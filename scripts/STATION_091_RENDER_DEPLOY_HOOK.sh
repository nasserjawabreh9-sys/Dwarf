#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
cd "$ROOT"

: "${RENDER_DEPLOY_HOOK:?Set it first: export RENDER_DEPLOY_HOOK='https://api.render.com/deploy/...'}"

# 0) stop committing logs forever
touch .gitignore
grep -q "^global/logs/" .gitignore || echo "global/logs/" >> .gitignore

BRANCH="$(git branch --show-current)"
echo "Branch: $BRANCH"

echo "== Git: stage/commit/push =="
git add -A
if git diff --cached --quiet; then
  echo "No changes to commit (OK)."
else
  git commit -m "${1:-station: deploy via hook}"
fi
git push origin "$BRANCH"

echo "== Render: trigger deploy hook =="
curl -fsS -X POST "$RENDER_DEPLOY_HOOK" | cat
echo
echo "DONE. Check Render dashboard deploy logs."
