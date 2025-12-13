#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
LOGS="$ROOT/station_logs"; mkdir -p "$LOGS"
cd "$ROOT/backend"
source .venv/bin/activate 2>/dev/null || true
bash "$ROOT/scripts/uul_kill_ports.sh" >/dev/null 2>&1 || true
nohup python -m uvicorn asgi:app --host 127.0.0.1 --port 8000 >"$LOGS/backend.log" 2>&1 &
sleep 1
curl -fsS http://127.0.0.1:8000/healthz >/dev/null 2>&1 && echo "OK: backend up" || { echo "Backend failed"; tail -n 140 "$LOGS/backend.log" || true; exit 1; }
echo "Backend: http://127.0.0.1:8000"
