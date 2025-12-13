#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
cmd="${1:-}"
msg="${2:-station update}"

case "$cmd" in
  init)
    cd "$ROOT"
    git init
    git branch -M main
    git add -A
    git commit -m "init station" || true
    echo "Git initialized. Add remote manually: git remote add origin <url>"
    ;;
  status)
    cd "$ROOT"
    git status -sb || true
    ;;
  push)
    cd "$ROOT"
    git add -A
    git commit -m "$msg" || true
    git push -u origin main
    ;;
  *)
    echo "usage: uul_git.sh init|status|push [message]"
    exit 2
    ;;
esac
