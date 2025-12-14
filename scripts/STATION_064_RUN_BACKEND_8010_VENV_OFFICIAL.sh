#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
BACK="$ROOT/backend"
LOGDIR="$ROOT/station_logs"
mkdir -p "$LOGDIR"

PORT="${PORT:-8010}"
export PORT
export STATION_EDIT_KEY="${STATION_EDIT_KEY:-1234}"

cd "$BACK"
source .venv/bin/activate

echo ">>> stopping uvicorn (best-effort)"
pkill -f "uvicorn.*--port $PORT" >/dev/null 2>&1 || true
pkill -f "python.*-m uvicorn.*--port $PORT" >/dev/null 2>&1 || true
sleep 1

echo ">>> starting backend on :$PORT (venv)"
: > "$LOGDIR/backend_${PORT}.log"
nohup python -m uvicorn app.main:app --host 0.0.0.0 --port "$PORT" \
  > "$LOGDIR/backend_${PORT}.log" 2>&1 &

sleep 1
echo ">>> tail:"
tail -n 40 "$LOGDIR/backend_${PORT}.log" || true
echo ">>> health:"
curl -fsS "http://127.0.0.1:${PORT}/healthz" && echo
echo "OK"
