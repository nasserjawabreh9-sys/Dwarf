#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
kill_port(){ local p="$1"; for pid in $(lsof -tiTCP:"$p" -sTCP:LISTEN 2>/dev/null); do kill -9 "$pid" >/dev/null 2>&1 || true; done; }
kill_port 8000
kill_port 5173
echo "OK: killed listeners on 8000/5173 (if any)."
