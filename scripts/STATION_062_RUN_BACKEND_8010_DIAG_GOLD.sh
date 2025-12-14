#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
BACK="$ROOT/backend"
LOGDIR="$ROOT/station_logs"
mkdir -p "$LOGDIR"

PORT="${PORT:-8010}"
export PORT

echo "========================================"
echo "STATION_062_RUN_BACKEND_8010_DIAG_GOLD"
echo "root: $ROOT"
echo "port: $PORT"
date
echo "========================================"
echo

# kill any existing on same port by PID
pids="$(ps -ef | grep -E "uvicorn|python.*-m uvicorn" | grep -F -- "--port $PORT" | grep -v grep | awk '{print $2}' | tr '\n' ' ' | sed 's/  */ /g' || true)"
if [ -n "${pids:-}" ]; then
  echo ">>> Killing existing PIDs on port $PORT: $pids"
  for pid in $pids; do kill -9 "$pid" >/dev/null 2>&1 || true; done
  sleep 0.5
fi

cd "$BACK"

echo ">>> Starting backend (nohup) ..."
: > "$LOGDIR/backend_8010.log"
nohup python -m uvicorn app.main:app --host 0.0.0.0 --port "$PORT" > "$LOGDIR/backend_8010.log" 2>&1 &
sleep 1

echo ">>> Process check:"
ps -ef | grep -E "uvicorn|python.*-m uvicorn" | grep -v grep || true
echo

echo ">>> Log tail:"
tail -n 80 "$LOGDIR/backend_8010.log" || true
echo

echo ">>> Health check:"
if curl -fsS "http://127.0.0.1:$PORT/healthz" >/dev/null 2>&1; then
  echo "OK: backend up on :$PORT"
  curl -fsS "http://127.0.0.1:$PORT/healthz" || true
  echo
else
  echo "FAIL: cannot connect to :$PORT"
  echo ">>> Re-print log tail (more):"
  tail -n 200 "$LOGDIR/backend_8010.log" || true
  exit 1
fi

echo "DONE"
