#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
LOGS="$ROOT/station_logs"; mkdir -p "$LOGS"
BACKEND="$ROOT/backend"
FRONTEND="$ROOT/frontend"

pkg install -y python nodejs npm curl >/dev/null 2>&1 || true

echo "=== BUILD BACKEND ==="
cd "$BACKEND"
if [[ ! -f requirements.txt ]]; then
  cat > requirements.txt <<'REQ'
fastapi
uvicorn
REQ
fi
if [[ ! -f backend/app.py && ! -f backend/app.py ]]; then :; fi

rm -rf .venv
python -m venv .venv
source .venv/bin/activate
python -m pip install -U pip >/dev/null
python -m pip install -r requirements.txt >"$LOGS/pip_install.log" 2>&1

echo "=== BUILD FRONTEND ==="
cd "$FRONTEND"
if [[ ! -f package.json ]]; then
  cat > package.json <<'PKG'
{
  "name": "station",
  "private": true,
  "version": "0.0.1",
  "scripts": { "dev": "vite", "build": "vite build" },
  "dependencies": { "react": "^18.3.1", "react-dom": "^18.3.1" },
  "devDependencies": { "vite": "^5.4.11", "typescript": "^5.6.3" }
}
PKG
fi
rm -rf node_modules package-lock.json
npm install >"$LOGS/npm_install.log" 2>&1
