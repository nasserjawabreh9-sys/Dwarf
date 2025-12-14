#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
BACK="$ROOT/backend"
LOGDIR="$ROOT/station_logs"
mkdir -p "$LOGDIR"

PORT="${PORT:-8010}"
export PORT
export STATION_ROOT="$ROOT"
export STATION_ENV="${STATION_ENV:-prod}"
export STATION_EDIT_KEY="${STATION_EDIT_KEY:-1234}"

echo ">>> [check] if backend already up on :$PORT"
if curl -fsS "http://127.0.0.1:${PORT}/healthz" >/dev/null 2>&1; then
  echo "OK: backend already running on :$PORT (no restart)"
  curl -fsS "http://127.0.0.1:${PORT}/api/status" | python -m json.tool || true
  exit 0
fi

echo ">>> [start] backend on :$PORT"
cd "$BACK"
if [ -f ".venv/bin/activate" ]; then
  source .venv/bin/activate
fi

: > "$LOGDIR/backend_${PORT}.log"
nohup python -m uvicorn app.main:app --host 0.0.0.0 --port "$PORT" \
  > "$LOGDIR/backend_${PORT}.log" 2>&1 &

sleep 1

echo ">>> [tail]"
tail -n 120 "$LOGDIR/backend_${PORT}.log" || true

echo ">>> [health]"
curl -fsS "http://127.0.0.1:${PORT}/healthz" && echo
echo "OK"
