#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
cd "$ROOT"

command -v curl >/dev/null 2>&1 || pkg install -y curl

echo "=== [DWARF] FORCE PUSH main -> origin/main (overwrite remote) ==="
echo

read -rsp "GitHub TOKEN (classic PAT, repo scope): " TOKEN
echo
[ -z "${TOKEN:-}" ] && { echo "ERROR: TOKEN required"; exit 1; }

API="https://api.github.com"
LOGIN="$(curl -sS --http1.1 \
  -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github+json" \
  "$API/user" | python3 -c "import sys,json; print(json.load(sys.stdin).get('login',''))")"

[ -z "${LOGIN:-}" ] && { echo "ERROR: token invalid"; exit 1; }

REPO="dwarf"
echo "Token owner = $LOGIN"
echo "Target repo  = $LOGIN/$REPO"
echo

git status >/dev/null
git branch -M main

# Ensure origin is correct (no token stored)
git remote remove origin 2>/dev/null || true
git remote add origin "https://github.com/${LOGIN}/${REPO}.git"

# Push with ASKPASS (token not stored)
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

echo ">>> FORCE pushing (this overwrites remote main)..."
git push --force-with-lease --set-upstream origin main

rm -f "$ASKPASS" || true
unset GIT_ASKPASS GIT_TERMINAL_PROMPT GITHUB_TOKEN

echo
echo "DONE."
echo "Repo: https://github.com/${LOGIN}/${REPO}"
