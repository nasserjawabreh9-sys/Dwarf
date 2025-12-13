#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
cd "$ROOT"

command -v curl >/dev/null 2>&1 || { echo "Installing curl..."; pkg install -y curl; }
command -v jq   >/dev/null 2>&1 || { echo "Installing jq..."; pkg install -y jq; }

echo "=== [GH_FIX] Auto-detect user from token, create/attach repo, push ==="
echo

read -rp "Repo name (recommended: station_root): " REPO
REPO="${REPO:-station_root}"
read -rsp "GitHub TOKEN (classic PAT, repo scope): " TOKEN
echo

if [ -z "${TOKEN:-}" ]; then
  echo "ERROR: TOKEN required."
  exit 1
fi

API="https://api.github.com"
AUTH="Authorization: token ${TOKEN}"
ACC="Accept: application/vnd.github+json"
UA="User-Agent: station-termux"

echo ">>> Detecting token owner (login)..."
ME_JSON="$(curl -sS -H "$AUTH" -H "$ACC" -H "$UA" "${API}/user")"
LOGIN="$(echo "$ME_JSON" | jq -r '.login // empty')"

if [ -z "${LOGIN:-}" ] || [ "$LOGIN" = "null" ]; then
  echo "ERROR: Token invalid or missing permissions."
  echo "Response:"
  echo "$ME_JSON" | head -n 40
  exit 1
fi

echo "OK: token owner login = $LOGIN"
echo "Target repo = $LOGIN/$REPO"
echo

# Purge any origin (avoid token stored)
git remote remove origin 2>/dev/null || true

# Ensure main
git branch -M main 2>/dev/null || true

# Ensure render scripts exist (safe placeholders only)
mkdir -p backend/ops
[ -f ".python-version" ] || echo "3.12.8" > .python-version

cat > backend/ops/run_render.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
: "${PORT:=8000}"
: "${STATION_ENV:=prod}"
cd "$(dirname "$0")/.."
echo ">>> [RUN_RENDER] STATION_ENV=$STATION_ENV PORT=$PORT"
python3 ops/preflight.py || true
exec python3 -m uvicorn app.main:app --host 0.0.0.0 --port "$PORT"
SH
chmod +x backend/ops/run_render.sh

# Add preflight if missing
if [ ! -f backend/ops/preflight.py ]; then
cat > backend/ops/preflight.py <<'PY'
import os, sys
SOFT_REQUIRED=["STATION_EDIT_KEY"]
OPTIONAL_KEYS=["STATION_OPENAI_API_KEY","OPENAI_API_KEY","GITHUB_TOKEN","RENDER_API_KEY","TTS_KEY","OCR_KEY","WEBHOOKS_URL","WHATSAPP_KEY","EMAIL_SMTP","GITHUB_REPO"]
def main():
  print(">>> [PREFLIGHT] Station Render Preflight")
  print("python =", sys.version.split()[0])
  missing=[k for k in SOFT_REQUIRED if not os.getenv(k)]
  if missing: print("!!! missing soft-required env:", ", ".join(missing))
  empty=[k for k in OPTIONAL_KEYS if not os.getenv(k)]
  if empty:
    print(".. optional keys empty (expected until set from UI):")
    for k in empty: print(" -", k)
  return 0
if __name__=="__main__": raise SystemExit(main())
PY
fi

# Commit if needed
git add .python-version backend/ops/run_render.sh backend/ops/preflight.py 2>/dev/null || true
git commit -m "render: pin python + preflight + run_render" 2>/dev/null || true

echo ">>> Checking if repo exists..."
CODE="$(curl -sS -o /tmp/gh_repo.json -w "%{http_code}" -H "$AUTH" -H "$ACC" -H "$UA" "${API}/repos/${LOGIN}/${REPO}" || true)"

if [ "$CODE" = "200" ]; then
  echo "OK: repo exists."
else
  echo "Repo not found (HTTP $CODE). Creating repo under token owner ($LOGIN)..."
  CREATE_CODE="$(curl -sS -o /tmp/gh_create.json -w "%{http_code}" -X POST -H "$AUTH" -H "$ACC" -H "$UA" "${API}/user/repos" -d "{\"name\":\"${REPO}\",\"private\":true,\"auto_init\":false}" || true)"
  if [ "$CREATE_CODE" != "201" ]; then
    echo "ERROR: create repo failed. HTTP=$CREATE_CODE"
    echo "Response:"
    cat /tmp/gh_create.json | head -n 80
    exit 1
  fi
  echo "OK: repo created."
fi

# Set origin WITHOUT token
git remote add origin "https://github.com/${LOGIN}/${REPO}.git"

# Push using temporary askpass (token not stored)
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
echo "DONE."
echo "Repo: https://github.com/${LOGIN}/${REPO}"
echo
echo "Render settings:"
echo "  Root Directory: backend"
echo "  Build Command : pip install -r requirements.txt"
echo "  Start Command : bash ops/run_render.sh"
echo
echo "Env placeholders (set later from UI):"
cat <<EOF
STATION_ENV=prod
STATION_EDIT_KEY=1234
STATION_OPENAI_API_KEY=
OPENAI_API_KEY=
GITHUB_TOKEN=
RENDER_API_KEY=
TTS_KEY=
OCR_KEY=
WEBHOOKS_URL=
WHATSAPP_KEY=
EMAIL_SMTP=
GITHUB_REPO=${LOGIN}/${REPO}
EOF
