#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
USER="nasserjawabreh9"
REPO_DEFAULT="station_root"

# deps
command -v curl >/dev/null 2>&1 || { echo "Installing curl..."; pkg install -y curl; }
command -v jq   >/dev/null 2>&1 || { echo "Installing jq..."; pkg install -y jq; }

echo "=== [ALL_IN_ONE] GitHub + Render prep ==="
echo "ROOT=$ROOT"
echo "USER=$USER"
echo

if [ ! -d "$ROOT" ]; then
  echo "ERROR: station_root not found at: $ROOT"
  exit 1
fi

cd "$ROOT"

# 0) Ensure git repo
if [ ! -d ".git" ]; then
  echo "No .git found -> initializing git repo"
  git init
  git branch -M main
fi

# 1) Choose repo name (default station_root)
read -rp "GitHub repo name (Enter for '${REPO_DEFAULT}'): " REPO
REPO="${REPO:-$REPO_DEFAULT}"

# 2) Token (not saved)
read -rsp "GitHub TOKEN (classic PAT, repo scope): " TOKEN
echo
if [ -z "${TOKEN:-}" ]; then
  echo "ERROR: TOKEN required."
  exit 1
fi

API="https://api.github.com"
AUTH_HEADER="Authorization: token ${TOKEN}"
ACCEPT_HEADER="Accept: application/vnd.github+json"
UA_HEADER="User-Agent: station-termux"

# 3) Purge any origin that contains token
if git remote get-url origin >/dev/null 2>&1; then
  OLD="$(git remote get-url origin)"
  echo "Purging existing origin (if any):" | sed 's#https://[^@]*@#https://***@#'
  git remote remove origin || true
fi

# 4) Ensure patch files exist (optional safety; does NOT add real keys)
mkdir -p backend/ops
if [ ! -f ".python-version" ]; then
  echo "3.12.8" > .python-version
fi

if [ ! -f "backend/.env.example" ]; then
  cat > backend/.env.example <<'TXT'
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
GITHUB_REPO=USER/REPO
TXT
fi

if [ ! -f "backend/ops/preflight.py" ]; then
  cat > backend/ops/preflight.py <<'PY'
import os, sys
SOFT_REQUIRED = ["STATION_EDIT_KEY"]
OPTIONAL_KEYS = [
  "STATION_OPENAI_API_KEY","OPENAI_API_KEY","GITHUB_TOKEN","RENDER_API_KEY",
  "TTS_KEY","OCR_KEY","WEBHOOKS_URL","WHATSAPP_KEY","EMAIL_SMTP","GITHUB_REPO",
]
def main():
  print(">>> [PREFLIGHT] Station Render Preflight")
  print("python =", sys.version.split()[0])
  missing_soft = [k for k in SOFT_REQUIRED if not os.getenv(k)]
  if missing_soft:
    print("!!! missing soft-required env:", ", ".join(missing_soft))
  empty_optional = [k for k in OPTIONAL_KEYS if not os.getenv(k)]
  if empty_optional:
    print(".. optional keys empty (expected until set from UI):")
    for k in empty_optional: print(" -", k)
  print(">>> [PREFLIGHT] Done.")
  return 0
if __name__ == "__main__":
  raise SystemExit(main())
PY
fi

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

# 5) Stage + commit whatever is currently present (idempotent)
git add .python-version backend/.env.example backend/ops/preflight.py backend/ops/run_render.sh scripts/*.sh 2>/dev/null || true
git add . 2>/dev/null || true
git commit -m "station: render-safe start + preflight + pinned python" || true

# 6) Check repo existence
echo ">>> Checking repo: ${USER}/${REPO}"
HTTP_CODE=$(curl -sS -o /tmp/gh_repo.json -w "%{http_code}" \
  -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -H "$UA_HEADER" \
  "${API}/repos/${USER}/${REPO}" || true)

if [ "$HTTP_CODE" = "200" ]; then
  echo "OK: repo exists."
else
  echo "Repo not found (HTTP $HTTP_CODE). Creating repo under ${USER}..."
  CREATE_CODE=$(curl -sS -o /tmp/gh_create.json -w "%{http_code}" \
    -X POST -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -H "$UA_HEADER" \
    "${API}/user/repos" \
    -d "{\"name\":\"${REPO}\",\"private\":true,\"auto_init\":false}" || true)

  if [ "$CREATE_CODE" != "201" ]; then
    echo "ERROR: failed to create repo. HTTP=$CREATE_CODE"
    echo "Response:"
    cat /tmp/gh_create.json || true
    exit 1
  fi
  echo "OK: repo created."
fi

# 7) Set origin without token saved
git remote add origin "https://github.com/${USER}/${REPO}.git"
git branch -M main

# 8) Push using temporary askpass (token not stored in origin)
ASKPASS="$(mktemp)"
cat > "$ASKPASS" <<'AP'
#!/usr/bin/env sh
# Git asks for username/password; we return token as password
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

echo ">>> Pushing to origin (upstream main)..."
git push --set-upstream origin main

rm -f "$ASKPASS" || true
unset GIT_ASKPASS GIT_TERMINAL_PROMPT GITHUB_TOKEN

echo
echo "=== DONE: GitHub ready ==="
echo "Repo: https://github.com/${USER}/${REPO}"
echo
echo "=== RENDER SETTINGS (copy/paste) ==="
echo "Web Service:"
echo "  Root Directory: backend"
echo "  Build Command : pip install -r requirements.txt"
echo "  Start Command : bash ops/run_render.sh"
echo
echo "Environment Variables (placeholders; set later from UI):"
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
GITHUB_REPO=${USER}/${REPO}
EOF

echo
echo "Next: go to Render, connect repo ${USER}/${REPO}, deploy."
