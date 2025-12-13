#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
LOGS="$ROOT/station_logs"; mkdir -p "$LOGS"
cmd="${1:-status}"; shift || true

trace(){
  echo "[ops] $(date -Iseconds) $cmd $*" >> "$LOGS/ops_trace.log"
}
trace "$@"

case "$cmd" in
  status)
    echo "=== STATUS ==="
    bash "$ROOT/scripts/uul_ports.sh" show || true
    echo ""
    curl -fsS http://127.0.0.1:8000/healthz 2>/dev/null && echo "" || echo "Backend healthz not reachable"
    ;;
  build)   bash "$ROOT/scripts/uul_build.sh" ;;
  run)     bash "$ROOT/scripts/uul_run.sh" ;;
  stop)    bash "$ROOT/scripts/uul_stop.sh" ;;
  restart) bash "$ROOT/scripts/uul_restart.sh" ;;
  doctor)  bash "$ROOT/scripts/uul_doctor.sh" ;;
  snapshot)bash "$ROOT/scripts/uul_snapshot.sh" ;;
  backup)  bash "$ROOT/scripts/uul_backup.sh" ;;
  restore) bash "$ROOT/scripts/uul_restore.sh" "${1:-}" ;;
  logs)    bash "$ROOT/scripts/uul_logs.sh" "${1:-backend}" ;;
  harden)  bash "$ROOT/scripts/uul_harden_local.sh" ;;
  git)     bash "$ROOT/scripts/uul_git.sh" "${1:-status}" "${2:-station update}" ;;
  render)  bash "$ROOT/scripts/uul_render_check.sh" "${1:-}" ;;
  *)
    echo "usage: station_ops.sh status|build|run|stop|restart|doctor|snapshot|backup|restore|logs|harden|git|render"
    exit 2
    ;;
esac
