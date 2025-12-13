#!/data/data/com.termux/files/usr/bin/bash
set -e
PORT=8000
if lsof -tiTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1; then
  echo "[GUARD] Port $PORT already in use. Abort."
  exit 1
fi
exit 0
