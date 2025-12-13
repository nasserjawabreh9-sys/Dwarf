#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
LOGS="$ROOT/station_logs"
mkdir -p "$LOGS"

echo "=== [040] STOP ALL listeners on 8000/8080/8810/5173 ==="
kill_port(){ local p="$1"; for pid in $(lsof -tiTCP:"$p" -sTCP:LISTEN 2>/dev/null || true); do
  echo "KILL port=$p pid=$pid"
  kill -9 "$pid" >/dev/null 2>&1 || true
done; }
kill_port 8000
kill_port 8080
kill_port 8810
kill_port 5173

echo "=== [040] RUN factory entrypoint backend.asgi:app ==="
cd "$ROOT"

# Try activate venv if exists (non-fatal)
if [ -f "$ROOT/backend/.venv/bin/activate" ]; then
  source "$ROOT/backend/.venv/bin/activate" || true
fi

# Run on 8000 explicitly for local
nohup python -m uvicorn backend.asgi:app --host 127.0.0.1 --port 8000 >"$LOGS/backend_factory.log" 2>&1 &
sleep 1

echo "=== [040] WHO IS RUNNING? ==="
curl -s http://127.0.0.1:8000/openapi.json | head -n 40 || true
echo

echo "=== [040] SMOKE (must NOT be 404) ==="
echo "[healthz]"; curl -s -i http://127.0.0.1:8000/healthz | head -n 20; echo
echo "[info]";    curl -s -i http://127.0.0.1:8000/info   | head -n 40; echo
echo "[ops/rooms]"; curl -s -i http://127.0.0.1:8000/ops/rooms | head -n 40; echo
echo "[ops/run/doctor]"; curl -s -i -X POST http://127.0.0.1:8000/ops/run/doctor -H "X-EDIT-KEY: 1234" | head -n 60; echo

echo "=== [040] DONE ==="
echo "Backend: http://127.0.0.1:8000"
echo "Log:    $LOGS/backend_factory.log"
