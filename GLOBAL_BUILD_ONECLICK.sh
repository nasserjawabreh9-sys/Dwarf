#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
LOGS="$ROOT/station_logs"
mkdir -p "$LOGS"

ts(){ date +"%Y-%m-%d %H:%M:%S"; }
say(){ echo "[$(ts)] $*"; }

need(){ command -v "$1" >/dev/null 2>&1 || { say "Missing: $1"; exit 1; }; }

safe_pkg(){
  pkg update -y >/dev/null 2>&1 || true
  pkg install -y git curl lsof jq python nodejs npm openssl termux-tools >/dev/null 2>&1 || true
}

mk_tree(){
  say "UUL-200/210: project tree"
  mkdir -p "$ROOT"/{backend,frontend,scripts,ops,seed,db,station_logs}
  mkdir -p "$ROOT/backend"/{backend,app,app/core,app/routers,app/services,app/state,app/storage}
  mkdir -p "$ROOT/frontend"/{src,public}
  mkdir -p "$ROOT/ops"/{render,git}
}

write_env(){
  say "Write env template"
  cat > "$ROOT/station_env.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -e
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export PYTHONIOENCODING="utf-8"

# Station runtime
export STATION_ROOT="$HOME/station_root"
export STATION_BACKEND_HOST="127.0.0.1"
export STATION_BACKEND_PORT="8000"
export STATION_FRONTEND_PORT="5173"

# Keys (fill later via UI; these are optional defaults)
export STATION_OPENAI_API_KEY="${STATION_OPENAI_API_KEY:-}"
export OPENAI_API_KEY="${OPENAI_API_KEY:-$STATION_OPENAI_API_KEY}"

export STATION_GITHUB_TOKEN="${STATION_GITHUB_TOKEN:-}"
export GITHUB_TOKEN="${GITHUB_TOKEN:-$STATION_GITHUB_TOKEN}"

export STATION_RENDER_API_KEY="${STATION_RENDER_API_KEY:-}"

echo "[station_env] Loaded."
EOF
  chmod +x "$ROOT/station_env.sh"
}

write_backend(){
  say "UUL-300: backend (FastAPI)"
  cat > "$ROOT/backend/requirements.txt" <<'EOF'
fastapi==0.115.6
uvicorn==0.32.1
pydantic==2.10.3
pydantic-settings==2.6.1
python-multipart==0.0.12
EOF

  cat > "$ROOT/backend/backend/app.py" <<'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import health, settings, ops, rooms, dynamo

app = FastAPI(title="Station", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(settings.router, prefix="/api")
app.include_router(rooms.router, prefix="/api")
app.include_router(dynamo.router, prefix="/api")
app.include_router(ops.router, prefix="/api/ops")
EOF

  cat > "$ROOT/backend/app/core/config.py" <<'EOF'
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    station_root: str = ""
    edit_mode_key: str = "1234"

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

    model_config = SettingsConfigDict(env_prefix="STATION_", extra="ignore")

settings = Settings()
EOF

  cat > "$ROOT/backend/app/services/store.py" <<'EOF'
import json, os
from pathlib import Path

def store_path(root: str) -> Path:
    base = Path(root).expanduser() if root else Path.home() / "station_root"
    p = base / "app_storage"
    p.mkdir(parents=True, exist_ok=True)
    return p / "settings.json"

def read_settings(root: str) -> dict:
    p = store_path(root)
    if not p.exists():
        return {}
    return json.loads(p.read_text(encoding="utf-8"))

def write_settings(root: str, data: dict) -> dict:
    p = store_path(root)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    return data
EOF

  cat > "$ROOT/backend/app/routers/health.py" <<'EOF'
from fastapi import APIRouter

router = APIRouter()

@router.get("/healthz")
def healthz():
    return {"ok": True}

@router.get("/info")
def info():
    return {"name": "Station", "ok": True}
EOF

  cat > "$ROOT/backend/app/routers/settings.py" <<'EOF'
from fastapi import APIRouter
from pydantic import BaseModel
from app.core.config import settings
from app.services.store import read_settings, write_settings

router = APIRouter(tags=["settings"])

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

@router.get("/settings")
def get_settings():
    data = read_settings(settings.station_root)
    # do not leak secrets fully (mask)
    masked = dict(data)
    for k in ["openai_api_key","github_token","render_api_key","tts_key","ocr_key","web_integration_key","whatsapp_key"]:
        if k in masked and masked[k]:
            masked[k] = masked[k][:4] + "..." + masked[k][-4:]
    return {"stored": masked, "has": {k: bool(data.get(k)) for k in data.keys()}}

@router.post("/settings")
def set_settings(payload: SettingsIn):
    current = read_settings(settings.station_root)
    d = payload.model_dump(exclude_none=True)
    current.update(d)
    write_settings(settings.station_root, current)
    return {"ok": True}
EOF

  cat > "$ROOT/backend/app/state/rooms.py" <<'EOF'
import time
from typing import Dict, Any

STATE = {
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

  cat > "$ROOT/backend/app/routers/rooms.py" <<'EOF'
from fastapi import APIRouter
from pydantic import BaseModel
from app.state.rooms import snapshot, patch

router = APIRouter(tags=["rooms"])

@router.get("/rooms")
def get_rooms():
    return snapshot()

class PatchIn(BaseModel):
    rooms: dict | None = None
    guards: dict | None = None

@router.post("/rooms")
def patch_rooms(p: PatchIn):
    return patch(p.model_dump(exclude_none=True))
EOF

  cat > "$ROOT/backend/app/state/dynamo.py" <<'EOF'
import time
from typing import Dict, Any, List

STATE: Dict[str, Any] = {
    "enabled": True,
    "last_tick": 0,
    "events": [],
    "max_events": 200
}

def add_event(kind: str, payload: dict):
    ev = {"ts": int(time.time()), "kind": kind, "payload": payload}
    STATE["events"].append(ev)
    if len(STATE["events"]) > STATE["max_events"]:
        STATE["events"] = STATE["events"][-STATE["max_events"]:]
    return ev

def tick():
    STATE["last_tick"] = int(time.time())
    add_event("tick", {"ok": True})
    return STATE

def get_state():
    return STATE
EOF

  cat > "$ROOT/backend/app/routers/dynamo.py" <<'EOF'
from fastapi import APIRouter
from pydantic import BaseModel
from app.state.dynamo import tick, get_state, add_event

router = APIRouter(tags=["dynamo"])

@router.get("/dynamo")
def dynamo_state():
    return get_state()

@router.post("/dynamo/tick")
def dynamo_tick():
    return tick()

class EvIn(BaseModel):
    kind: str
    payload: dict = {}

@router.post("/dynamo/event")
def dynamo_event(e: EvIn):
    return add_event(e.kind, e.payload)
EOF

  cat > "$ROOT/backend/app/routers/ops.py" <<'EOF'
import os, subprocess, shlex
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.core.config import settings
from app.services.store import read_settings

router = APIRouter(tags=["ops"])

def check_edit_mode(key: str):
    store = read_settings(settings.station_root)
    expected = store.get("edit_mode_key") or settings.edit_mode_key
    if key != expected:
        raise HTTPException(status_code=403, detail="Edit mode key required")

class OpsIn(BaseModel):
    edit_mode_key: str
    message: str | None = "station ops"

@router.get("/git/status")
def git_status():
    root = os.path.expanduser(settings.station_root) or os.path.expanduser("~/station_root")
    r = subprocess.run(["bash","-lc", f"cd {shlex.quote(root)} && git status -sb || true"], capture_output=True, text=True)
    return {"ok": True, "out": r.stdout[-4000:]}

@router.post("/git/push")
def git_push(p: OpsIn):
    check_edit_mode(p.edit_mode_key)
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

@router.post("/render/ping")
def render_ping(p: OpsIn):
    check_edit_mode(p.edit_mode_key)
    store = read_settings(settings.station_root)
    api = store.get("render_api_key","")
    if not api:
        raise HTTPException(status_code=400, detail="render_api_key missing in settings")
    # lightweight ping: list services (may be empty)
    import requests
    resp = requests.get("https://api.render.com/v1/services", headers={"Authorization": f"Bearer {api}"}, timeout=20)
    return {"status": resp.status_code, "sample": resp.json()[:1] if resp.headers.get("content-type","").startswith("application/json") else resp.text[:200]}
EOF

  cat > "$ROOT/backend/app/routers/__init__.py" <<'EOF'
from . import health, settings, ops, rooms, dynamo
EOF
}

write_frontend(){
  say "UUL-320: frontend (React/Vite) Windows-like + Keys + Console"
  cat > "$ROOT/frontend/package.json" <<'EOF'
{
  "name": "station-frontend",
  "private": true,
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "preview": "vite preview"
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

  cat > "$ROOT/frontend/tsconfig.json" <<'EOF'
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

  cat > "$ROOT/frontend/vite.config.ts" <<'EOF'
import { defineConfig } from "vite";

export default defineConfig({
  server: {
    host: "127.0.0.1",
    port: 5173
  }
});
EOF

  cat > "$ROOT/frontend/index.html" <<'EOF'
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

  cat > "$ROOT/frontend/src/main.tsx" <<'EOF'
import { createRoot } from "react-dom/client";
import App from "./App";

createRoot(document.getElementById("root")!).render(<App />);
EOF

  cat > "$ROOT/frontend/src/api.ts" <<'EOF'
const BASE = (import.meta as any).env?.VITE_BACKEND_URL || "http://127.0.0.1:8000";

export async function getJSON(path: string) {
  const r = await fetch(`${BASE}${path}`);
  if (!r.ok) throw new Error(`${r.status} ${r.statusText}`);
  return r.json();
}

export async function postJSON(path: string, body: any) {
  const r = await fetch(`${BASE}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body)
  });
  if (!r.ok) throw new Error(`${r.status} ${r.statusText}`);
  return r.json();
}

export const backendBase = BASE;
EOF

  cat > "$ROOT/frontend/src/App.tsx" <<'EOF'
import { useEffect, useMemo, useState } from "react";
import { backendBase, getJSON, postJSON } from "./api";

type Tab = "Landing" | "Dashboard" | "Settings" | "Console";

function cls(s: string) { return s; }

export default function App() {
  const [tab, setTab] = useState<Tab>("Landing");
  const [now, setNow] = useState<number>(Date.now());

  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(t);
  }, []);

  return (
    <div style={{ fontFamily: "system-ui, -apple-system, Segoe UI, Roboto, Arial", height: "100vh", display: "flex", flexDirection: "column" }}>
      <TopBar tab={tab} setTab={setTab} now={now} />
      <div style={{ display: "flex", flex: 1, minHeight: 0 }}>
        <SideBar tab={tab} setTab={setTab} />
        <div style={{ flex: 1, minHeight: 0, background: "#0b1220", color: "#e8eefc" }}>
          {tab === "Landing" && <Landing setTab={setTab} />}
          {tab === "Dashboard" && <Dashboard />}
          {tab === "Settings" && <Settings />}
          {tab === "Console" && <Console />}
        </div>
      </div>
      <StatusBar />
      <div style={{ position:"fixed", right: 10, bottom: 40, fontSize: 11, opacity: 0.6 }}>
        Backend: {backendBase}
      </div>
    </div>
  );
}

function TopBar({ tab, setTab, now }: { tab: Tab; setTab: (t:Tab)=>void; now:number; }) {
  return (
    <div style={{ height: 44, display:"flex", alignItems:"center", justifyContent:"space-between", padding:"0 12px", background:"#0a2a66", color:"#eaf2ff", borderBottom:"1px solid rgba(255,255,255,0.1)" }}>
      <div style={{ display:"flex", gap:10, alignItems:"center" }}>
        <div style={{ width: 26, height: 26, borderRadius: 8, background:"#163b8a", display:"grid", placeItems:"center", boxShadow:"0 6px 18px rgba(0,0,0,0.35)" }}>
          <span style={{ fontWeight: 800 }}>S</span>
        </div>
        <div style={{ fontWeight: 700 }}>Station</div>
        <div style={{ opacity: 0.75, fontSize: 12 }}>Royal Console</div>
      </div>
      <div style={{ display:"flex", gap:8 }}>
        {(["Landing","Dashboard","Settings","Console"] as Tab[]).map(t => (
          <button key={t}
            onClick={() => setTab(t)}
            style={{
              height: 28, padding:"0 10px", borderRadius: 10,
              border: "1px solid rgba(255,255,255,0.18)",
              background: tab===t ? "rgba(255,255,255,0.18)" : "rgba(0,0,0,0.15)",
              color:"#eaf2ff", cursor:"pointer"
            }}>
            {t}
          </button>
        ))}
      </div>
      <div style={{ fontSize: 12, opacity: 0.75 }}>
        {new Date(now).toLocaleTimeString()}
      </div>
    </div>
  );
}

function SideBar({ tab, setTab }: { tab: Tab; setTab:(t:Tab)=>void }) {
  const items: {t:Tab, d:string}[] = [
    { t:"Landing", d:"Start & Demo" },
    { t:"Dashboard", d:"Health & Rooms" },
    { t:"Settings", d:"Keys & Integrations" },
    { t:"Console", d:"Ops & Logs" }
  ];
  return (
    <div style={{ width: 240, background:"#07101f", borderRight:"1px solid rgba(255,255,255,0.08)", padding: 12 }}>
      <div style={{ fontSize: 12, opacity: 0.7, marginBottom: 8 }}>Navigation</div>
      {items.map(x => (
        <div key={x.t}
          onClick={() => setTab(x.t)}
          style={{
            padding:"10px 10px", borderRadius: 12, cursor:"pointer",
            background: tab===x.t ? "rgba(74,144,226,0.18)" : "transparent",
            border: tab===x.t ? "1px solid rgba(74,144,226,0.35)" : "1px solid rgba(255,255,255,0.06)",
            marginBottom: 8
          }}>
          <div style={{ fontWeight: 700 }}>{x.t}</div>
          <div style={{ fontSize: 12, opacity: 0.7 }}>{x.d}</div>
        </div>
      ))}
      <div style={{ marginTop: 12, padding: 10, borderRadius: 12, border:"1px dashed rgba(255,255,255,0.14)", opacity: 0.85 }}>
        <div style={{ fontWeight: 700 }}>Armored Dwarf</div>
        <div style={{ fontSize: 12, opacity: 0.7 }}>Brand slot reserved</div>
      </div>
    </div>
  );
}

function Landing({ setTab }: { setTab:(t:Tab)=>void }) {
  return (
    <div style={{ padding: 18, maxWidth: 980 }}>
      <div style={{ fontSize: 30, fontWeight: 900, letterSpacing: -0.4 }}>Station is Ready</div>
      <div style={{ marginTop: 6, opacity: 0.8 }}>One UI to run backend, keys, rooms, ops, and dynamo.</div>

      <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr", gap: 12, marginTop: 14 }}>
        <Card title="5-sec animation placeholder" desc="You can replace this with your dwarf cartoon + audio later." />
        <Card title="Keys bars" desc="Settings screen contains permanent bars for: API Key, TTS, Hooks, OCR, Web, WhatsApp, Email, GitHub, Render." />
      </div>

      <div style={{ marginTop: 14, display:"flex", gap:10 }}>
        <button onClick={() => setTab("Settings")} style={btnPrimary}>Open Settings</button>
        <button onClick={() => setTab("Dashboard")} style={btnGhost}>Open Dashboard</button>
        <button onClick={() => setTab("Console")} style={btnGhost}>Open Console</button>
      </div>

      <div style={{ marginTop: 16, fontSize: 12, opacity: 0.7 }}>
        Note: animation/audio are placeholders to keep this build Termux-safe and stable.
      </div>
    </div>
  );
}

function Dashboard(){
  const [health, setHealth] = useState<any>(null);
  const [rooms, setRooms] = useState<any>(null);
  const [err, setErr] = useState<string>("");

  useEffect(() => {
    (async () => {
      try {
        const h = await getJSON("/healthz");
        const r = await getJSON("/api/rooms");
        setHealth(h);
        setRooms(r);
      } catch (e:any) {
        setErr(String(e?.message || e));
      }
    })();
  }, []);

  return (
    <div style={{ padding: 18, maxWidth: 980 }}>
      <div style={{ fontSize: 22, fontWeight: 900 }}>Dashboard</div>
      {err && <div style={{ marginTop: 10, color:"#ffb4b4" }}>Error: {err}</div>}
      <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr", gap:12, marginTop: 12 }}>
        <Panel title="Backend Health" value={health ? "OK" : "..."} body={<pre style={pre}>{JSON.stringify(health, null, 2)}</pre>} />
        <Panel title="Rooms / Guards" value={rooms ? "Loaded" : "..."} body={<pre style={pre}>{JSON.stringify(rooms, null, 2)}</pre>} />
      </div>
    </div>
  );
}

function Settings(){
  const [form, setForm] = useState<any>({
    openai_api_key: localStorage.getItem("openai_api_key") || "",
    github_token: localStorage.getItem("github_token") || "",
    github_repo: localStorage.getItem("github_repo") || "",
    render_api_key: localStorage.getItem("render_api_key") || "",
    render_service_id: localStorage.getItem("render_service_id") || "",
    edit_mode_key: localStorage.getItem("edit_mode_key") || "1234",

    tts_key: localStorage.getItem("tts_key") || "",
    webhooks_url: localStorage.getItem("webhooks_url") || "",
    ocr_key: localStorage.getItem("ocr_key") || "",
    web_integration_key: localStorage.getItem("web_integration_key") || "",
    whatsapp_key: localStorage.getItem("whatsapp_key") || "",
    email_smtp: localStorage.getItem("email_smtp") || ""
  });

  const [status, setStatus] = useState<string>("");

  function saveLocal(){
    Object.keys(form).forEach(k => localStorage.setItem(k, String(form[k] ?? "")));
    setStatus("Saved to LocalStorage");
    setTimeout(() => setStatus(""), 1200);
  }

  async function saveBackend(){
    try{
      await postJSON("/api/settings", form);
      setStatus("Saved to Backend");
      setTimeout(() => setStatus(""), 1200);
    }catch(e:any){
      setStatus("Backend error: " + (e?.message||e));
    }
  }

  async function loadBackend(){
    try{
      const r = await getJSON("/api/settings");
      setStatus("Loaded (masked) from Backend");
      console.log("backend settings", r);
      setTimeout(() => setStatus(""), 1200);
    }catch(e:any){
      setStatus("Load error: " + (e?.message||e));
    }
  }

  return (
    <div style={{ padding: 18, maxWidth: 980 }}>
      <div style={{ fontSize: 22, fontWeight: 900 }}>Station Settings</div>
      <div style={{ marginTop: 6, opacity: 0.8, fontSize: 13 }}>
        Keys are stored in LocalStorage. You can also push them to backend. Ops endpoints require Edit Mode Key.
      </div>

      <div style={{ marginTop: 12, display:"grid", gridTemplateColumns:"1fr 1fr", gap:12 }}>
        <Field label="OpenAI API Key" v={form.openai_api_key} onChange={(v)=>setForm({...form, openai_api_key:v})} secret />
        <Field label="GitHub Token" v={form.github_token} onChange={(v)=>setForm({...form, github_token:v})} secret />
        <Field label="GitHub Repo (owner/repo)" v={form.github_repo} onChange={(v)=>setForm({...form, github_repo:v})} />
        <Field label="Render API Key" v={form.render_api_key} onChange={(v)=>setForm({...form, render_api_key:v})} secret />
        <Field label="Render Service ID" v={form.render_service_id} onChange={(v)=>setForm({...form, render_service_id:v})} />
        <Field label="Edit Mode Key (required for Ops)" v={form.edit_mode_key} onChange={(v)=>setForm({...form, edit_mode_key:v})} />
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
    try{
      const r = await getJSON("/api/ops/git/status");
      setOut(JSON.stringify(r, null, 2));
    }catch(e:any){
      setOut("Error: " + (e?.message||e));
    }
  }

  async function gitPush(){
    try{
      const r = await postJSON("/api/ops/git/push", { edit_mode_key: editKey, message: "station global build" });
      setOut(JSON.stringify(r, null, 2));
    }catch(e:any){
      setOut("Error: " + (e?.message||e));
    }
  }

  async function dynamoTick(){
    try{
      const r = await postJSON("/api/dynamo/tick", {});
      setOut(JSON.stringify(r, null, 2));
    }catch(e:any){
      setOut("Error: " + (e?.message||e));
    }
  }

  return (
    <div style={{ padding: 18, maxWidth: 980 }}>
      <div style={{ fontSize: 22, fontWeight: 900 }}>Station Console</div>

      <div style={{ marginTop: 10, display:"flex", gap:10, flexWrap:"wrap" }}>
        <button onClick={gitStatus} style={btnGhost}>Git Status (Backend)</button>
        <button onClick={gitPush} style={btnPrimary}>Stage + Commit + Push (Backend)</button>
        <button onClick={dynamoTick} style={btnGhost}>Dynamo Tick</button>

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

function Card({title, desc}:{title:string; desc:string}){
  return (
    <div style={{ padding: 14, borderRadius: 16, background:"rgba(255,255,255,0.04)", border:"1px solid rgba(255,255,255,0.08)" }}>
      <div style={{ fontWeight: 900 }}>{title}</div>
      <div style={{ marginTop: 6, opacity: 0.8, fontSize: 13 }}>{desc}</div>
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
      <input
        value={v}
        type={secret ? "password" : "text"}
        onChange={(e)=>onChange(e.target.value)}
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
      <div>Station Status: <span style={{ opacity: 0.85 }}>Ready</span></div>
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
  color:"#eaf2ff", cursor:"pointer", fontWeight: 700
};
EOF
}

write_runner_scripts(){
  say "UUL-900: unified runners"
  cat > "$ROOT/scripts/station_run.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
source "$ROOT/station_env.sh" || true

BACKEND_HOST="${STATION_BACKEND_HOST:-127.0.0.1}"
BACKEND_PORT="${STATION_BACKEND_PORT:-8000}"
FRONTEND_PORT="${STATION_FRONTEND_PORT:-5173}"

LOGS="$ROOT/station_logs"
mkdir -p "$LOGS"

kill_port(){
  local p="$1"
  if command -v lsof >/dev/null 2>&1; then
    for pid in $(lsof -tiTCP:"$p" -sTCP:LISTEN 2>/dev/null); do
      kill -9 "$pid" >/dev/null 2>&1 || true
    done
  fi
}

health_wait(){
  local url1="http://$BACKEND_HOST:$BACKEND_PORT/healthz"
  local url2="http://$BACKEND_HOST:$BACKEND_PORT/health"
  for i in $(seq 1 80); do
    if curl -fsS "$url1" >/dev/null 2>&1 || curl -fsS "$url2" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.5
  done
  return 1
}

kill_port "$BACKEND_PORT"
kill_port "$FRONTEND_PORT"

cd "$ROOT/backend"
if [[ -f ".venv/bin/activate" ]]; then source ".venv/bin/activate"; fi
nohup python -m uvicorn backend.app:app --host "$BACKEND_HOST" --port "$BACKEND_PORT" --reload >"$LOGS/backend.log" 2>&1 &
sleep 0.4
health_wait || { tail -n 120 "$LOGS/backend.log"; exit 1; }

cd "$ROOT/frontend"
export VITE_BACKEND_URL="http://$BACKEND_HOST:$BACKEND_PORT"
nohup npm run dev -- --host 127.0.0.1 --port "$FRONTEND_PORT" >"$LOGS/frontend.log" 2>&1 &
sleep 1

if command -v termux-open-url >/dev/null 2>&1; then
  termux-open-url "http://127.0.0.1:$FRONTEND_PORT/" >/dev/null 2>&1 || true
fi

echo "RUNNING"
echo "UI: http://127.0.0.1:$FRONTEND_PORT/"
echo "Logs: $LOGS"
EOF
  chmod +x "$ROOT/scripts/station_run.sh"

  cat > "$ROOT/scripts/station_reset_run.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
source "$ROOT/station_env.sh" || true
LOGS="$ROOT/station_logs"
mkdir -p "$LOGS"

pkg install -y lsof curl >/dev/null 2>&1 || true

BACKEND_PORT="${STATION_BACKEND_PORT:-8000}"
FRONTEND_PORT="${STATION_FRONTEND_PORT:-5173}"

kill_port(){
  local p="$1"
  if command -v lsof >/dev/null 2>&1; then
    for pid in $(lsof -tiTCP:"$p" -sTCP:LISTEN 2>/dev/null); do
      kill -9 "$pid" >/dev/null 2>&1 || true
    done
  fi
}

kill_port "$BACKEND_PORT"
kill_port "$FRONTEND_PORT"

cd "$ROOT/frontend"
rm -rf dist .vite node_modules package-lock.json >/dev/null 2>&1 || true
npm install >"$LOGS/npm_install.log" 2>&1 || { tail -n 120 "$LOGS/npm_install.log"; exit 1; }

cd "$ROOT/backend"
if [[ ! -d ".venv" ]]; then
  python -m venv .venv
fi
source "$ROOT/backend/.venv/bin/activate"
python -m pip install -U pip >/dev/null 2>&1 || true
python -m pip install -r requirements.txt >"$LOGS/pip_install.log" 2>&1 || { tail -n 120 "$LOGS/pip_install.log"; exit 1; }

bash "$ROOT/scripts/station_run.sh"
EOF
  chmod +x "$ROOT/scripts/station_reset_run.sh"
}

gitignore_readme(){
  say "Git hygiene"
  cat > "$ROOT/.gitignore" <<'EOF'
.venv/
**/.venv/
node_modules/
dist/
.vite/
__pycache__/
*.pyc
station_logs/
app_storage/
EOF

  cat > "$ROOT/README.md" <<'EOF'
# Station (Termux-safe)

## Run
- First time: `bash scripts/station_reset_run.sh`
- Next times: `bash scripts/station_run.sh`

## URLs
- Backend: http://127.0.0.1:8000/healthz
- Frontend: http://127.0.0.1:5173/

## Notes
- Settings UI stores keys in LocalStorage and can push to backend store.
- Ops Git push requires Edit Mode Key.
EOF
}

install_build(){
  say "Install deps (backend venv + frontend npm)"
  cd "$ROOT/backend"
  python -m venv .venv
  source "$ROOT/backend/.venv/bin/activate"
  python -m pip install -U pip >/dev/null 2>&1 || true
  python -m pip install -r requirements.txt >"$LOGS/pip_install.log" 2>&1

  cd "$ROOT/frontend"
  npm install >"$LOGS/npm_install.log" 2>&1
}

final_run(){
  say "Final run"
  bash "$ROOT/scripts/station_run.sh"
}

main(){
  safe_pkg
  need python
  need node
  need npm
  mk_tree
  write_env
  write_backend
  write_frontend
  write_runner_scripts
  gitignore_readme
  install_build
  final_run
  say "DONE"
}

main "$@"
