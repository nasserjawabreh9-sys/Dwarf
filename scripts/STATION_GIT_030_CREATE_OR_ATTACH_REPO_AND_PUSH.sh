#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
cd "$ROOT"

# deps
command -v curl >/dev/null 2>&1 || { echo "Installing curl..."; pkg install -y curl; }
command -v jq   >/dev/null 2>&1 || { echo "Installing jq..."; pkg install -y jq; }

echo "=== [GIT_030] Create (if missing) or attach repo, then push ==="
echo

read -rp "GitHub username (exact, case-sensitive): " USER
read -rp "Repo name to use (recommended: station_root): " REPO
read -rsp "GitHub TOKEN (classic PAT, repo scope): " TOKEN
echo

if [ -z "${USER:-}" ] || [ -z "${REPO:-}" ] || [ -z "${TOKEN:-}" ]; then
  echo "ERROR: USER/REPO/TOKEN required."
  exit 1
fi

API="https://api.github.com"
AUTH_HEADER="Authorization: token ${TOKEN}"
ACCEPT_HEADER="Accept: application/vnd.github+json"
UA_HEADER="User-Agent: station-termux"

echo ">>> Checking if repo exists: ${USER}/${REPO}"
HTTP_CODE=$(curl -sS -o /tmp/gh_repo.json -w "%{http_code}" \
  -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -H "$UA_HEADER" \
  "${API}/repos/${USER}/${REPO}" || true)

if [ "$HTTP_CODE" = "200" ]; then
  echo "OK: repo exists."
else
  echo "Repo not found (HTTP $HTTP_CODE). Creating repo..."
  # Create under the authenticated user
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

# Set origin WITHOUT token (we will use credential helper or prompt)
git remote remove origin 2>/dev/null || true
git remote add origin "https://github.com/${USER}/${REPO}.git"

echo "Origin set to: https://github.com/${USER}/${REPO}.git"
echo

# Ensure main + upstream
git branch -M main

echo ">>> Pushing (Git may prompt for credentials)."
echo "If prompted: username=${USER} password=YOUR_TOKEN"
git push --set-upstream origin main

echo
echo "DONE: repo attached and pushed."
