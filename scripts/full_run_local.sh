#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_REPO_DIR:-$HOME/station_root}"
LOGS="$ROOT/.logs"
mkdir -p "$LOGS"

PORT="${PORT:-8000}"

cd "$ROOT"

# Backend venv (Termux-safe)
if [ ! -d "$ROOT/.venv" ]; then
  python -m venv "$ROOT/.venv"
fi
# shellcheck disable=SC1091
source "$ROOT/.venv/bin/activate"

pip install --upgrade pip >/dev/null 2>&1 || true
pip install -r "$ROOT/backend/requirements.txt"

# Start backend
pkill -f "uvicorn backend.asgi:app" >/dev/null 2>&1 || true
nohup uvicorn backend.asgi:app --host 127.0.0.1 --port "$PORT" > "$LOGS/backend.log" 2>&1 &

sleep 1
if curl -fsS "http://127.0.0.1:$PORT/healthz" >/dev/null 2>&1; then
  echo "OK: backend up -> http://127.0.0.1:$PORT"
  echo "Docs:           http://127.0.0.1:$PORT/docs"
else
  echo "FAIL: backend did not start. Tail logs:"
  tail -n 120 "$LOGS/backend.log" || true
  exit 1
fi
