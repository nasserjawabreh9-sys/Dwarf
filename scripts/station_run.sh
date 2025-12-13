#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
source "$ROOT/station_env.sh" || true

BACKEND_HOST="${STATION_BACKEND_HOST:-127.0.0.1}"
BACKEND_PORT="${STATION_BACKEND_PORT:-8000}"
FRONTEND_PORT="${STATION_FRONTEND_PORT:-5173}"

LOGS="$ROOT/station_logs"
mkdir -p "$LOGS"

kill_port(){
  local p="$1"
  if command -v lsof >/dev/null 2>&1; then
    for pid in $(lsof -tiTCP:"$p" -sTCP:LISTEN 2>/dev/null); do
      kill -9 "$pid" >/dev/null 2>&1 || true
    done
  fi
}

health_wait(){
  local url1="http://$BACKEND_HOST:$BACKEND_PORT/healthz"
  local url2="http://$BACKEND_HOST:$BACKEND_PORT/health"
  for i in $(seq 1 80); do
    if curl -fsS "$url1" >/dev/null 2>&1 || curl -fsS "$url2" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.5
  done
  return 1
}

kill_port "$BACKEND_PORT"
kill_port "$FRONTEND_PORT"

cd "$ROOT/backend"
if [[ -f ".venv/bin/activate" ]]; then source ".venv/bin/activate"; fi
nohup python -m uvicorn backend.app:app --host "$BACKEND_HOST" --port "$BACKEND_PORT" --reload >"$LOGS/backend.log" 2>&1 &
sleep 0.4
health_wait || { tail -n 120 "$LOGS/backend.log"; exit 1; }

cd "$ROOT/frontend"
export VITE_BACKEND_URL="http://$BACKEND_HOST:$BACKEND_PORT"
nohup npm run dev -- --host 127.0.0.1 --port "$FRONTEND_PORT" >"$LOGS/frontend.log" 2>&1 &
sleep 1

if command -v termux-open-url >/dev/null 2>&1; then
  termux-open-url "http://127.0.0.1:$FRONTEND_PORT/" >/dev/null 2>&1 || true
fi

echo "RUNNING"
echo "UI: http://127.0.0.1:$FRONTEND_PORT/"
echo "Logs: $LOGS"
