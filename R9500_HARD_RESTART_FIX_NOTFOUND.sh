#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
cd "$ROOT"

echo ">>> [R9500] HARD restart: free ports 8000/5173 and relaunch Station"

# --- 1) Kill uvicorn / node that might be holding ports
echo ">>> [R9500] Killing old backend/frontend (best-effort)..."
pkill -f "uvicorn.*8000" >/dev/null 2>&1 || true
pkill -f "node.*5173"   >/dev/null 2>&1 || true
pkill -f "vite.*5173"   >/dev/null 2>&1 || true

# Extra: kill anything mentioning station backend/front if your command differs
pkill -f "station.*backend" >/dev/null 2>&1 || true
pkill -f "station.*frontend" >/dev/null 2>&1 || true

sleep 1

# --- 2) Show who is still listening (if any)
echo ">>> [R9500] Checking listeners (ss):"
ss -ltnp 2>/dev/null | grep -E ':(8000|5173)\b' || echo "OK: no listeners on 8000/5173 (or ss can't show pids)"

# --- 3) Relaunch Station
echo ">>> [R9500] Launching station_full_run.sh ..."
./station_full_run.sh >/dev/null 2>&1 || true

sleep 1

# --- 4) Verify /health and the new routes
echo
echo ">>> [R9500] VERIFY /health"
curl -sS http://127.0.0.1:8000/health && echo

echo
echo ">>> [R9500] VERIFY /api/senses/text"
curl -sS -X POST http://127.0.0.1:8000/api/senses/text \
  -H "Content-Type: application/json" \
  -d '{"text":"hello"}' && echo

echo
echo ">>> [R9500] VERIFY /api/config/uui"
curl -sS http://127.0.0.1:8000/api/config/uui | head -c 400 && echo

echo
echo ">>> [R9500] DONE."
echo "If still Not Found, you are still hitting an old server or your running ASGI entry is not the file you patched."
echo "Next debug: inspect backend start command and backend/app/main.py structure."
