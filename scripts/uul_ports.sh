#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
kill_port(){
  local p="$1"
  for pid in $(lsof -tiTCP:"$p" -sTCP:LISTEN 2>/dev/null); do
    kill -9 "$pid" >/dev/null 2>&1 || true
  done
}
case "${1:-}" in
  kill)
    kill_port "${2:-8000}"
    kill_port "${3:-5173}"
    ;;
  show|*)
    lsof -iTCP:8000 -sTCP:LISTEN 2>/dev/null || true
    lsof -iTCP:5173 -sTCP:LISTEN 2>/dev/null || true
    ;;
esac
