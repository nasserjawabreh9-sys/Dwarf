#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
LOGS="$ROOT/station_logs"
mkdir -p "$LOGS"

target="${1:-}"
case "$target" in
  backend)  tail -n 200 "$LOGS/backend.log" 2>/dev/null || true ;;
  frontend) tail -n 200 "$LOGS/frontend.log" 2>/dev/null || true ;;
  trace)    tail -n 200 "$LOGS/ops_trace.log" 2>/dev/null || true ;;
  *) echo "usage: uul_logs.sh backend|frontend|trace"; exit 2 ;;
esac
