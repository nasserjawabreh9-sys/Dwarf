#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

# =========================
# Station Unified Runner
# Termux-safe
# =========================

ROOT="${STATION_ROOT:-$HOME/station_root}"
BACKEND_DIR="$ROOT/backend"
FRONTEND_DIR="$ROOT/frontend"
LOG_DIR="$ROOT/station_logs"
BACKEND_PORT="${STATION_BACKEND_PORT:-8000}"
FRONTEND_PORT="${STATION_FRONTEND_PORT:-5173}"
BACKEND_HOST="${STATION_BACKEND_HOST:-127.0.0.1}"

ENV_FILE="${STATION_ENV_FILE:-$HOME/station_env.sh}"

mkdir -p "$LOG_DIR"

ts() { date +"%Y-%m-%d %H:%M:%S"; }
say() { echo "[$(ts)] $*"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { say "ERROR: missing command: $1"; exit 1; }
}

port_in_use() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then
    lsof -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
  else
    # fallback using python
    python - <<PY >/dev/null 2>&1
import socket
s=socket.socket()
try:
  s.bind(("127.0.0.1", int("$port")))
  ok=True
except OSError:
  ok=False
finally:
  s.close()
exit(0 if not ok else 1)
PY
  fi
}

kill_port() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then
    local pids
    pids="$(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)"
    if [[ -n "${pids:-}" ]]; then
      say "Port $port in use; killing pids: $pids"
      kill -9 $pids >/dev/null 2>&1 || true
    fi
  else
    say "lsof not found; cannot auto-kill port $port reliably (install lsof)."
  fi
}

health_check() {
  local url="$1"
  local tries="${2:-40}"
  local wait_s="${3:-0.5}"
  for i in $(seq 1 "$tries"); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$wait_s"
  done
  return 1
}

load_env() {
  if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE" || true
    say "Loaded env: $ENV_FILE"
  else
    say "Env file not found: $ENV_FILE (ok)."
  fi
}

ensure_dirs() {
  [[ -d "$ROOT" ]] || { say "ERROR: ROOT not found: $ROOT"; exit 1; }
  [[ -d "$BACKEND_DIR" ]] || { say "ERROR: backend dir not found: $BACKEND_DIR"; exit 1; }
  [[ -d "$FRONTEND_DIR" ]] || { say "ERROR: frontend dir not found: $FRONTEND_DIR"; exit 1; }
}

ensure_tools() {
  need_cmd python
  need_cmd node
  need_cmd npm
  need_cmd curl
  if ! command -v lsof >/dev/null 2>&1; then
    say "NOTE: lsof not found. Installing for better port handling..."
    pkg install -y lsof >/dev/null 2>&1 || true
  fi
}

start_backend() {
  local out="$LOG_DIR/backend.log"
  say "Starting backend on http://$BACKEND_HOST:$BACKEND_PORT ..."
  cd "$BACKEND_DIR"

  if [[ -f ".venv/bin/activate" ]]; then
    # shellcheck disable=SC1091
    source ".venv/bin/activate"
  elif [[ -f "venv/bin/activate" ]]; then
    # shellcheck disable=SC1091
    source "venv/bin/activate"
  fi

  # kill lingering uvicorn on port
  if port_in_use "$BACKEND_PORT"; then kill_port "$BACKEND_PORT"; fi

  # prefer uvicorn if available, otherwise python -m uvicorn
  if command -v uvicorn >/dev/null 2>&1; then
    nohup uvicorn backend.app:app --host "$BACKEND_HOST" --port "$BACKEND_PORT" --reload \
      >"$out" 2>&1 &
  else
    nohup python -m uvicorn backend.app:app --host "$BACKEND_HOST" --port "$BACKEND_PORT" --reload \
      >"$out" 2>&1 &
  fi

  say "Backend pid: $! (log: $out)"
}

start_frontend() {
  local out="$LOG_DIR/frontend.log"
  say "Starting frontend on http://127.0.0.1:$FRONTEND_PORT ..."
  cd "$FRONTEND_DIR"

  # kill lingering vite on port
  if port_in_use "$FRONTEND_PORT"; then kill_port "$FRONTEND_PORT"; fi

  # install deps if missing
  if [[ ! -d "node_modules" ]]; then
    say "node_modules missing; running npm install..."
    npm install >"$LOG_DIR/npm_install.log" 2>&1 || { say "ERROR: npm install failed. See $LOG_DIR/npm_install.log"; exit 1; }
  fi

  # pass backend url to vite if project uses it
  export VITE_BACKEND_URL="${VITE_BACKEND_URL:-http://$BACKEND_HOST:$BACKEND_PORT}"

  nohup npm run dev -- --host 127.0.0.1 --port "$FRONTEND_PORT" >"$out" 2>&1 &
  say "Frontend pid: $! (log: $out)"
}

open_browser() {
  local url="$1"
  if command -v termux-open-url >/dev/null 2>&1; then
    termux-open-url "$url" >/dev/null 2>&1 || true
    say "Opened: $url"
  else
    say "termux-open-url not found. Open manually: $url"
  fi
}

main() {
  say "=== Station Unified Runner ==="
  say "ROOT=$ROOT"
  ensure_dirs
  ensure_tools
  load_env

  start_backend

  # try /healthz then fallback /health
  local h1="http://$BACKEND_HOST:$BACKEND_PORT/healthz"
  local h2="http://$BACKEND_HOST:$BACKEND_PORT/health"
  if health_check "$h1" 60 0.5; then
    say "Backend healthy: $h1"
  elif health_check "$h2" 60 0.5; then
    say "Backend healthy: $h2"
  else
    say "ERROR: backend not healthy. Check log: $LOG_DIR/backend.log"
    tail -n 80 "$LOG_DIR/backend.log" || true
    exit 1
  fi

  start_frontend

  # wait a moment for vite
  sleep 1.2

  local ui="http://127.0.0.1:$FRONTEND_PORT/"
  open_browser "$ui"

  say "=== RUNNING ==="
  say "Backend: http://$BACKEND_HOST:$BACKEND_PORT"
  say "Frontend: $ui"
  say "Logs: $LOG_DIR"
  say "Tip: tail -f $LOG_DIR/backend.log"
  say "Tip: tail -f $LOG_DIR/frontend.log"
}

main "$@"
