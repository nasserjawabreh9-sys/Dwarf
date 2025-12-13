#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
cmd="${1:-}"
case "$cmd" in
  run)
    bash "$ROOT/backend/run_backend_official.sh"
    echo "Ops UI: file://$ROOT/frontend/ops/index.html"
    ;;
  stop)
    bash "$ROOT/scripts/uul_kill_ports.sh" || true
    ;;
  status)
    curl -s http://127.0.0.1:8000/healthz || true
    echo
    ;;
  *)
    echo "Usage: $0 {run|stop|status}"
    exit 1
    ;;
esac
