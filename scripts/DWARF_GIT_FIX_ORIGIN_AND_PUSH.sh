#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
cd "$ROOT"

command -v git >/dev/null 2>&1 || { echo "ERROR: git not installed"; exit 1; }

echo "=== [DWARF_GIT] Fix origin + push (safe) ==="
echo

read -rsp "GitHub TOKEN (for the same account you want to push to): " TOKEN
echo
[ -z "${TOKEN:-}" ] && { echo "ERROR: TOKEN required"; exit 1; }

# Detect token owner (so we don't guess)
API="https://api.github.com"
LOGIN="$(curl -sS -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github+json" \
  "$API/user" | python3 -c "import sys,json; print(json.load(sys.stdin).get('login',''))")"

[ -z "${LOGIN:-}" ] && { echo "ERROR: token invalid"; exit 1; }

REPO="dwarf"
echo "Token owner = $LOGIN"
echo "Target repo  = $LOGIN/$REPO"
echo

# Ensure git + main
git status >/dev/null
git branch -M main

# Ensure origin is correct (no token stored)
git remote remove origin 2>/dev/null || true
git remote add origin "https://github.com/${LOGIN}/${REPO}.git"

# Create repo if missing (private)
CODE="$(curl -s -o /tmp/gh_repo.json -w "%{http_code}" \
  -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github+json" \
  "$API/repos/${LOGIN}/${REPO}")"

if [ "$CODE" != "200" ]; then
  echo "Repo not found on GitHub → creating ${LOGIN}/${REPO} (private)"
  CREATE_CODE="$(curl -s -o /tmp/gh_create.json -w "%{http_code}" \
    -X POST -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github+json" \
    "$API/user/repos" -d "{\"name\":\"${REPO}\",\"private\":true,\"auto_init\":false}")"
  if [ "$CREATE_CODE" != "201" ]; then
    echo "ERROR: create repo failed HTTP=$CREATE_CODE"
    cat /tmp/gh_create.json | head -n 120 || true
    exit 1
  fi
  echo "OK: repo created."
else
  echo "OK: repo exists."
fi

# Push using temporary askpass (token not stored in origin)
ASKPASS="$(mktemp)"
cat > "$ASKPASS" <<'AP'
#!/usr/bin/env sh
case "$1" in
  *Username*) echo "x-access-token" ;;
  *Password*) echo "$GITHUB_TOKEN" ;;
  *) echo "" ;;
esac
AP
chmod +x "$ASKPASS"
export GIT_ASKPASS="$ASKPASS"
export GIT_TERMINAL_PROMPT=0
export GITHUB_TOKEN="$TOKEN"

echo ">>> Pushing..."
git push --set-upstream origin main

rm -f "$ASKPASS" || true
unset GIT_ASKPASS GIT_TERMINAL_PROMPT GITHUB_TOKEN

echo
echo "DONE: pushed to https://github.com/${LOGIN}/${REPO}"
