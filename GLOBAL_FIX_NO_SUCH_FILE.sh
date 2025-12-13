#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT="$HOME/station_root"
BACKEND="$ROOT/backend"
FRONTEND="$ROOT/frontend"
LOGS="$ROOT/station_logs"
mkdir -p "$LOGS"

echo "=== GLOBAL FIX: NO SUCH FILE ==="

# 1) Ensure system libs
pkg update -y >/dev/null 2>&1 || true
pkg install -y python nodejs npm curl lsof openssl ca-certificates >/dev/null 2>&1 || true

# 2) Ensure tree
mkdir -p "$BACKEND/backend" "$BACKEND/app" "$FRONTEND/src" "$ROOT/scripts"

# 3) Ensure backend entrypoint
if [ ! -f "$BACKEND/backend/app.py" ]; then
  echo "Fix: creating backend/backend/app.py"
  cat > "$BACKEND/backend/app.py" <<'EOF'
from fastapi import FastAPI

app = FastAPI()

@app.get("/healthz")
def healthz():
    return {"ok": True}
EOF
fi

# 4) Ensure requirements
if [ ! -f "$BACKEND/requirements.txt" ]; then
  echo "Fix: creating requirements.txt"
  cat > "$BACKEND/requirements.txt" <<'EOF'
fastapi
uvicorn
EOF
fi

# 5) Rebuild venv (hard)
cd "$BACKEND"
rm -rf .venv
python -m venv .venv
source .venv/bin/activate
python -m pip install -U pip >/dev/null
python -m pip install -r requirements.txt >"$LOGS/pip_install.log" 2>&1

# 6) Ensure frontend entry
if [ ! -f "$FRONTEND/src/main.tsx" ]; then
  echo "Fix: creating frontend/src/main.tsx"
  cat > "$FRONTEND/src/main.tsx" <<'EOF'
import { createRoot } from "react-dom/client";
createRoot(document.getElementById("root")!).render(<div>Station OK</div>);
EOF
fi

# 7) Ensure package.json
if [ ! -f "$FRONTEND/package.json" ]; then
  echo "Fix: creating frontend/package.json"
  cat > "$FRONTEND/package.json" <<'EOF'
{
  "name": "station",
  "private": true,
  "version": "0.0.1",
  "scripts": { "dev": "vite" },
  "dependencies": { "react": "^18.3.1", "react-dom": "^18.3.1" },
  "devDependencies": { "vite": "^5.4.11", "typescript": "^5.6.3" }
}
EOF
fi

# 8) Reinstall frontend deps
cd "$FRONTEND"
rm -rf node_modules package-lock.json
npm install >"$LOGS/npm_install.log" 2>&1

# 9) Kill ports
lsof -tiTCP:8000 -sTCP:LISTEN 2>/dev/null | xargs -r kill -9
lsof -tiTCP:5173 -sTCP:LISTEN 2>/dev/null | xargs -r kill -9

# 10) Run backend
cd "$BACKEND"
source .venv/bin/activate
nohup python -m uvicorn backend.app:app --host 127.0.0.1 --port 8000 >"$LOGS/backend.log" 2>&1 &

sleep 1
curl -fs http://127.0.0.1:8000/healthz >/dev/null || {
  echo "Backend failed"
  tail -n 50 "$LOGS/backend.log"
  exit 1
}

# 11) Run frontend
cd "$FRONTEND"
nohup npm run dev -- --host 127.0.0.1 --port 5173 >"$LOGS/frontend.log" 2>&1 &

sleep 1
echo "=== FIX APPLIED ==="
echo "UI: http://127.0.0.1:5173/"
