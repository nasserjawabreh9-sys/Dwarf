#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
BACK="$ROOT/backend"
FRONT="$ROOT/frontend"
OPS="$ROOT/scripts"
LOGS="$ROOT/station_logs"
mkdir -p "$BACK" "$FRONT" "$OPS" "$LOGS"

echo "=== GLOBAL FACTORY DEPLOY (Termux-Safe) ==="

# ------------------------
# 1) Kernel + Guards + Ops
# ------------------------
cat > "$BACK/asgi.py" <<'PY'
from fastapi import FastAPI, Header, HTTPException
from typing import Any
import os, json, pathlib, subprocess, platform, tarfile, time

EDIT_KEY = os.environ.get("STATION_EDIT_KEY", "1234")
ROOT = os.environ.get("STATION_ROOT", str(pathlib.Path.home() / "station_root"))

app = FastAPI(title="Station Factory Kernel", version="1.0.0")

class Kernel:
    def __init__(self):
        self.rooms: dict[str, Any] = {}

    def register(self, name, fn):
        self.rooms[name] = fn

    def run(self, name, payload):
        if name not in self.rooms:
            return {"error": "room not found", "available": sorted(self.rooms)}
        return self.rooms[name](payload or {})

kernel = Kernel()

def guard(key: str | None):
    if key != EDIT_KEY:
        raise HTTPException(status_code=403, detail="edit key required")

# -------- Rooms --------
def doctor(_):
    def cmd(s):
        try:
            return subprocess.check_output(s, shell=True, timeout=3).decode()
        except Exception:
            return ""
    return {
        "status": "ok",
        "python": cmd("python -V"),
        "node": cmd("node -v"),
        "npm": cmd("npm -v"),
        "git": cmd("git --version"),
        "platform": platform.platform(),
        "root": ROOT
    }

def rooms_list(_):
    return {"rooms": sorted(kernel.rooms)}

def fs(payload):
    base = pathlib.Path(ROOT)
    action = payload.get("action")
    path = (base / payload.get("path","")).resolve()
    if base not in path.parents and path != base:
        return {"error": "forbidden path"}
    if action == "ls":
        return {"files": [p.name for p in path.iterdir()]}
    if action == "read":
        return {"content": path.read_text(errors="ignore")}
    if action == "write":
        path.write_text(payload.get("content",""))
        return {"ok": True}
    return {"error": "unknown fs action"}

def env_room(payload):
    keys = payload.get("keys", [])
    return {k: os.environ.get(k) for k in keys}

def snapshot(_):
    snap = pathlib.Path(ROOT) / "snapshots"
    snap.mkdir(exist_ok=True)
    name = f"snapshot_{int(time.time())}.tgz"
    with tarfile.open(snap/name, "w:gz") as tar:
        tar.add(ROOT, arcname="station_root")
    return {"snapshot": str(snap/name)}

def restore(payload):
    f = payload.get("file")
    if not f:
        return {"error": "file required"}
    with tarfile.open(f, "r:gz") as tar:
        tar.extractall(path=pathlib.Path(ROOT).parent)
    return {"restored": f}

# register
kernel.register("doctor", doctor)
kernel.register("rooms_list", rooms_list)
kernel.register("fs", fs)
kernel.register("env", env_room)
kernel.register("snapshot", snapshot)
kernel.register("restore", restore)

# -------- API --------
@app.get("/healthz")
def healthz():
    return {"ok": True, "rooms": len(kernel.rooms)}

@app.get("/ops/rooms")
def ops_rooms():
    return {"rooms": sorted(kernel.rooms)}

@app.post("/ops/run/{room}")
def ops_run(room: str, payload: dict | None = None, x_edit_key: str | None = Header(None)):
    guard(x_edit_key)
    return kernel.run(room, payload or {})
PY

# ------------------------
# 2) Backend Runner (official)
# ------------------------
cat > "$BACK/run_backend_official.sh" <<'BASH2'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
LOGS="$ROOT/station_logs"; mkdir -p "$LOGS"
cd "$ROOT/backend"
source .venv/bin/activate 2>/dev/null || true
nohup python -m uvicorn asgi:app --host 127.0.0.1 --port 8000 >"$LOGS/backend.log" 2>&1 &
sleep 1
curl -fs http://127.0.0.1:8000/healthz >/dev/null && echo "Backend OK"
BASH2
chmod +x "$BACK/run_backend_official.sh"

# ------------------------
# 3) Ops UI (Static)
# ------------------------
mkdir -p "$FRONT/ops"
cat > "$FRONT/ops/index.html" <<'HTML'
<!doctype html>
<html>
<head><meta charset="utf-8"><title>Station Ops</title></head>
<body>
<h2>Station Ops</h2>
<input id="key" placeholder="Edit Key">
<button onclick="load()">Load Rooms</button>
<ul id="rooms"></ul>
<pre id="out"></pre>
<script>
async function load(){
  const r = await fetch("http://127.0.0.1:8000/ops/rooms");
  const j = await r.json();
  const ul = document.getElementById("rooms");
  ul.innerHTML="";
  j.rooms.forEach(x=>{
    const li=document.createElement("li");
    const b=document.createElement("button");
    b.textContent="Run "+x;
    b.onclick=()=>run(x);
    li.appendChild(b);
    ul.appendChild(li);
  });
}
async function run(room){
  const key=document.getElementById("key").value;
  const r=await fetch("http://127.0.0.1:8000/ops/run/"+room,{
    method:"POST",
    headers:{"Content-Type":"application/json","X-EDIT-KEY":key},
    body:"{}"
  });
  document.getElementById("out").textContent=await r.text();
}
</script>
</body>
</html>
HTML

# ------------------------
# 4) Final run
# ------------------------
echo "=== START BACKEND ==="
bash "$BACK/run_backend_official.sh"

echo "=== DONE ==="
echo "Backend: http://127.0.0.1:8000"
echo "Ops UI:  file://$FRONT/ops/index.html"
echo "Edit Key: 1234"
