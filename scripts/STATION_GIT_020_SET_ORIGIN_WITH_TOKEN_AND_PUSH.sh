#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
cd "$ROOT"

echo "=== [GIT_020] Set origin (with token) + push ==="
echo

read -rp "GitHub OWNER (username or org): " OWNER
read -rp "GitHub REPO (repo name only): " REPO
read -rsp "GitHub TOKEN (classic PAT with repo scope): " TOKEN
echo

if [ -z "${OWNER:-}" ] || [ -z "${REPO:-}" ] || [ -z "${TOKEN:-}" ]; then
  echo "ERROR: OWNER/REPO/TOKEN required."
  exit 1
fi

URL="https://${TOKEN}@github.com/${OWNER}/${REPO}.git"

git remote remove origin 2>/dev/null || true
git remote add origin "$URL"

echo "Origin set to: https://***@github.com/${OWNER}/${REPO}.git"
echo

git push --set-upstream origin main

echo
echo "OK: pushed and upstream set."
