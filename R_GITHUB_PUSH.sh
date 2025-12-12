#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
cd "$ROOT"

MSG="${1:-chore: push updates}"
TAG="${2:-}"

echo "=============================="
echo "GITHUB PUSH"
echo "MSG=$MSG"
echo "TAG=$TAG"
echo "=============================="

# تأكد أنك داخل repo
if [ ! -d ".git" ]; then
  echo "[ERR] Not a git repository"
  exit 1
fi

# حماية الملفات الحساسة
touch .gitignore
grep -q "station_meta/settings/runtime_keys.json" .gitignore || cat >> .gitignore <<'EOF'

# --- Station runtime sensitive ---
station_meta/settings/runtime_keys.json
station_meta/queue/*.pid
station_meta/queue/locks/
station_meta/logs/
backend.log
frontend.log
EOF

# إزالة التتبع إن وُجد
git rm --cached station_meta/settings/runtime_keys.json >/dev/null 2>&1 || true
git rm --cached station_meta/queue/dynamo_worker.pid >/dev/null 2>&1 || true

# Commit
git add -A
git commit -m "$MSG" || echo "[NOTE] Nothing to commit"

# Push
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
git push -u origin "$BRANCH"

# Tag اختياري
if [ -n "$TAG" ]; then
  TAG="r${TAG#r}"
  git tag -f "$TAG"
  git push -f origin "$TAG"
  echo "Tagged: $TAG"
fi

echo "DONE: GitHub push complete."
