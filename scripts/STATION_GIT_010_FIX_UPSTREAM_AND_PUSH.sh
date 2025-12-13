#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
cd "$ROOT"

echo "=== [GIT_010] Fix upstream + push ==="
echo "Repo: $ROOT"
echo

# Ensure git
git status >/dev/null

# Ensure main
git branch -M main

# Stage the scripts too (optional, but recommended)
git add scripts/STATION_RENDER_010_PATCH_PRECHECK.sh scripts/STATION_RENDER_020_GIT_COMMIT_PUSH.sh scripts/STATION_RENDER_030_LOCAL_SANITY.sh 2>/dev/null || true
git commit -m "ops: add render patch scripts" || true

# Ensure origin exists (replace OWNER/REPO before running!)
if ! git remote get-url origin >/dev/null 2>&1; then
  echo "ERROR: origin remote not set."
  echo "ACTION: Set it first:"
  echo "  git remote add origin https://github.com/OWNER/REPO.git"
  exit 1
fi

echo "Origin:"
git remote -v | sed -n '1,4p'
echo

# Push and set upstream
git push --set-upstream origin main

echo
echo "OK: upstream set and pushed."
