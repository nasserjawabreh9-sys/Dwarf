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
