#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="${STATION_REPO_DIR:-$HOME/station_root}"
cd "$ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repo here. Init..."
  git init
fi

git add backend scripts || true

msg="${1:-enterprise render fix: asgi + start + healthz}"
git commit -m "$msg" || true

echo "OK: committed. If remote exists, push manually:"
echo "git push -u origin main"
