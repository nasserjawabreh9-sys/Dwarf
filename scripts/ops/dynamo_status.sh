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
