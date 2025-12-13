#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
BACK="$ROOT/backend"
LOGDIR="$ROOT/station_logs"
mkdir -p "$LOGDIR"

PORT="${PORT:-8010}"
echo ">>> [backend] stopping any previous on port=$PORT (best-effort)"
pkill -f "uvicorn.*--port $PORT" >/dev/null 2>&1 || true
pkill -f "python -m uvicorn.*--port $PORT" >/dev/null 2>&1 || true

cd "$BACK"
echo ">>> [backend] starting on :$PORT"
nohup python -m uvicorn app.main:app --host 0.0.0.0 --port "$PORT" > "$LOGDIR/backend.log" 2>&1 &
sleep 1
echo ">>> [backend] tail:"
tail -n 25 "$LOGDIR/backend.log" || true
echo ">>> [backend] health:"
curl -fsS "http://127.0.0.1:$PORT/healthz" && echo
echo "OK"
