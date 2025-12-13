#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
for p in 8000 5173; do
  for pid in $(lsof -tiTCP:"$p" -sTCP:LISTEN 2>/dev/null); do
    kill -9 "$pid" >/dev/null 2>&1 || true
  done
done
echo "Stopped ports 8000/5173 (if any)."
