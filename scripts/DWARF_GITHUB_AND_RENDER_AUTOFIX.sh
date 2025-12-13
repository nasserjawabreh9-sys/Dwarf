#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
cd "$ROOT"

# deps
command -v curl >/dev/null || pkg install -y curl
command -v jq   >/dev/null || pkg install -y jq

echo "=== [DWARF] GitHub + Render AutoFix ==="
echo

read -rsp "GitHub TOKEN (classic PAT, repo scope): " TOKEN
echo
[ -z "$TOKEN" ] && { echo "ERROR: TOKEN required"; exit 1; }

API="https://api.github.com"
AUTH="Authorization: token $TOKEN"
ACC="Accept: application/vnd.github+json"
UA="User-Agent: dwarf-termux"

# detect user from token
ME="$(curl -sS -H "$AUTH" -H "$ACC" -H "$UA" "$API/user")"
USER="$(echo "$ME" | jq -r '.login // empty')"

[ -z "$USER" ] && { echo "ERROR: invalid token"; exit 1; }

REPO="dwarf"

echo "GitHub User : $USER"
echo "Repo        : $USER/$REPO"
echo

# ensure git
git status >/dev/null
git branch -M main

# prepare backend render runner
mkdir -p backend/ops

cat > backend/ops/preflight.py <<'PY'
import os,sys
print(">>> PREFLIGHT")
print("python =", sys.version.split()[0])
soft=["STATION_EDIT_KEY"]
opt=["OPENAI_API_KEY","STATION_OPENAI_API_KEY","GITHUB_TOKEN","RENDER_API_KEY"]
miss=[k for k in soft if not os.getenv(k)]
if miss: print("missing soft:", miss)
else: print("soft ok")
print("optional empty allowed")
PY

cat > backend/ops/run_render.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
: "${PORT:=8000}"
: "${STATION_ENV:=prod}"
cd "$(dirname "$0")/.."
python3 ops/preflight.py || true
exec python3 -m uvicorn app.main:app --host 0.0.0.0 --port "$PORT"
SH
chmod +x backend/ops/run_render.sh

echo "3.12.8" > .python-version

git add .python-version backend/ops/preflight.py backend/ops/run_render.sh
git commit -m "dwarf: render bootstrap (no secrets)" 2>/dev/null || true

# check repo
CODE="$(curl -s -o /tmp/repo.json -w "%{http_code}" -H "$AUTH" -H "$ACC" "$API/repos/$USER/$REPO")"
if [ "$CODE" != "200" ]; then
  echo "Repo not found → creating private repo '$REPO'"
  curl -s -H "$AUTH" -H "$ACC" -X POST "$API/user/repos" \
    -d "{\"name\":\"$REPO\",\"private\":true}" >/dev/null
fi

git remote remove origin 2>/dev/null || true
git remote add origin "https://github.com/$USER/$REPO.git"

# push without storing token
ASKPASS="$(mktemp)"
cat > "$ASKPASS" <<EOF
#!/bin/sh
echo "$TOKEN"
EOF
chmod +x "$ASKPASS"
export GIT_ASKPASS="$ASKPASS"
export GIT_TERMINAL_PROMPT=0

git push --set-upstream origin main

rm -f "$ASKPASS"
unset GIT_ASKPASS GIT_TERMINAL_PROMPT

echo
echo "DONE."
echo "GitHub Repo: https://github.com/$USER/$REPO"
echo
echo "=== Render Settings ==="
echo "Root Dir    : backend"
echo "Build Cmd   : pip install -r requirements.txt"
echo "Start Cmd   : bash ops/run_render.sh"
echo
echo "Env (set later from UI):"
echo "STATION_ENV=prod"
echo "STATION_EDIT_KEY=1234"
echo "OPENAI_API_KEY="
echo "STATION_OPENAI_API_KEY="
