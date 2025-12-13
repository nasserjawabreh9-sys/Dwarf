#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
cd "$ROOT"

echo "=================================================="
echo "STATION_040_GITHUB_AUDIT_REAL"
echo "root: $ROOT"
date
echo "=================================================="

# 0) sanity: must be a git repo
if [ ! -d .git ]; then
  echo "ERROR: Not a git repo here. Missing .git in: $ROOT"
  exit 1
fi

echo
echo ">>> 1) Git identity (where am I?)"
git rev-parse --show-toplevel
echo "branch:  $(git branch --show-current || true)"
echo "HEAD:    $(git rev-parse --short HEAD)"
echo "remote:"
git remote -v || true

echo
echo ">>> 2) Working tree (must be clean for 'real push')"
git status -sb || true
if ! git diff --quiet; then
  echo
  echo "WARN: Uncommitted changes exist (diff):"
  git diff --stat | sed -n '1,120p'
fi
if ! git diff --cached --quiet; then
  echo
  echo "WARN: Staged (but not committed) changes exist:"
  git diff --cached --stat | sed -n '1,120p'
fi

echo
echo ">>> 3) Fetch origin + compare local vs GitHub"
# If origin unreachable, this will error; we catch and continue with a clear message.
if git fetch --all --prune >/dev/null 2>&1; then
  echo "OK: fetch origin"
else
  echo "WARN: git fetch failed (network/auth). Still printing local info."
fi

BR="$(git branch --show-current || echo main)"
UP="origin/$BR"

echo "upstream assumed: $UP"
if git show-ref --verify --quiet "refs/remotes/$UP"; then
  LOCAL="$(git rev-parse HEAD)"
  REMOTE="$(git rev-parse "$UP")"
  echo "local : $LOCAL"
  echo "remote: $REMOTE"
  if [ "$LOCAL" = "$REMOTE" ]; then
    echo "OK: Local HEAD == Remote HEAD (pushed for this branch)."
  else
    echo "NOT OK: Local and Remote differ."
    echo
    echo "Commits ONLY on LOCAL (not on GitHub):"
    git log --oneline --decorate "$UP"..HEAD | sed -n '1,40p' || true
    echo
    echo "Commits ONLY on REMOTE (not in your local):"
    git log --oneline --decorate HEAD.."$UP" | sed -n '1,40p' || true
  fi
else
  echo "WARN: Remote branch $UP not found locally. Printing ls-remote:"
  git ls-remote --heads origin 2>/dev/null | sed -n '1,20p' || true
fi

echo
echo ">>> 4) Last commits (evidence)"
git log --oneline --decorate -n 12 || true

echo
echo ">>> 5) What EXACTLY was in the last commit (files changed)"
git show --name-status --oneline -1 | sed -n '1,160p' || true

echo
echo ">>> 6) Real file inventory (top-level and key paths)"
echo "--- top-level:"
ls -la | sed -n '1,120p'

echo
echo "--- backend/app (should exist):"
if [ -d backend/app ]; then
  find backend/app -maxdepth 3 -type f | sed -n '1,120p'
else
  echo "MISSING: backend/app"
fi

echo
echo "--- frontend (should exist):"
if [ -d frontend ]; then
  ls -la frontend | sed -n '1,80p'
else
  echo "MISSING: frontend"
fi

echo
echo ">>> 7) Smoke tests (prove it's not a shell)"
# Backend import test
if [ -d backend ]; then
  ( cd backend && python -c "import app.main; print('OK: import app.main')" ) || \
    echo "FAIL: cannot import backend app.main"
fi

# Frontend minimal check
if [ -d frontend ]; then
  if [ -f frontend/package.json ]; then
    echo "OK: frontend/package.json present"
  else
    echo "FAIL: frontend/package.json missing"
  fi
  if [ -d frontend/src ]; then
    echo "OK: frontend/src present"
  else
    echo "WARN: frontend/src missing (maybe already built only?)"
  fi
fi

echo
echo ">>> 8) Optional: verify origin contains your HEAD hash (strong proof)"
# This verifies your current HEAD exists in origin by asking git to find it in remote history.
if git show-ref --verify --quiet "refs/remotes/$UP"; then
  H="$(git rev-parse HEAD)"
  if git branch -r --contains "$H" 2>/dev/null | grep -q "$UP"; then
    echo "OK: Remote $UP contains your HEAD ($H)."
  else
    echo "NOT OK: Remote $UP does NOT contain your HEAD ($H)."
  fi
fi

echo
echo "=================================================="
echo "DONE: STATION_040_GITHUB_AUDIT_REAL"
echo "If you want, paste the output here and I will tell you EXACTLY what is missing."
echo "=================================================="
