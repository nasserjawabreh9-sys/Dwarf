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
