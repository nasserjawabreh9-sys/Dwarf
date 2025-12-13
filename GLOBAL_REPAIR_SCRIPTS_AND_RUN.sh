#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT="$HOME/station_root"
BACKEND="$ROOT/backend"
FRONTEND="$ROOT/frontend"
SCRIPTS="$ROOT/scripts"
LOGS="$ROOT/station_logs"
mkdir -p "$BACKEND" "$FRONTEND" "$SCRIPTS" "$LOGS"

echo "=== GLOBAL REPAIR: scripts + run ==="

# --- system deps (best-effort) ---
pkg update -y >/dev/null 2>&1 || true
pkg install -y python nodejs npm curl lsof ca-certificates >/dev/null 2>&1 || true

# --- write scripts ---
cat > "$SCRIPTS/uul_doctor.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
echo "ROOT=$ROOT"
echo "Python: $(python -V 2>/dev/null || true)"
echo "Node:   $(node -v 2>/dev/null || true)"
echo "Npm:    $(npm -v 2>/dev/null || true)"
echo "Ports:"
lsof -iTCP:8000 -sTCP:LISTEN 2>/dev/null || true
lsof -iTCP:5173 -sTCP:LISTEN 2>/dev/null || true
echo "Tree:"
ls -la "$ROOT" || true
ls -la "$ROOT/backend" || true
ls -la "$ROOT/frontend" || true
EOF

cat > "$SCRIPTS/uul_backup.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$ROOT/backups/station_backup_$TS.tgz"
mkdir -p "$ROOT/backups"
tar -czf "$OUT" \
  --exclude="**/node_modules" \
  --exclude="**/.venv" \
  --exclude="**/dist" \
  --exclude="**/.vite" \
  --exclude="**/__pycache__" \
  --exclude="**/*.pyc" \
  -C "$ROOT" backend frontend scripts station_env.sh README.md .gitignore app_storage station_logs 2>/dev/null || true
echo "BACKUP: $OUT"
EOF

cat > "$SCRIPTS/uul_harden_local.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
mkdir -p "$ROOT/ops/hardening"
cat > "$ROOT/ops/hardening/HARDENING_CHECKLIST.md" <<'MD'
# Station Hardening Checklist (Local)
- Keep backend bound to 127.0.0.1 in Termux.
- Do not commit secrets. Use UI/LocalStorage/backend store.
- Logs: station_logs/
- Backups: backups/
- If exposed externally: reverse proxy + TLS + auth.
MD
echo "Wrote: $ROOT/ops/hardening/HARDENING_CHECKLIST.md"
EOF

cat > "$SCRIPTS/uul_build.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
LOGS="$ROOT/station_logs"; mkdir -p "$LOGS"

echo "=== BUILD BACKEND ==="
cd "$ROOT/backend"
if [[ ! -f requirements.txt ]]; then
  cat > requirements.txt <<'REQ'
fastapi
uvicorn
REQ
fi
rm -rf .venv
python -m venv .venv
source .venv/bin/activate
python -m pip install -U pip >/dev/null
python -m pip install -r requirements.txt >"$LOGS/pip_install.log" 2>&1

echo "=== BUILD FRONTEND ==="
cd "$ROOT/frontend"
if [[ ! -f package.json ]]; then
  cat > package.json <<'PKG'
{
  "name": "station",
  "private": true,
  "version": "0.0.1",
  "scripts": { "dev": "vite" },
  "dependencies": { "react": "^18.3.1", "react-dom": "^18.3.1" },
  "devDependencies": { "vite": "^5.4.11", "typescript": "^5.6.3" }
}
PKG
fi
rm -rf node_modules package-lock.json
npm install >"$LOGS/npm_install.log" 2>&1
EOF

cat > "$SCRIPTS/uul_run.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
LOGS="$ROOT/station_logs"; mkdir -p "$LOGS"

kill_port(){
  local p="$1"
  for pid in $(lsof -tiTCP:"$p" -sTCP:LISTEN 2>/dev/null); do
    kill -9 "$pid" >/dev/null 2>&1 || true
  done
}

mkdir -p "$ROOT/backend/backend"
mkdir -p "$ROOT/frontend/src"

# minimal backend app
if [[ ! -f "$ROOT/backend/backend/app.py" ]]; then
  cat > "$ROOT/backend/backend/app.py" <<'PY'
from fastapi import FastAPI
app = FastAPI()
@app.get("/healthz")
def healthz(): return {"ok": True}
PY
fi

# minimal frontend
if [[ ! -f "$ROOT/frontend/index.html" ]]; then
  cat > "$ROOT/frontend/index.html" <<'HTML'
<!doctype html><html><head><meta charset="UTF-8" /><meta name="viewport" content="width=device-width, initial-scale=1.0" /><title>Station</title></head><body><div id="root"></div><script type="module" src="/src/main.tsx"></script></body></html>
HTML
fi

if [[ ! -f "$ROOT/frontend/src/main.tsx" ]]; then
  cat > "$ROOT/frontend/src/main.tsx" <<'TSX'
import { createRoot } from "react-dom/client";
createRoot(document.getElementById("root")!).render(<div style={{fontFamily:"system-ui"}}>Station OK</div>);
TSX
fi

# build deps if needed
bash "$ROOT/scripts/uul_build.sh"

# run
kill_port 8000
kill_port 5173

echo "=== RUN BACKEND ==="
cd "$ROOT/backend"
source .venv/bin/activate
nohup python -m uvicorn backend.app:app --host 127.0.0.1 --port 8000 >"$LOGS/backend.log" 2>&1 &

sleep 1
curl -fsS http://127.0.0.1:8000/healthz >/dev/null || { echo "Backend failed"; tail -n 80 "$LOGS/backend.log"; exit 1; }

echo "=== RUN FRONTEND ==="
cd "$ROOT/frontend"
nohup npm run dev -- --host 127.0.0.1 --port 5173 >"$LOGS/frontend.log" 2>&1 &

sleep 1
echo "UI: http://127.0.0.1:5173/"
EOF

chmod +x "$SCRIPTS/"uul_*.sh

# optional env template
if [[ ! -f "$ROOT/station_env.sh" ]]; then
  cat > "$ROOT/station_env.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -e
export STATION_ROOT="$HOME/station_root"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export PYTHONIOENCODING="utf-8"
echo "[station_env] Loaded."
EOF
  chmod +x "$ROOT/station_env.sh"
fi

# final: run
bash "$SCRIPTS/uul_run.sh"
