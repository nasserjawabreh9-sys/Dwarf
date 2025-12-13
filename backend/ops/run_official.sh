#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
BACK="$ROOT/backend"
cd "$BACK"

if [ -x "$BACK/.venv/bin/python" ]; then
  PY="$BACK/.venv/bin/python"
else
  PY="$(command -v python3 || command -v python)"
fi

: "${PORT:=8080}"

pkill -f "uvicorn asgi:app" 2>/dev/null || true
pkill -f "uvicorn app.main:app" 2>/dev/null || true
sleep 1

echo ">>> [OFFICIAL] PY=$PY PORT=$PORT"
exec "$PY" -m uvicorn app.main:app --host 0.0.0.0 --port "$PORT"
