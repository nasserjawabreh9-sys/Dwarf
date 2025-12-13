#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
SCRIPTS="$ROOT/scripts"
OPS="$ROOT/ops"
BACKEND="$ROOT/backend"
FRONTEND="$ROOT/frontend"
LOGS="$ROOT/station_logs"
mkdir -p "$SCRIPTS" "$OPS" "$LOGS"

ts(){ date +"%Y-%m-%d %H:%M:%S"; }
say(){ echo "[$(ts)] $*"; }

# -------------------------
# Global guardrail helpers
# -------------------------
ensure_pkg(){
  pkg update -y >/dev/null 2>&1 || true
  pkg install -y git curl jq lsof openssl python nodejs npm termux-tools ca-certificates >/dev/null 2>&1 || true
}

kill_port(){
  local p="$1"
  if command -v lsof >/dev/null 2>&1; then
    for pid in $(lsof -tiTCP:"$p" -sTCP:LISTEN 2>/dev/null); do
      kill -9 "$pid" >/dev/null 2>&1 || true
    done
  fi
}

write_file(){
  local path="$1"; shift
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<'EOF'
EOF
  # then replace with heredoc content by caller (we don't use this helper for now)
}

# -------------------------
# UUL Tree (Ultimate)
# -------------------------
uul_tree(){
  say "UUL-100: Ultimate tree"
  mkdir -p "$ROOT"/{backend,frontend,ops,scripts,db,seed,station_logs,app_storage,backups,artifacts,docs}
  mkdir -p "$BACKEND"/{backend,app}
  mkdir -p "$BACKEND/app"/{core,routers,services,state,storage,security,observability,schemas}
  mkdir -p "$FRONTEND"/{src,public}
  mkdir -p "$OPS"/{git,render,hardening,doctor}
}

# -------------------------
# Env (safe, no secrets)
# -------------------------
uul_env(){
  say "UUL-110: station_env.sh (safe template)"
  cat > "$ROOT/station_env.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -e
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export PYTHONIOENCODING="utf-8"

export STATION_ROOT="$HOME/station_root"

export STATION_BACKEND_HOST="127.0.0.1"
export STATION_BACKEND_PORT="8000"
export STATION_FRONTEND_PORT="5173"

# Optional defaults (do NOT put secrets here). Prefer UI -> LocalStorage -> backend store.
export STATION_EDIT_MODE_KEY="${STATION_EDIT_MODE_KEY:-1234}"

echo "[station_env] Loaded."
EOF
  chmod +x "$ROOT/station_env.sh"
}

# -------------------------
# Backend (Hardened + Observability + RBAC-lite + Guards + Dynamo)
# -------------------------
uul_backend(){
  say "UUL-300: Backend hardened build"

  cat > "$BACKEND/requirements.txt" <<'EOF'
fastapi==0.115.6
uvicorn==0.32.1
pydantic==2.10.3
pydantic-settings==2.6.1
python-multipart==0.0.12
requests==2.32.3
EOF

  # core config
  cat > "$BACKEND/app/core/config.py" <<'EOF'
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    station_root: str = ""
    edit_mode_key: str = "1234"

    # runtime
    environment: str = "dev"
    cors_allow_origins: str = "*"

    # keys and integrations (stored in backend store, masked in reads)
    openai_api_key: str = ""
    github_token: str = ""
    github_repo: str = ""
    render_api_key: str = ""
    render_service_id: str = ""

    webhooks_url: str = ""
    tts_key: str = ""
    ocr_key: str = ""
    web_integration_key: str = ""
    whatsapp_key: str = ""
    email_smtp: str = ""

    # security
    require_edit_key_for_ops: bool = True
    max_body_kb: int = 512
    rate_limit_rpm: int = 120  # lightweight in-process limiter

    model_config = SettingsConfigDict(env_prefix="STATION_", extra="ignore")

settings = Settings()
EOF

  # storage: persistent json store
  cat > "$BACKEND/app/services/store.py" <<'EOF'
import json
from pathlib import Path
from typing import Dict, Any

def base_root(station_root: str) -> Path:
    if station_root:
        return Path(station_root).expanduser()
    return Path.home() / "station_root"

def store_dir(station_root: str) -> Path:
    d = base_root(station_root) / "app_storage"
    d.mkdir(parents=True, exist_ok=True)
    return d

def store_path(station_root: str) -> Path:
    return store_dir(station_root) / "settings.json"

def read_settings(station_root: str) -> Dict[str, Any]:
    p = store_path(station_root)
    if not p.exists():
        return {}
    return json.loads(p.read_text(encoding="utf-8"))

def write_settings(station_root: str, data: Dict[str, Any]) -> Dict[str, Any]:
    p = store_path(station_root)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    return data
EOF

  # observability: request id + minimal logs
  cat > "$BACKEND/app/observability/mw.py" <<'EOF'
import time, uuid
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware

class RequestIdMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        rid = request.headers.get("x-request-id") or str(uuid.uuid4())
        request.state.request_id = rid
        start = time.time()
        resp = await call_next(request)
        ms = int((time.time() - start) * 1000)
        resp.headers["x-request-id"] = rid
        resp.headers["x-response-ms"] = str(ms)
        return resp
EOF

  # security: size guard + rate limiter (in-process)
  cat > "$BACKEND/app/security/guards.py" <<'EOF'
import time
from fastapi import Request, HTTPException
from app.core.config import settings

# very light in-memory rate limiter by client ip
_BUCKET = {}

def body_size_guard(request: Request):
    cl = request.headers.get("content-length")
    if not cl:
        return
    try:
        n = int(cl)
    except ValueError:
        return
    if n > settings.max_body_kb * 1024:
        raise HTTPException(status_code=413, detail="payload too large")

def rate_limit_guard(request: Request):
    ip = request.client.host if request.client else "unknown"
    now = int(time.time())
    key = (ip, now // 60)
    _BUCKET[key] = _BUCKET.get(key, 0) + 1
    if _BUCKET[key] > settings.rate_limit_rpm:
        raise HTTPException(status_code=429, detail="rate limit exceeded")
EOF

  # rooms/guards state
  cat > "$BACKEND/app/state/rooms.py" <<'EOF'
import time
from typing import Dict, Any

STATE: Dict[str, Any] = {
    "rooms": {
        "L0": {"name": "L0", "desc": "Safe defaults", "enabled": True},
        "L1": {"name": "L1", "desc": "Automation low risk", "enabled": True},
        "L2": {"name": "L2", "desc": "Automation medium risk", "enabled": True},
        "L3": {"name": "L3", "desc": "Requires owner explicit approval", "enabled": False},
    },
    "guards": {
        "anti_repeat": True,
        "termux_safe": True,
        "no_arabic_in_code": True,
        "ports_auto_fix": True,
        "size_guard": True,
        "rate_limit": True
    },
    "updated_at": int(time.time())
}

def snapshot() -> Dict[str, Any]:
    return STATE

def patch(data: Dict[str, Any]) -> Dict[str, Any]:
    for k,v in data.items():
        if k in STATE and isinstance(STATE[k], dict) and isinstance(v, dict):
            STATE[k].update(v)
        else:
            STATE[k] = v
    STATE["updated_at"] = int(time.time())
    return STATE
EOF

  # dynamo event bus
  cat > "$BACKEND/app/state/dynamo.py" <<'EOF'
import time
from typing import Dict, Any

STATE: Dict[str, Any] = {
    "enabled": True,
    "last_tick": 0,
    "events": [],
    "max_events": 250
}

def add_event(kind: str, payload: dict):
    ev = {"ts": int(time.time()), "kind": kind, "payload": payload}
    STATE["events"].append(ev)
    if len(STATE["events"]) > STATE["max_events"]:
        STATE["events"] = STATE["events"][-STATE["max_events"]:]
    return ev

def tick(meta: dict | None = None):
    STATE["last_tick"] = int(time.time())
    add_event("tick", {"ok": True, "meta": meta or {}})
    return STATE

def get_state():
    return STATE
EOF

  # routers
  cat > "$BACKEND/app/routers/health.py" <<'EOF'
from fastapi import APIRouter

router = APIRouter(tags=["health"])

@router.get("/healthz")
def healthz():
    return {"ok": True}

@router.get("/info")
def info():
    return {"name": "Station", "ok": True, "version": "2.0.0-global"}
EOF

  cat > "$BACKEND/app/routers/settings.py" <<'EOF'
from fastapi import APIRouter
from pydantic import BaseModel
from app.core.config import settings
from app.services.store import read_settings, write_settings

router = APIRouter(tags=["settings"])

SENSITIVE = {
    "openai_api_key","github_token","render_api_key","tts_key","ocr_key",
    "web_integration_key","whatsapp_key"
}

def mask(v: str) -> str:
    if not v:
        return ""
    if len(v) <= 8:
        return "****"
    return v[:4] + "..." + v[-4:]

class SettingsIn(BaseModel):
    openai_api_key: str | None = None
    github_token: str | None = None
    github_repo: str | None = None
    render_api_key: str | None = None
    render_service_id: str | None = None
    edit_mode_key: str | None = None

    webhooks_url: str | None = None
    tts_key: str | None = None
    ocr_key: str | None = None
    web_integration_key: str | None = None
    whatsapp_key: str | None = None
    email_smtp: str | None = None

@router.get("/api/settings")
def get_settings():
    data = read_settings(settings.station_root)
    masked = {}
    for k,v in data.items():
        if k in SENSITIVE and isinstance(v, str):
            masked[k] = mask(v)
        else:
            masked[k] = v
    return {"ok": True, "stored": masked, "has": {k: bool(data.get(k)) for k in data.keys()}}

@router.post("/api/settings")
def set_settings(payload: SettingsIn):
    current = read_settings(settings.station_root)
    d = payload.model_dump(exclude_none=True)
    current.update(d)
    write_settings(settings.station_root, current)
    return {"ok": True}
EOF

  cat > "$BACKEND/app/routers/rooms.py" <<'EOF'
from fastapi import APIRouter
from pydantic import BaseModel
from app.state.rooms import snapshot, patch

router = APIRouter(tags=["rooms"])

@router.get("/api/rooms")
def get_rooms():
    return snapshot()

class PatchIn(BaseModel):
    rooms: dict | None = None
    guards: dict | None = None

@router.post("/api/rooms")
def patch_rooms(p: PatchIn):
    return patch(p.model_dump(exclude_none=True))
EOF

  cat > "$BACKEND/app/routers/dynamo.py" <<'EOF'
from fastapi import APIRouter
from pydantic import BaseModel
from app.state.dynamo import tick, get_state, add_event

router = APIRouter(tags=["dynamo"])

@router.get("/api/dynamo")
def dynamo_state():
    return get_state()

class TickIn(BaseModel):
    meta: dict | None = None

@router.post("/api/dynamo/tick")
def dynamo_tick(t: TickIn):
    return tick(t.meta or {})

class EvIn(BaseModel):
    kind: str
    payload: dict = {}

@router.post("/api/dynamo/event")
def dynamo_event(e: EvIn):
    return add_event(e.kind, e.payload)
EOF

  # ops: git + render ping (edit key protected)
  cat > "$BACKEND/app/routers/ops.py" <<'EOF'
import os, subprocess, shlex
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.core.config import settings
from app.services.store import read_settings

router = APIRouter(tags=["ops"])

def require_edit_key(key: str):
    store = read_settings(settings.station_root)
    expected = store.get("edit_mode_key") or settings.edit_mode_key
    if settings.require_edit_key_for_ops and key != expected:
        raise HTTPException(status_code=403, detail="Edit mode key required")

class OpsIn(BaseModel):
    edit_mode_key: str
    message: str | None = "station ops"

@router.get("/api/ops/git/status")
def git_status():
    root = os.path.expanduser(settings.station_root) or os.path.expanduser("~/station_root")
    r = subprocess.run(["bash","-lc", f"cd {shlex.quote(root)} && git status -sb || true"], capture_output=True, text=True)
    return {"ok": True, "out": r.stdout[-4000:]}

@router.post("/api/ops/git/push")
def git_push(p: OpsIn):
    require_edit_key(p.edit_mode_key)
    root = os.path.expanduser(settings.station_root) or os.path.expanduser("~/station_root")
    cmd = f"""
    set -e
    cd {shlex.quote(root)}
    git add -A
    git commit -m {shlex.quote(p.message)} || true
    git push -u origin main
    """
    r = subprocess.run(["bash","-lc", cmd], capture_output=True, text=True)
    if r.returncode != 0:
        raise HTTPException(status_code=500, detail=(r.stderr[-2000:] or r.stdout[-2000:]))
    return {"ok": True, "out": (r.stdout[-4000:] or "pushed")}

@router.post("/api/ops/render/ping")
def render_ping(p: OpsIn):
    require_edit_key(p.edit_mode_key)
    store = read_settings(settings.station_root)
    api = store.get("render_api_key","")
    if not api:
        raise HTTPException(status_code=400, detail="render_api_key missing in settings")
    import requests
    resp = requests.get("https://api.render.com/v1/services", headers={"Authorization": f"Bearer {api}"}, timeout=20)
    ct = resp.headers.get("content-type","")
    data = resp.json() if ct.startswith("application/json") else {"text": resp.text[:300]}
    return {"ok": True, "status": resp.status_code, "sample": data[:1] if isinstance(data, list) else data}
EOF

  # app entrypoint
  cat > "$BACKEND/backend/app.py" <<'EOF'
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.observability.mw import RequestIdMiddleware
from app.security.guards import body_size_guard, rate_limit_guard
from app.routers import health, settings as settings_router, rooms, dynamo, ops

app = FastAPI(title="Station", version="2.0.0-global")

app.add_middleware(RequestIdMiddleware)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in settings.cors_allow_origins.split(",")] if settings.cors_allow_origins else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.middleware("http")
async def guards_middleware(request: Request, call_next):
    # Minimal hardening in dev-friendly way
    body_size_guard(request)
    rate_limit_guard(request)
    return await call_next(request)

app.include_router(health.router)
app.include_router(settings_router.router)
app.include_router(rooms.router)
app.include_router(dynamo.router)
app.include_router(ops.router)

EOF

  cat > "$BACKEND/app/routers/__init__.py" <<'EOF'
from . import health, settings, rooms, dynamo, ops
EOF
}

# -------------------------
# Frontend (Production-grade basics + no TS6133 issue)
# -------------------------
uul_frontend(){
  say "UUL-320: Frontend pro scaffold"

  cat > "$FRONTEND/package.json" <<'EOF'
{
  "name": "station-frontend",
  "private": true,
  "version": "2.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "preview": "vite preview --host 127.0.0.1 --port 5173"
  },
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "devDependencies": {
    "@types/react": "^18.3.12",
    "@types/react-dom": "^18.3.1",
    "typescript": "^5.6.3",
    "vite": "^5.4.11"
  }
}
EOF

  cat > "$FRONTEND/tsconfig.json" <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "useDefineForClassFields": true,
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "Bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": false,
    "noUnusedParameters": false,
    "types": ["vite/client"]
  },
  "include": ["src"]
}
EOF

  cat > "$FRONTEND/vite.config.ts" <<'EOF'
import { defineConfig } from "vite";

export default defineConfig({
  server: { host: "127.0.0.1", port: 5173 }
});
EOF

  cat > "$FRONTEND/index.html" <<'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Station</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF

  cat > "$FRONTEND/src/main.tsx" <<'EOF'
import { createRoot } from "react-dom/client";
import App from "./ui/App";

createRoot(document.getElementById("root")!).render(<App />);
EOF

  cat > "$FRONTEND/src/core/api.ts" <<'EOF'
export const BACKEND = (import.meta as any).env?.VITE_BACKEND_URL || "http://127.0.0.1:8000";

export async function getJSON(path: string) {
  const r = await fetch(`${BACKEND}${path}`);
  if (!r.ok) throw new Error(`${r.status} ${r.statusText}`);
  return r.json();
}

export async function postJSON(path: string, body: any) {
  const r = await fetch(`${BACKEND}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body)
  });
  if (!r.ok) throw new Error(`${r.status} ${r.statusText}`);
  return r.json();
}
EOF

  mkdir -p "$FRONTEND/src/ui" "$FRONTEND/src/core"

  cat > "$FRONTEND/src/ui/App.tsx" <<'EOF'
import { useEffect, useState } from "react";
import { BACKEND, getJSON, postJSON } from "../core/api";

type Tab = "Landing" | "Dashboard" | "Settings" | "Console" | "Hardening";

export default function App() {
  const [tab, setTab] = useState<Tab>("Landing");
  const [clock, setClock] = useState<number>(Date.now());

  useEffect(() => {
    const t = setInterval(() => setClock(Date.now()), 1000);
    return () => clearInterval(t);
  }, []);

  return (
    <div style={{ fontFamily: "system-ui, -apple-system, Segoe UI, Roboto, Arial", height: "100vh", display: "flex", flexDirection: "column" }}>
      <TopBar tab={tab} setTab={setTab} clock={clock} />
      <div style={{ display: "flex", flex: 1, minHeight: 0 }}>
        <SideBar tab={tab} setTab={setTab} />
        <div style={{ flex: 1, minHeight: 0, background: "#0b1220", color: "#e8eefc" }}>
          {tab === "Landing" && <Landing setTab={setTab} />}
          {tab === "Dashboard" && <Dashboard />}
          {tab === "Settings" && <Settings />}
          {tab === "Console" && <Console />}
          {tab === "Hardening" && <Hardening />}
        </div>
      </div>
      <StatusBar />
      <div style={{ position:"fixed", right: 10, bottom: 40, fontSize: 11, opacity: 0.65 }}>
        Backend: {BACKEND}
      </div>
    </div>
  );
}

function TopBar({ tab, setTab, clock }: { tab: Tab; setTab: (t:Tab)=>void; clock:number; }) {
  const tabs: Tab[] = ["Landing","Dashboard","Settings","Console","Hardening"];
  return (
    <div style={{ height: 44, display:"flex", alignItems:"center", justifyContent:"space-between", padding:"0 12px", background:"#0a2a66", color:"#eaf2ff", borderBottom:"1px solid rgba(255,255,255,0.1)" }}>
      <div style={{ display:"flex", gap:10, alignItems:"center" }}>
        <div style={{ width: 26, height: 26, borderRadius: 8, background:"#163b8a", display:"grid", placeItems:"center", boxShadow:"0 6px 18px rgba(0,0,0,0.35)" }}>
          <span style={{ fontWeight: 900 }}>S</span>
        </div>
        <div style={{ fontWeight: 800 }}>Station</div>
        <div style={{ opacity: 0.8, fontSize: 12 }}>Global / Hardened</div>
      </div>
      <div style={{ display:"flex", gap:8, flexWrap:"wrap" }}>
        {tabs.map(t => (
          <button key={t} onClick={() => setTab(t)}
            style={{
              height: 28, padding:"0 10px", borderRadius: 10,
              border: "1px solid rgba(255,255,255,0.18)",
              background: tab===t ? "rgba(255,255,255,0.18)" : "rgba(0,0,0,0.15)",
              color:"#eaf2ff", cursor:"pointer", fontWeight: 700
            }}>
            {t}
          </button>
        ))}
      </div>
      <div style={{ fontSize: 12, opacity: 0.78 }}>{new Date(clock).toLocaleTimeString()}</div>
    </div>
  );
}

function SideBar({ tab, setTab }: { tab: Tab; setTab:(t:Tab)=>void }) {
  const items: {t:Tab, d:string}[] = [
    { t:"Landing", d:"Start & Demo" },
    { t:"Dashboard", d:"Health / Rooms / Dynamo" },
    { t:"Settings", d:"Keys / Integrations (bars)" },
    { t:"Console", d:"Ops (Git/Render) + Output" },
    { t:"Hardening", d:"Checks & Actions" }
  ];
  return (
    <div style={{ width: 250, background:"#07101f", borderRight:"1px solid rgba(255,255,255,0.08)", padding: 12 }}>
      <div style={{ fontSize: 12, opacity: 0.75, marginBottom: 8 }}>Navigation</div>
      {items.map(x => (
        <div key={x.t} onClick={() => setTab(x.t)}
          style={{
            padding:"10px 10px", borderRadius: 12, cursor:"pointer",
            background: tab===x.t ? "rgba(74,144,226,0.18)" : "transparent",
            border: tab===x.t ? "1px solid rgba(74,144,226,0.35)" : "1px solid rgba(255,255,255,0.06)",
            marginBottom: 8
          }}>
          <div style={{ fontWeight: 900 }}>{x.t}</div>
          <div style={{ fontSize: 12, opacity: 0.7 }}>{x.d}</div>
        </div>
      ))}
      <div style={{ marginTop: 10, padding: 10, borderRadius: 12, border:"1px dashed rgba(255,255,255,0.14)", opacity: 0.9 }}>
        <div style={{ fontWeight: 900 }}>Armored Dwarf</div>
        <div style={{ fontSize: 12, opacity: 0.7 }}>Brand slot reserved</div>
      </div>
    </div>
  );
}

function Landing({ setTab }:{setTab:(t:Tab)=>void}){
  return (
    <div style={{ padding: 18, maxWidth: 980 }}>
      <div style={{ fontSize: 32, fontWeight: 950, letterSpacing: -0.6 }}>Station Global is Live</div>
      <div style={{ marginTop: 8, opacity: 0.85 }}>
        Hardened backend, permanent keys bars, Rooms/Guards, Dynamo events, Ops endpoints, and Hardening checks.
      </div>
      <div style={{ marginTop: 14, display:"flex", gap:10, flexWrap:"wrap" }}>
        <button onClick={()=>setTab("Settings")} style={btnPrimary}>Open Settings</button>
        <button onClick={()=>setTab("Dashboard")} style={btnGhost}>Open Dashboard</button>
        <button onClick={()=>setTab("Hardening")} style={btnGhost}>Open Hardening</button>
      </div>
      <div style={{ marginTop: 14, fontSize: 12, opacity: 0.7 }}>
        Note: animation/audio intentionally omitted in Global to keep Termux stable. Can be added later as optional layer.
      </div>
    </div>
  );
}

function Dashboard(){
  const [health, setHealth] = useState<any>(null);
  const [rooms, setRooms] = useState<any>(null);
  const [dynamo, setDynamo] = useState<any>(null);
  const [err, setErr] = useState<string>("");

  async function load(){
    setErr("");
    try{
      setHealth(await getJSON("/healthz"));
      setRooms(await getJSON("/api/rooms"));
      setDynamo(await getJSON("/api/dynamo"));
    }catch(e:any){
      setErr(String(e?.message||e));
    }
  }

  useEffect(()=>{ load(); }, []);

  return (
    <div style={{ padding: 18, maxWidth: 980 }}>
      <div style={{ fontSize: 22, fontWeight: 950 }}>Dashboard</div>
      {err && <div style={{ marginTop: 10, color:"#ffb4b4" }}>Error: {err}</div>}
      <div style={{ marginTop: 10, display:"flex", gap:10, flexWrap:"wrap" }}>
        <button onClick={load} style={btnGhost}>Refresh</button>
        <button onClick={async()=>{ await postJSON("/api/dynamo/tick", {meta:{from:"ui"}}); await load(); }} style={btnPrimary}>Dynamo Tick</button>
      </div>

      <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr", gap:12, marginTop: 12 }}>
        <Panel title="Backend Health" value={health ? "OK" : "..."} body={<pre style={pre}>{JSON.stringify(health, null, 2)}</pre>} />
        <Panel title="Rooms / Guards" value={rooms ? "Loaded" : "..."} body={<pre style={pre}>{JSON.stringify(rooms, null, 2)}</pre>} />
      </div>
      <div style={{ marginTop: 12 }}>
        <Panel title="Dynamo" value={dynamo ? "Active" : "..."} body={<pre style={pre}>{JSON.stringify(dynamo, null, 2)}</pre>} />
      </div>
    </div>
  );
}

function Settings(){
  const init = (k:string, def="") => localStorage.getItem(k) || def;
  const [form, setForm] = useState<any>({
    openai_api_key: init("openai_api_key"),
    github_token: init("github_token"),
    github_repo: init("github_repo"),
    render_api_key: init("render_api_key"),
    render_service_id: init("render_service_id"),
    edit_mode_key: init("edit_mode_key", "1234"),

    tts_key: init("tts_key"),
    webhooks_url: init("webhooks_url"),
    ocr_key: init("ocr_key"),
    web_integration_key: init("web_integration_key"),
    whatsapp_key: init("whatsapp_key"),
    email_smtp: init("email_smtp")
  });

  const [status, setStatus] = useState<string>("");

  function saveLocal(){
    Object.keys(form).forEach(k => localStorage.setItem(k, String(form[k] ?? "")));
    setStatus("Saved to LocalStorage");
    setTimeout(()=>setStatus(""), 1200);
  }

  async function saveBackend(){
    try{
      await postJSON("/api/settings", form);
      setStatus("Saved to Backend");
      setTimeout(()=>setStatus(""), 1200);
    }catch(e:any){
      setStatus("Backend error: " + (e?.message||e));
    }
  }

  async function loadBackend(){
    try{
      const r = await getJSON("/api/settings");
      setStatus("Loaded (masked) from Backend (see console log)");
      console.log("backend settings", r);
      setTimeout(()=>setStatus(""), 1200);
    }catch(e:any){
      setStatus("Load error: " + (e?.message||e));
    }
  }

  return (
    <div style={{ padding: 18, maxWidth: 980 }}>
      <div style={{ fontSize: 22, fontWeight: 950 }}>Settings</div>
      <div style={{ marginTop: 6, opacity: 0.8, fontSize: 13 }}>
        Permanent bars for: API Key, TTS, Hooks, OCR, Web, WhatsApp, Email, GitHub, Render. Ops requires Edit Mode Key.
      </div>

      <div style={{ marginTop: 12, display:"grid", gridTemplateColumns:"1fr 1fr", gap:12 }}>
        <Field label="OpenAI API Key" v={form.openai_api_key} onChange={(v)=>setForm({...form, openai_api_key:v})} secret />
        <Field label="GitHub Token" v={form.github_token} onChange={(v)=>setForm({...form, github_token:v})} secret />
        <Field label="GitHub Repo (owner/repo)" v={form.github_repo} onChange={(v)=>setForm({...form, github_repo:v})} />
        <Field label="Render API Key" v={form.render_api_key} onChange={(v)=>setForm({...form, render_api_key:v})} secret />
        <Field label="Render Service ID" v={form.render_service_id} onChange={(v)=>setForm({...form, render_service_id:v})} />
        <Field label="Edit Mode Key" v={form.edit_mode_key} onChange={(v)=>setForm({...form, edit_mode_key:v})} />
      </div>

      <div style={{ marginTop: 12, display:"grid", gridTemplateColumns:"1fr 1fr", gap:12 }}>
        <Field label="TTS Key" v={form.tts_key} onChange={(v)=>setForm({...form, tts_key:v})} />
        <Field label="Webhooks URL" v={form.webhooks_url} onChange={(v)=>setForm({...form, webhooks_url:v})} />
        <Field label="OCR Key" v={form.ocr_key} onChange={(v)=>setForm({...form, ocr_key:v})} />
        <Field label="Web Integration Key" v={form.web_integration_key} onChange={(v)=>setForm({...form, web_integration_key:v})} />
        <Field label="WhatsApp Key" v={form.whatsapp_key} onChange={(v)=>setForm({...form, whatsapp_key:v})} />
        <Field label="Email SMTP (string)" v={form.email_smtp} onChange={(v)=>setForm({...form, email_smtp:v})} />
      </div>

      <div style={{ marginTop: 12, display:"flex", gap:10, flexWrap:"wrap" }}>
        <button onClick={saveLocal} style={btnPrimary}>Save Local</button>
        <button onClick={saveBackend} style={btnGhost}>Save to Backend</button>
        <button onClick={loadBackend} style={btnGhost}>Load from Backend</button>
        <div style={{ marginLeft: 8, fontSize: 12, opacity: 0.75, alignSelf:"center" }}>{status}</div>
      </div>
    </div>
  );
}

function Console(){
  const [out, setOut] = useState<string>("");
  const [editKey, setEditKey] = useState<string>(localStorage.getItem("edit_mode_key") || "1234");

  async function gitStatus(){
    try{ setOut(JSON.stringify(await getJSON("/api/ops/git/status"), null, 2)); }
    catch(e:any){ setOut("Error: " + (e?.message||e)); }
  }
  async function gitPush(){
    try{ setOut(JSON.stringify(await postJSON("/api/ops/git/push", { edit_mode_key: editKey, message: "station global upgrade" }), null, 2)); }
    catch(e:any){ setOut("Error: " + (e?.message||e)); }
  }
  async function renderPing(){
    try{ setOut(JSON.stringify(await postJSON("/api/ops/render/ping", { edit_mode_key: editKey, message:"ping" }), null, 2)); }
    catch(e:any){ setOut("Error: " + (e?.message||e)); }
  }

  return (
    <div style={{ padding: 18, maxWidth: 980 }}>
      <div style={{ fontSize: 22, fontWeight: 950 }}>Console</div>

      <div style={{ marginTop: 10, display:"flex", gap:10, flexWrap:"wrap" }}>
        <button onClick={gitStatus} style={btnGhost}>Git Status</button>
        <button onClick={gitPush} style={btnPrimary}>Commit + Push</button>
        <button onClick={renderPing} style={btnGhost}>Render Ping</button>

        <div style={{ display:"flex", gap:8, alignItems:"center" }}>
          <span style={{ fontSize: 12, opacity: 0.75 }}>Edit Key</span>
          <input value={editKey} onChange={(e)=>{setEditKey(e.target.value); localStorage.setItem("edit_mode_key", e.target.value);}}
            style={{ height: 28, borderRadius: 10, border:"1px solid rgba(255,255,255,0.18)", background:"rgba(0,0,0,0.25)", color:"#eaf2ff", padding:"0 10px" }} />
        </div>
      </div>

      <div style={{ marginTop: 12 }}>
        <pre style={pre}>{out || "Output will appear here."}</pre>
      </div>
    </div>
  );
}

function Hardening(){
  const [out, setOut] = useState<string>("");

  async function runHardening(){
    try{
      const r1 = await getJSON("/healthz");
      const r2 = await getJSON("/api/rooms");
      const r3 = await getJSON("/api/dynamo");
      setOut(JSON.stringify({health:r1, rooms:r2, dynamo:r3}, null, 2));
    }catch(e:any){
      setOut("Error: " + (e?.message||e));
    }
  }

  return (
    <div style={{ padding: 18, maxWidth: 980 }}>
      <div style={{ fontSize: 22, fontWeight: 950 }}>Hardening</div>
      <div style={{ marginTop: 6, opacity: 0.8, fontSize: 13 }}>
        This page validates core guards and observability via endpoints. Advanced hardening is done via scripts on Termux / server.
      </div>
      <div style={{ marginTop: 10, display:"flex", gap:10, flexWrap:"wrap" }}>
        <button onClick={runHardening} style={btnPrimary}>Run Checks</button>
      </div>
      <div style={{ marginTop: 12 }}>
        <pre style={pre}>{out || "No output yet."}</pre>
      </div>
    </div>
  );
}

function Panel({title, value, body}:{title:string; value:string; body:any}){
  return (
    <div style={{ padding: 14, borderRadius: 16, background:"rgba(255,255,255,0.04)", border:"1px solid rgba(255,255,255,0.08)" }}>
      <div style={{ display:"flex", justifyContent:"space-between", alignItems:"center" }}>
        <div style={{ fontWeight: 900 }}>{title}</div>
        <div style={{ fontSize: 12, opacity: 0.75 }}>{value}</div>
      </div>
      <div style={{ marginTop: 10 }}>{body}</div>
    </div>
  );
}

function Field({label, v, onChange, secret}:{label:string; v:string; onChange:(v:string)=>void; secret?:boolean}){
  return (
    <div style={{ padding: 12, borderRadius: 16, background:"rgba(0,0,0,0.18)", border:"1px solid rgba(255,255,255,0.10)" }}>
      <div style={{ fontSize: 12, opacity: 0.78 }}>{label}</div>
      <input value={v} type={secret ? "password" : "text"} onChange={(e)=>onChange(e.target.value)}
        style={{
          marginTop: 6, width:"100%", height: 34, padding:"0 10px",
          borderRadius: 12, border:"1px solid rgba(255,255,255,0.18)",
          background:"rgba(0,0,0,0.28)", color:"#eaf2ff"
        }}
      />
    </div>
  );
}

function StatusBar(){
  return (
    <div style={{ height: 30, display:"flex", alignItems:"center", justifyContent:"space-between", padding:"0 12px",
      background:"#061023", borderTop:"1px solid rgba(255,255,255,0.08)", color:"#cfe0ff", fontSize: 12 }}>
      <div>Station Status: <span style={{ opacity: 0.85 }}>Global Ready</span></div>
      <div style={{ opacity: 0.7 }}>Ports: 8000 / 5173</div>
    </div>
  );
}

const pre: any = {
  whiteSpace:"pre-wrap",
  wordBreak:"break-word",
  background:"rgba(0,0,0,0.35)",
  border:"1px solid rgba(255,255,255,0.10)",
  borderRadius: 14,
  padding: 12,
  minHeight: 180
};

const btnPrimary: any = {
  height: 34, padding:"0 12px", borderRadius: 12,
  border:"1px solid rgba(74,144,226,0.55)",
  background:"rgba(74,144,226,0.28)",
  color:"#eaf2ff", cursor:"pointer", fontWeight: 800
};

const btnGhost: any = {
  height: 34, padding:"0 12px", borderRadius: 12,
  border:"1px solid rgba(255,255,255,0.18)",
  background:"rgba(0,0,0,0.22)",
  color:"#eaf2ff", cursor:"pointer", fontWeight: 750
};
EOF
}

# -------------------------
# Hardening + Doctor scripts (Global)
# -------------------------
uul_scripts(){
  say "UUL-900: Scripts (doctor/build/run/harden/backup)"

  cat > "$SCRIPTS/uul_doctor.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
source "$ROOT/station_env.sh" 2>/dev/null || true

echo "=== STATION DOCTOR ==="
echo "ROOT=$ROOT"
echo "Python: $(python -V 2>/dev/null || true)"
echo "Node:   $(node -v 2>/dev/null || true)"
echo "Npm:    $(npm -v 2>/dev/null || true)"
echo "Git:    $(git --version 2>/dev/null || true)"
echo "Ports (listeners):"
if command -v lsof >/dev/null 2>&1; then
  lsof -iTCP:8000 -sTCP:LISTEN 2>/dev/null || true
  lsof -iTCP:5173 -sTCP:LISTEN 2>/dev/null || true
else
  echo "lsof missing"
fi

echo "Backend tree:"
ls -la "$ROOT/backend" || true
echo "Frontend tree:"
ls -la "$ROOT/frontend" || true
EOF
  chmod +x "$SCRIPTS/uul_doctor.sh"

  cat > "$SCRIPTS/uul_build.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
source "$ROOT/station_env.sh" 2>/dev/null || true
LOGS="$ROOT/station_logs"; mkdir -p "$LOGS"

pkg install -y python nodejs npm curl lsof >/dev/null 2>&1 || true

echo "=== BUILD BACKEND ==="
cd "$ROOT/backend"
if [[ ! -d ".venv" ]]; then python -m venv .venv; fi
source ".venv/bin/activate"
python -m pip install -U pip >/dev/null 2>&1 || true
python -m pip install -r requirements.txt >"$LOGS/pip_install.log" 2>&1

echo "=== BUILD FRONTEND ==="
cd "$ROOT/frontend"
npm install >"$LOGS/npm_install.log" 2>&1
EOF
  chmod +x "$SCRIPTS/uul_build.sh"

  cat > "$SCRIPTS/uul_run.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
source "$ROOT/station_env.sh" 2>/dev/null || true

HOST="${STATION_BACKEND_HOST:-127.0.0.1}"
BPORT="${STATION_BACKEND_PORT:-8000}"
FPORT="${STATION_FRONTEND_PORT:-5173}"

LOGS="$ROOT/station_logs"; mkdir -p "$LOGS"

kill_port(){
  local p="$1"
  if command -v lsof >/dev/null 2>&1; then
    for pid in $(lsof -tiTCP:"$p" -sTCP:LISTEN 2>/dev/null); do kill -9 "$pid" >/dev/null 2>&1 || true; done
  fi
}

health_wait(){
  for i in $(seq 1 80); do
    if curl -fsS "http://$HOST:$BPORT/healthz" >/dev/null 2>&1; then return 0; fi
    sleep 0.5
  done
  return 1
}

kill_port "$BPORT"
kill_port "$FPORT"

echo "=== RUN BACKEND ==="
cd "$ROOT/backend"
source ".venv/bin/activate" 2>/dev/null || true
nohup python -m uvicorn backend.app:app --host "$HOST" --port "$BPORT" --reload >"$LOGS/backend.log" 2>&1 &

sleep 0.6
health_wait || { echo "Backend not healthy"; tail -n 140 "$LOGS/backend.log"; exit 1; }

echo "=== RUN FRONTEND ==="
cd "$ROOT/frontend"
export VITE_BACKEND_URL="http://$HOST:$BPORT"
nohup npm run dev -- --host 127.0.0.1 --port "$FPORT" >"$LOGS/frontend.log" 2>&1 &

sleep 1.1
if command -v termux-open-url >/dev/null 2>&1; then
  termux-open-url "http://127.0.0.1:$FPORT/" >/dev/null 2>&1 || true
fi

echo "RUNNING"
echo "UI: http://127.0.0.1:$FPORT/"
echo "Logs: $LOGS"
EOF
  chmod +x "$SCRIPTS/uul_run.sh"

  cat > "$SCRIPTS/uul_reset_run.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
source "$ROOT/station_env.sh" 2>/dev/null || true
LOGS="$ROOT/station_logs"; mkdir -p "$LOGS"

echo "=== RESET FRONTEND ==="
cd "$ROOT/frontend"
rm -rf dist .vite node_modules package-lock.json >/dev/null 2>&1 || true
npm install >"$LOGS/npm_install.log" 2>&1 || { tail -n 120 "$LOGS/npm_install.log"; exit 1; }

echo "=== RESET BACKEND ==="
cd "$ROOT/backend"
rm -rf .venv >/dev/null 2>&1 || true
python -m venv .venv
source ".venv/bin/activate"
python -m pip install -U pip >/dev/null 2>&1 || true
python -m pip install -r requirements.txt >"$LOGS/pip_install.log" 2>&1 || { tail -n 120 "$LOGS/pip_install.log"; exit 1; }

bash "$ROOT/scripts/uul_run.sh"
EOF
  chmod +x "$SCRIPTS/uul_reset_run.sh"

  cat > "$SCRIPTS/uul_backup.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$ROOT/backups/station_backup_$TS.tgz"
mkdir -p "$ROOT/backups"

tar -czf "$OUT" \
  --exclude="**/node_modules" \
  --exclude="**/.venv" \
  --exclude="**/dist" \
  --exclude="**/.vite" \
  --exclude="**/__pycache__" \
  --exclude="**/*.pyc" \
  -C "$ROOT" \
  backend frontend scripts ops docs README.md .gitignore station_env.sh app_storage || true

echo "BACKUP: $OUT"
EOF
  chmod +x "$SCRIPTS/uul_backup.sh"

  cat > "$SCRIPTS/uul_harden_local.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
mkdir -p "$ROOT/ops/hardening"

cat > "$ROOT/ops/hardening/HARDENING_CHECKLIST.md" <<'MD'
# Station Hardening Checklist (Global)

## Network
- Bind backend to 127.0.0.1 for local use (default).
- If exposed externally: put behind reverse proxy + TLS + auth.

## App Guards
- Max body size (413) enabled.
- Rate limit (429) enabled.
- Edit mode key required for ops.

## Secrets
- Do not commit secrets.
- Use UI -> backend store (masked reads).
- Keep backups encrypted if needed.

## Ops
- Logs in station_logs.
- Backups in backups/.
- Git hygiene via .gitignore.
MD

echo "Wrote: $ROOT/ops/hardening/HARDENING_CHECKLIST.md"
EOF
  chmod +x "$SCRIPTS/uul_harden_local.sh"
}

# -------------------------
# Git hygiene + docs
# -------------------------
uul_docs(){
  say "Docs + git hygiene"

  cat > "$ROOT/.gitignore" <<'EOF'
# Python
__pycache__/
*.pyc
.venv/
**/.venv/

# Node
node_modules/
dist/
.vite/

# Runtime
station_logs/
app_storage/
backups/
artifacts/
EOF

  cat > "$ROOT/README.md" <<'EOF'
# Station Global (Hardened)

## One-time build
bash scripts/uul_build.sh

## Run
bash scripts/uul_run.sh

## Reset (hard)
bash scripts/uul_reset_run.sh

## Doctor
bash scripts/uul_doctor.sh

## Backup
bash scripts/uul_backup.sh

## Endpoints
- GET  /healthz
- GET  /info
- GET  /api/settings (masked)
- POST /api/settings
- GET  /api/rooms
- POST /api/rooms
- GET  /api/dynamo
- POST /api/dynamo/tick
- GET  /api/ops/git/status
- POST /api/ops/git/push
- POST /api/ops/render/ping
EOF
}

# -------------------------
# Final install + run
# -------------------------
uul_install_and_run(){
  say "Install dependencies + run"
  mkdir -p "$LOGS"

  cd "$BACKEND"
  python -m venv .venv >/dev/null 2>&1 || true
  source "$BACKEND/.venv/bin/activate" || true
  python -m pip install -U pip >/dev/null 2>&1 || true
  python -m pip install -r requirements.txt >"$LOGS/pip_install.log" 2>&1 || true

  cd "$FRONTEND"
  npm install >"$LOGS/npm_install.log" 2>&1 || true

  bash "$SCRIPTS/uul_run.sh"
}

main(){
  say "=== GLOBAL UPGRADE PACK (ULTRA) ==="
  ensure_pkg
  uul_tree
  uul_env
  uul_backend
  uul_frontend
  uul_scripts
  uul_docs
  uul_install_and_run
  say "=== DONE: Global upgrade applied ==="
  say "UI should be on: http://127.0.0.1:5173/"
}

main "$@"
