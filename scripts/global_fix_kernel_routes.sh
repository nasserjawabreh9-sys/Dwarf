#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
BACK="$ROOT/backend"
LOGS="$ROOT/station_logs"; mkdir -p "$LOGS"

echo "=== [GLOBAL] Fix Kernel Routes (Termux-Safe) ==="
echo "ROOT=$ROOT"

# 0) Guards: kill ports
if [[ -x "$ROOT/scripts/uul_kill_ports.sh" ]]; then
  bash "$ROOT/scripts/uul_kill_ports.sh" >/dev/null 2>&1 || true
else
  # fallback kill
  for p in 8000 5173; do
    for pid in $(lsof -tiTCP:"$p" -sTCP:LISTEN 2>/dev/null); do
      kill -9 "$pid" >/dev/null 2>&1 || true
    done
  done
fi

# 1) Ensure asgi.py exists with ops routes (hard overwrite to remove ambiguity)
cat > "$BACK/asgi.py" <<'PY'
from fastapi import FastAPI
from typing import Any

app = FastAPI(title="Station Kernel (Termux-Safe)", version="1.0.0")

class StationKernel:
    def __init__(self, app: FastAPI):
        self.app = app
        self.rooms: dict[str, Any] = {}

    def register_room(self, name: str, fn):
        self.rooms[name] = fn

    def run_room(self, name: str, payload=None):
        if name not in self.rooms:
            return {"error": "room not found", "room": name, "available": sorted(self.rooms.keys())}
        return self.rooms[name](payload or {})

kernel = StationKernel(app)

# ---- Rooms ----
try:
    from rooms_doctor import doctor
    kernel.register_room("doctor", doctor)
except Exception:
    pass

def _rooms_list(_payload=None):
    return {"rooms": sorted(kernel.rooms.keys())}

kernel.register_room("rooms_list", _rooms_list)

# ---- Endpoints ----
@app.get("/healthz")
def healthz():
    return {"ok": True, "kernel": True, "rooms": len(kernel.rooms), "entry": "asgi.kernel"}

@app.get("/ops/rooms")
def ops_rooms():
    return {"rooms": sorted(kernel.rooms.keys())}

@app.post("/ops/run/{room}")
def ops_run(room: str, payload: dict | None = None):
    return kernel.run_room(room, payload or {})
PY

# 2) Ensure doctor room exists (safe)
cat > "$BACK/rooms_doctor.py" <<'PY'
import os, platform, subprocess, pathlib

def _cmd(s: str) -> str:
    try:
        out = subprocess.check_output(s, shell=True, stderr=subprocess.STDOUT, timeout=3)
        return out.decode("utf-8", "ignore").strip()
    except Exception:
        return ""

def doctor(_payload=None):
    root = os.environ.get("STATION_ROOT", str(pathlib.Path.home() / "station_root"))
    return {
        "status": "ok",
        "mode": "termux-safe",
        "python": _cmd("python -V"),
        "node": _cmd("node -v"),
        "npm": _cmd("npm -v"),
        "git": _cmd("git --version"),
        "platform": platform.platform(),
        "root": root
    }
PY

# 3) Force run_backend_official.sh to run ONLY asgi:app
cat > "$BACK/run_backend_official.sh" <<'BASH2'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
LOGS="$ROOT/station_logs"; mkdir -p "$LOGS"
BACK="$ROOT/backend"

# kill ports safely
if [[ -x "$ROOT/scripts/uul_kill_ports.sh" ]]; then
  bash "$ROOT/scripts/uul_kill_ports.sh" >/dev/null 2>&1 || true
else
  for p in 8000 5173; do
    for pid in $(lsof -tiTCP:"$p" -sTCP:LISTEN 2>/dev/null); do
      kill -9 "$pid" >/dev/null 2>&1 || true
    done
  done
fi

cd "$BACK"
if [[ -d .venv ]]; then
  source .venv/bin/activate
fi

# run ONLY asgi:app
nohup python -m uvicorn asgi:app --host 127.0.0.1 --port 8000 >"$LOGS/backend.log" 2>&1 &
sleep 1

# verify healthz + ops
curl -fsS http://127.0.0.1:8000/healthz >/dev/null 2>&1 || {
  echo "Backend failed. Tail:"
  tail -n 160 "$LOGS/backend.log" || true
  exit 1
}

# hard checks
TITLE="$(curl -s http://127.0.0.1:8000/openapi.json | head -n 40 | tr -d '\n' | sed 's/.*"title":"\([^"]*\)".*/\1/' || true)"
OPS_OK="$(curl -s http://127.0.0.1:8000/ops/rooms || true)"

echo "OK: backend up"
echo "Backend: http://127.0.0.1:8000"
echo "OpenAPI title: ${TITLE:-unknown}"
echo "ops/rooms: $OPS_OK"
BASH2
chmod +x "$BACK/run_backend_official.sh"

# 4) Patch uul_run.sh + station_ops.sh to use run_backend_official.sh when possible
if [[ -f "$ROOT/scripts/uul_run.sh" ]]; then
  sed -i 's/python -m uvicorn .*backend\.app:app.*/bash "$ROOT\/backend\/run_backend_official.sh"/g' "$ROOT/scripts/uul_run.sh" 2>/dev/null || true
  sed -i 's/python -m uvicorn .*asgi:app.*/bash "$ROOT\/backend\/run_backend_official.sh"/g' "$ROOT/scripts/uul_run.sh" 2>/dev/null || true
fi

if [[ -f "$ROOT/scripts/station_ops.sh" ]]; then
  # replace any backend run command with official
  sed -i 's/python -m uvicorn .*backend\.app:app.*/bash "$ROOT\/backend\/run_backend_official.sh"/g' "$ROOT/scripts/station_ops.sh" 2>/dev/null || true
  sed -i 's/python -m uvicorn .*asgi:app.*/bash "$ROOT\/backend\/run_backend_official.sh"/g' "$ROOT/scripts/station_ops.sh" 2>/dev/null || true
fi

# 5) Run backend official + verify routes end-to-end
echo "=== RUN OFFICIAL BACKEND ==="
bash "$BACK/run_backend_official.sh"

echo "=== VERIFY ==="
echo "- /healthz"
curl -s http://127.0.0.1:8000/healthz ; echo
echo "- /ops/rooms"
curl -s http://127.0.0.1:8000/ops/rooms ; echo
echo "- /ops/run/doctor"
curl -s -X POST http://127.0.0.1:8000/ops/run/doctor ; echo
echo "- /ops/run/rooms_list"
curl -s -X POST http://127.0.0.1:8000/ops/run/rooms_list ; echo

echo "=== DONE: Kernel routes are live on 8000 ==="
