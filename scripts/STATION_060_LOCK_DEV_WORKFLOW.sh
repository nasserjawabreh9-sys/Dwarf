#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
cd "$ROOT"

echo "============================================"
echo "STATION_060_LOCK_DEV_WORKFLOW"
date
echo "root: $ROOT"
echo "============================================"
echo

# 1) تأكيد git
if [ ! -d .git ]; then
  echo "ERROR: Not a git repository"
  exit 1
fi

# 2) إنشاء فرع dev (إن لم يكن موجود)
if git show-ref --verify --quiet refs/heads/dev; then
  echo "branch dev: already exists"
else
  git checkout -b dev
  echo "branch dev: created"
fi

# 3) إنشاء .gitignore قوي (إن لم يكن موجود)
if [ ! -f .gitignore ]; then
cat > .gitignore <<'EOF'
# Python
__pycache__/
*.pyc
*.pyo
*.pyd
.env
.venv/
venv/

# Node
node_modules/
dist/
build/

# Logs / Runtime
*.log
station_logs/
global/logs/
station_meta/logs/

# DB / State (keep schema, ignore runtime)
*.sqlite
*.sqlite3
*.db
state/*.db

# Backups / zips
_backup_*/
*.zip

# OS
.DS_Store
EOF
  echo ".gitignore: created"
else
  echo ".gitignore: exists (not overwritten)"
fi

# 4) تنظيف التتبع (بدون حذف محلي)
git rm -r --cached __pycache__ 2>/dev/null || true
git rm -r --cached backend/.venv 2>/dev/null || true
git rm -r --cached frontend/node_modules 2>/dev/null || true
git rm -r --cached station_logs 2>/dev/null || true
git rm -r --cached global/logs 2>/dev/null || true

# 5) Commit منظم
git add .gitignore || true
git add -u || true
git commit -m "chore: lock dev workflow, add gitignore, clean tracked noise" || true

# 6) تقرير نهائي
echo
echo "STATUS:"
git status -sb
echo
echo "NEXT:"
echo " - اعمل تطويرك اليومي على فرع dev"
echo " - لما يستقر: merge -> main ثم tag release"
echo "============================================"
echo "DONE: STATION_060_LOCK_DEV_WORKFLOW"
echo "============================================"
