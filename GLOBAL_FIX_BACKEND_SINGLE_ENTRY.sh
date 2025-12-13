#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT="$HOME/station_root"
BACK="$ROOT/backend"
LOGS="$ROOT/station_logs"
SCRIPTS="$ROOT/scripts"

mkdir -p "$LOGS" "$SCRIPTS"

echo "=== [FIX] Stopworld: free ports + kill uvicorn/python ==="
pkg install -y procps lsof >/dev/null 2>&1 || true

kill_port(){
  local p="$1"
  for pid in $(lsof -tiTCP:"$p" -sTCP:LISTEN 2>/dev/null); do
    kill -9 "$pid" >/dev/null 2>&1 || true
  done
}

# kill by port + by pattern (covers reloader children)
kill_port 8000
kill_port 5173
pkill -9 -f "uvicorn.*8000" >/dev/null 2>&1 || true
pkill -9 -f "python.*uvicorn.*8000" >/dev/null 2>&1 || true
pkill -9 -f "uvicorn" >/dev/null 2>&1 || true

sleep 0.3
echo "Ports now:"
lsof -iTCP:8000 -sTCP:LISTEN 2>/dev/null || true
lsof -iTCP:5173 -sTCP:LISTEN 2>/dev/null || true
echo ""

echo "=== [FIX] Termux-safe requirements (no pydantic-core build) ==="
cat > "$BACK/requirements.txt" <<'REQ'
fastapi==0.99.1
uvicorn==0.23.2
pydantic<2
python-multipart==0.0.6
requests==2.32.3
REQ

echo "=== [FIX] Create SINGLE ASGI entry: backend/asgi.py (guaranteed /healthz) ==="
cat > "$BACK/asgi.py" <<'PY'
from fastapi import FastAPI

app = FastAPI()

@app.get("/healthz")
def healthz():
    return {"ok": True, "entry": "asgi.py"}
PY

echo "=== [FIX] Rebuild venv clean ==="
cd "$BACK"
rm -rf .venv
python -m venv .venv
source .venv/bin/activate
python -m pip install -U pip >/dev/null 2>&1 || true
python -m pip install -r requirements.txt >"$LOGS/pip_install.log" 2>&1

echo "=== [FIX] Patch scripts to run: uvicorn asgi:app (NO reload) ==="
# patch uul_run.sh if exists
if [[ -f "$SCRIPTS/uul_run.sh" ]]; then
  cp -f "$SCRIPTS/uul_run.sh" "$SCRIPTS/uul_run.bak_$(date +%Y%m%d_%H%M%S).sh" || true
  # remove any --reload
  sed -i 's/--reload//g' "$SCRIPTS/uul_run.sh" || true
  # replace backend target "backend.app:app" -> "asgi:app"
  sed -i 's/backend\.app:app/asgi:app/g' "$SCRIPTS/uul_run.sh" || true
fi

# patch station_ops.sh status health check (no perl)
if [[ -f "$SCRIPTS/station_ops.sh" ]]; then
  cp -f "$SCRIPTS/station_ops.sh" "$SCRIPTS/station_ops.bak_$(date +%Y%m%d_%H%M%S).sh" || true
fi

echo "=== [RUN] Start backend clean on 8000 ==="
kill_port 8000
nohup python -m uvicorn asgi:app --host 127.0.0.1 --port 8000 >"$LOGS/backend.log" 2>&1 &

# verify health
for _ in $(seq 1 60); do
  if curl -fsS http://127.0.0.1:8000/healthz >/dev/null 2>&1; then
    echo "OK: http://127.0.0.1:8000/healthz"
    echo ""
    echo "Next:"
    echo "  bash ~/station_root/scripts/station_ops.sh status"
    echo "  bash ~/station_root/scripts/station_ops.sh restart"
    exit 0
  fi
  sleep 0.25
done

echo "Backend still unhealthy. Tail backend.log:"
tail -n 200 "$LOGS/backend.log" || true
exit 1
