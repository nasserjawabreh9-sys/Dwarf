#!/data/data/com.termux/files/usr/bin/bash
set -e

cmd="${1:-}"
shift || true

case "$cmd" in
  dynamo)
    sub="${1:-}"
    shift || true
    case "$sub" in
      start)
        mode="${1:-TRIAL-1}"
        pipeline="${2:-bootstrap_validate}"
        root="${3:-1000}"
        python scripts/ops/dynamo.py "$mode" "$pipeline" "$root"
        ;;
      *)
        echo "Usage: st dynamo start <MODE> <PIPELINE> [ROOT_ID]"
        echo "Example: st dynamo start TRIAL-1 bootstrap_validate 1000"
        exit 1
        ;;
    esac
    ;;
  *)
    echo "Usage: st <command>"
    echo "Commands:"
    echo "  dynamo start <MODE> <PIPELINE> [ROOT_ID]"
    exit 1
    ;;
esac

