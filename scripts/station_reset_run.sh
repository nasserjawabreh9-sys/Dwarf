#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
source "$ROOT/station_env.sh" || true
LOGS="$ROOT/station_logs"
mkdir -p "$LOGS"

pkg install -y lsof curl >/dev/null 2>&1 || true

BACKEND_PORT="${STATION_BACKEND_PORT:-8000}"
FRONTEND_PORT="${STATION_FRONTEND_PORT:-5173}"

kill_port(){
  local p="$1"
  if command -v lsof >/dev/null 2>&1; then
    for pid in $(lsof -tiTCP:"$p" -sTCP:LISTEN 2>/dev/null); do
      kill -9 "$pid" >/dev/null 2>&1 || true
    done
  fi
}

kill_port "$BACKEND_PORT"
kill_port "$FRONTEND_PORT"

cd "$ROOT/frontend"
rm -rf dist .vite node_modules package-lock.json >/dev/null 2>&1 || true
npm install >"$LOGS/npm_install.log" 2>&1 || { tail -n 120 "$LOGS/npm_install.log"; exit 1; }

cd "$ROOT/backend"
if [[ ! -d ".venv" ]]; then
  python -m venv .venv
fi
source "$ROOT/backend/.venv/bin/activate"
python -m pip install -U pip >/dev/null 2>&1 || true
python -m pip install -r requirements.txt >"$LOGS/pip_install.log" 2>&1 || { tail -n 120 "$LOGS/pip_install.log"; exit 1; }

bash "$ROOT/scripts/station_run.sh"
