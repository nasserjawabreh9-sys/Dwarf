#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
BACK="$ROOT/backend"
APP="$BACK/app"
META="$ROOT/station_meta"
LOGS="$ROOT/global/logs"
OPS="$ROOT/scripts/ops"

cd "$ROOT"

echo "============================================"
echo "STATION_070_RELIABILITY_PACK_GOLD"
date
echo "root: $ROOT"
echo "============================================"
echo

mkdir -p "$LOGS" "$META/pids" "$META/logs" "$META/dynamo" "$META/rooms" "$OPS"

# -----------------------------
# 1) Backend: add status router
# -----------------------------
mkdir -p "$APP/routers"

cat > "$APP/routers/status.py" <<'PY'
from __future__ import annotations
from fastapi import APIRouter
from pathlib import Path
import os, time, json

router = APIRouter()

ROOT = Path(os.environ.get("STATION_ROOT", str(Path.home() / "station_root")))
META = ROOT / "station_meta"
LOGS = ROOT / "global" / "logs"
BACK = ROOT / "backend"

def _exists(p: Path) -> bool:
    try:
        return p.exists()
    except Exception:
        return False

def _read_text(p: Path, limit: int = 4000) -> str:
    try:
        return p.read_text(encoding="utf-8", errors="ignore")[:limit]
    except Exception:
        return ""

def _pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except Exception:
        return False

def _pidfile_status(pidfile: Path) -> dict:
    if not _exists(pidfile):
        return {"pidfile": str(pidfile), "running": False, "pid": None}
    raw = _read_text(pidfile).strip()
    try:
        pid = int(raw)
    except Exception:
        return {"pidfile": str(pidfile), "running": False, "pid": None, "raw": raw}
    return {"pidfile": str(pidfile), "running": _pid_alive(pid), "pid": pid}

@router.get("/api/status")
def status():
    # runtime markers
    dyn_pid = META / "pids" / "dynamo_worker.pid"
    loop_pid = META / "pids" / "loop_worker.pid"

    # db/state indicators
    station_db = ROOT / "state" / "station.db"
    agent_q = BACK / "agent_queue.sqlite3"

    # logs indicators
    dyn_log = META / "logs" / "dynamo_worker.log"
    loop_log = META / "logs" / "loop_worker.log"

    now = int(time.time())
    payload = {
        "ok": True,
        "ts": now,
        "root": str(ROOT),
        "paths": {
            "station_db": str(station_db),
            "agent_queue": str(agent_q),
            "logs_dir": str(LOGS),
            "meta_dir": str(META),
        },
        "files": {
            "station_db_exists": _exists(station_db),
            "agent_queue_exists": _exists(agent_q),
            "dynamo_log_exists": _exists(dyn_log),
            "loop_log_exists": _exists(loop_log),
        },
        "process": {
            "dynamo_worker": _pidfile_status(dyn_pid),
            "loop_worker": _pidfile_status(loop_pid),
        },
        "hints": {
            "start": "/ops/loop/start  | /ops/dynamo/start",
            "stop":  "/ops/loop/stop   | /ops/dynamo/stop",
            "status":"/api/status",
        }
    }
    return payload
PY

# -----------------------------
# 2) Wire router into FastAPI
# -----------------------------
MAIN_CANDIDATES=(
  "$APP/main.py"
  "$BACK/main.py"
  "$BACK/asgi.py"
)

MAIN_FILE=""
for f in "${MAIN_CANDIDATES[@]}"; do
  if [ -f "$f" ]; then MAIN_FILE="$f"; break; fi
done

if [ -z "$MAIN_FILE" ]; then
  echo "ERROR: Cannot find backend main entry (app/main.py | backend/main.py | backend/asgi.py)"
  exit 1
fi

echo "backend_entry: $MAIN_FILE"

python - <<'PY' "$MAIN_FILE"
import sys, re, pathlib
p = pathlib.Path(sys.argv[1])
s = p.read_text(encoding="utf-8", errors="ignore")

# 1) ensure import
if "from app.routers.status import router as status_router" not in s and "app.routers.status" not in s:
    # add near other imports
    ins = "from app.routers.status import router as status_router\n"
    # try insert after fastapi import
    m = re.search(r"(from fastapi import .*\n)", s)
    if m:
        s = s[:m.end()] + ins + s[m.end():]
    else:
        s = ins + s

# 2) ensure include_router call
if "include_router(status_router" not in s:
    # find "app = FastAPI"
    m = re.search(r"app\s*=\s*FastAPI\([^\n]*\)\s*\n", s)
    if m:
        anchor = m.end()
        inject = "\n# --- Station: Status API ---\napp.include_router(status_router)\n"
        s = s[:anchor] + inject + s[anchor:]
    else:
        # fallback append
        s += "\n\n# --- Station: Status API ---\napp.include_router(status_router)\n"

p.write_text(s, encoding="utf-8")
print("patched:", str(p))
PY

# -----------------------------
# 3) Ops scripts: start/stop/status (dynamo/loop)
# -----------------------------
cat > "$OPS/dynamo_start.sh" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
META="$ROOT/station_meta"
LOG="$META/logs/dynamo_worker.log"
PID="$META/pids/dynamo_worker.pid"

mkdir -p "$(dirname "$LOG")" "$(dirname "$PID")"

# prevent duplicate
if [ -f "$PID" ]; then
  old="$(cat "$PID" 2>/dev/null || true)"
  if [ -n "${old:-}" ] && kill -0 "$old" 2>/dev/null; then
    echo "dynamo_worker already running pid=$old"
    exit 0
  fi
fi

# prefer existing runner if present
if [ -f "$ROOT/global/loop5_agent_runner.sh" ]; then
  nohup bash "$ROOT/global/loop5_agent_runner.sh" >>"$LOG" 2>&1 &
else
  # fallback: run a lightweight python loop if file missing
  nohup python - <<'PY' >>"$LOG" 2>&1 &
import time
print("[dynamo_worker] fallback worker started")
while True:
    time.sleep(2)
PY
fi

echo $! > "$PID"
echo "dynamo_worker started pid=$(cat "$PID") log=$LOG"
SH

cat > "$OPS/dynamo_stop.sh" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
PID="$ROOT/station_meta/pids/dynamo_worker.pid"
if [ ! -f "$PID" ]; then
  echo "dynamo_worker not running (no pidfile)"
  exit 0
fi
pid="$(cat "$PID" 2>/dev/null || true)"
if [ -n "${pid:-}" ] && kill -0 "$pid" 2>/dev/null; then
  kill "$pid" 2>/dev/null || true
  sleep 1
  kill -9 "$pid" 2>/dev/null || true
  echo "dynamo_worker stopped pid=$pid"
else
  echo "dynamo_worker not alive pid=$pid"
fi
rm -f "$PID" || true
SH

cat > "$OPS/dynamo_status.sh" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
PID="$ROOT/station_meta/pids/dynamo_worker.pid"
if [ ! -f "$PID" ]; then
  echo "dynamo_worker: DOWN (no pidfile)"
  exit 0
fi
pid="$(cat "$PID" 2>/dev/null || true)"
if [ -n "${pid:-}" ] && kill -0 "$pid" 2>/dev/null; then
  echo "dynamo_worker: UP pid=$pid"
else
  echo "dynamo_worker: DOWN pid=$pid"
fi
SH

# Loop worker placeholders (if you have a dedicated loop worker later)
cat > "$OPS/loop_start.sh" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
META="$ROOT/station_meta"
LOG="$META/logs/loop_worker.log"
PID="$META/pids/loop_worker.pid"
mkdir -p "$(dirname "$LOG")" "$(dirname "$PID")"
if [ -f "$PID" ]; then
  old="$(cat "$PID" 2>/dev/null || true)"
  if [ -n "${old:-}" ] && kill -0 "$old" 2>/dev/null; then
    echo "loop_worker already running pid=$old"
    exit 0
  fi
fi
# If you have a real loop runner script, place it here.
nohup bash -lc 'while true; do sleep 3; done' >>"$LOG" 2>&1 &
echo $! > "$PID"
echo "loop_worker started pid=$(cat "$PID") log=$LOG"
SH

cat > "$OPS/loop_stop.sh" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
PID="$ROOT/station_meta/pids/loop_worker.pid"
if [ ! -f "$PID" ]; then
  echo "loop_worker not running (no pidfile)"
  exit 0
fi
pid="$(cat "$PID" 2>/dev/null || true)"
if [ -n "${pid:-}" ] && kill -0 "$pid" 2>/dev/null; then
  kill "$pid" 2>/dev/null || true
  sleep 1
  kill -9 "$pid" 2>/dev/null || true
  echo "loop_worker stopped pid=$pid"
else
  echo "loop_worker not alive pid=$pid"
fi
rm -f "$PID" || true
SH

cat > "$OPS/loop_status.sh" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
PID="$ROOT/station_meta/pids/loop_worker.pid"
if [ ! -f "$PID" ]; then
  echo "loop_worker: DOWN (no pidfile)"
  exit 0
fi
pid="$(cat "$PID" 2>/dev/null || true)"
if [ -n "${pid:-}" ] && kill -0 "$pid" 2>/dev/null; then
  echo "loop_worker: UP pid=$pid"
else
  echo "loop_worker: DOWN pid=$pid"
fi
SH

chmod +x "$OPS/"*.sh

# -----------------------------
# 4) Guard: keep worker alive
# -----------------------------
cat > "$ROOT/scripts/guards/guard_dynamo_keepalive.sh" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
OPS="$ROOT/scripts/ops"
LOG="$ROOT/global/logs/guard_dynamo_keepalive.log"
mkdir -p "$(dirname "$LOG")"

echo "[guard] started $(date)" >>"$LOG"

while true; do
  if ! bash "$OPS/dynamo_status.sh" >>"$LOG" 2>&1; then
    :
  fi

  # if DOWN -> start
  if bash "$OPS/dynamo_status.sh" | grep -q "DOWN"; then
    echo "[guard] restarting dynamo $(date)" >>"$LOG"
    bash "$OPS/dynamo_start.sh" >>"$LOG" 2>&1 || true
  fi

  sleep 5
done
SH

chmod +x "$ROOT/scripts/guards/guard_dynamo_keepalive.sh"

# -----------------------------
# 5) Quick smoke: backend health + status
# -----------------------------
echo
echo ">>> Smoke test"
if curl -fsS http://127.0.0.1:8000/healthz >/dev/null 2>&1; then
  echo "backend: OK on :8000"
  echo "status:"
  curl -fsS http://127.0.0.1:8000/api/status || true
else
  echo "backend: not responding on :8000 (start backend then re-run smoke)"
fi

echo
echo "NEXT COMMANDS:"
echo "  bash $OPS/dynamo_start.sh"
echo "  bash $ROOT/scripts/guards/guard_dynamo_keepalive.sh &"
echo "  curl -fsS http://127.0.0.1:8000/api/status | python -m json.tool"
echo "============================================"
echo "DONE: STATION_070_RELIABILITY_PACK_GOLD"
echo "============================================"
