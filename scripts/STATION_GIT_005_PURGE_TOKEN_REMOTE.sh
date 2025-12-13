#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
cd "$ROOT"

echo "=== [GIT_005] Purge token from origin ==="
if git remote get-url origin >/dev/null 2>&1; then
  OLD="$(git remote get-url origin)"
  echo "Old origin: $OLD" | sed 's#https://[^@]*@#https://***@#'
  git remote remove origin || true
  echo "Origin removed."
else
  echo "No origin to purge."
fi

echo "OK."
