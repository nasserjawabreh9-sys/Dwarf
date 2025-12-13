#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
source "$ROOT/station_env.sh" 2>/dev/null || true

LOGS="$ROOT/station_logs"; mkdir -p "$LOGS"
BACKEND="$ROOT/backend"
FRONTEND="$ROOT/frontend"

HOST="${STATION_BACKEND_HOST:-127.0.0.1}"
BPORT="${STATION_BACKEND_PORT:-8000}"
FHOST="${STATION_FRONTEND_HOST:-127.0.0.1}"
FPORT="${STATION_FRONTEND_PORT:-5173}"

kill_port(){
  local p="$1"
  for pid in $(lsof -tiTCP:"$p" -sTCP:LISTEN 2>/dev/null); do
    kill -9 "$pid" >/dev/null 2>&1 || true
  done
}

health_wait(){
  for _ in $(seq 1 80); do
    if curl -fsS "http://$HOST:$BPORT/healthz" >/dev/null 2>&1; then return 0; fi
    sleep 0.5
  done
  return 1
}

# Ensure minimal backend entry exists
mkdir -p "$BACKEND/backend"
if [[ ! -f "$BACKEND/backend/app.py" ]]; then
  cat > "$BACKEND/backend/app.py" <<'PY'
from fastapi import FastAPI
app = FastAPI()
@app.get("/healthz")
def healthz(): return {"ok": True}
PY
fi

# Ensure minimal frontend exists
mkdir -p "$FRONTEND/src"
if [[ ! -f "$FRONTEND/index.html" ]]; then
  cat > "$FRONTEND/index.html" <<'HTML'
<!doctype html><html><head><meta charset="UTF-8"/><meta name="viewport" content="width=device-width,initial-scale=1.0"/><title>Station</title></head><body><div id="root"></div><script type="module" src="/src/main.tsx"></script></body></html>
HTML
fi
if [[ ! -f "$FRONTEND/src/main.tsx" ]]; then
  cat > "$FRONTEND/src/main.tsx" <<'TSX'
import { createRoot } from "react-dom/client";
createRoot(document.getElementById("root")!).render(<div style={{fontFamily:"system-ui"}}>Station OK</div>);
TSX
fi

bash "$ROOT/scripts/uul_build.sh"

kill_port "$BPORT"
kill_port "$FPORT"

echo "=== RUN BACKEND ==="
cd "$BACKEND"
source .venv/bin/activate
nohup python -m uvicorn backend.app:app --host "$HOST" --port "$BPORT"  >"$LOGS/backend.log" 2>&1 &

sleep 1
health_wait || { echo "Backend unhealthy"; tail -n 120 "$LOGS/backend.log"; exit 1; }

echo "=== RUN FRONTEND ==="
cd "$FRONTEND"
nohup npm run dev -- --host "$FHOST" --port "$FPORT" >"$LOGS/frontend.log" 2>&1 &

sleep 1
echo "UI: http://$FHOST:$FPORT/"
