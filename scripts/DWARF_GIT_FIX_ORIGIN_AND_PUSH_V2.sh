#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
cd "$ROOT"

command -v curl >/dev/null 2>&1 || { echo "Installing curl..."; pkg install -y curl; }
command -v git  >/dev/null 2>&1 || { echo "ERROR: git missing"; exit 1; }

echo "=== [DWARF_GIT_V2] Fix origin + ensure repo + push (Termux-safe) ==="
echo

read -rsp "GitHub TOKEN (classic PAT, repo scope): " TOKEN
echo
[ -z "${TOKEN:-}" ] && { echo "ERROR: TOKEN required"; exit 1; }

API="https://api.github.com"
HDR_AUTH="Authorization: token ${TOKEN}"
HDR_ACC="Accept: application/vnd.github+json"
HDR_UA="User-Agent: dwarf-termux"

TMP_ME="$(mktemp)"
TMP_REPO="$(mktemp)"
TMP_CREATE="$(mktemp)"

# 1) Detect token owner (write to file to avoid curl (23))
curl -sS --retry 3 --retry-delay 1 --http1.1 \
  -H "$HDR_AUTH" -H "$HDR_ACC" -H "$HDR_UA" \
  "$API/user" > "$TMP_ME" || true

LOGIN="$(python3 - <<PY
import json
p="$TMP_ME"
try:
  obj=json.load(open(p,'r'))
  print(obj.get("login",""))
except Exception:
  print("")
PY
)"

if [ -z "$LOGIN" ]; then
  echo "ERROR: token invalid or blocked. Raw response (first 60 lines):"
  sed -n '1,60p' "$TMP_ME" || true
  exit 1
fi

REPO="dwarf"
echo "Token owner = $LOGIN"
echo "Target repo  = $LOGIN/$REPO"
echo

# 2) Ensure git + main
git status >/dev/null
git branch -M main

# 3) Set origin WITHOUT token
git remote remove origin 2>/dev/null || true
git remote add origin "https://github.com/${LOGIN}/${REPO}.git"

# 4) Check repo exists
CODE="$(curl -sS --retry 3 --retry-delay 1 --http1.1 \
  -o "$TMP_REPO" -w "%{http_code}" \
  -H "$HDR_AUTH" -H "$HDR_ACC" -H "$HDR_UA" \
  "$API/repos/${LOGIN}/${REPO}" || true)"

if [ "$CODE" != "200" ]; then
  echo "Repo not found (HTTP $CODE) -> creating private repo '${REPO}' under $LOGIN"
  CREATE_CODE="$(curl -sS --retry 3 --retry-delay 1 --http1.1 \
    -o "$TMP_CREATE" -w "%{http_code}" \
    -X POST -H "$HDR_AUTH" -H "$HDR_ACC" -H "$HDR_UA" \
    "$API/user/repos" \
    -d "{\"name\":\"${REPO}\",\"private\":true,\"auto_init\":false}" || true)"

  if [ "$CREATE_CODE" != "201" ]; then
    echo "ERROR: create repo failed HTTP=$CREATE_CODE"
    echo "Response (first 120 lines):"
    sed -n '1,120p' "$TMP_CREATE" || true
    exit 1
  fi
  echo "OK: repo created."
else
  echo "OK: repo exists."
fi

# 5) Push using ASKPASS (token not stored)
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

rm -f "$ASKPASS" "$TMP_ME" "$TMP_REPO" "$TMP_CREATE" 2>/dev/null || true
unset GIT_ASKPASS GIT_TERMINAL_PROMPT GITHUB_TOKEN

echo
echo "DONE."
echo "Repo: https://github.com/${LOGIN}/${REPO}"
