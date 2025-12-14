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
