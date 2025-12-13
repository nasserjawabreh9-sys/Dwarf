#!/data/data/com.termux/files/usr/bin/bash
# =========================================================
# STATION ULTRA ONE-CLICK
# Self-Healing | Hard Reset | Run | Open Browser
# Termux-safe
# =========================================================

set +e

ROOT="${STATION_ROOT:-$HOME/station_root}"
BACKEND_DIR="$ROOT/backend"
FRONTEND_DIR="$ROOT/frontend"
LOG_DIR="$ROOT/station_logs"

BACKEND_HOST="127.0.0.1"
BACKEND_PORT="${STATION_BACKEND_PORT:-8000}"
FRONTEND_PORT="${STATION_FRONTEND_PORT:-5173}"

ENV_FILE="${STATION_ENV_FILE:-$HOME/station_env.sh}"

mkdir -p "$LOG_DIR"

ts(){ date +"%Y-%m-%d %H:%M:%S"; }
log(){ echo "[$(ts)] $*"; }

safe(){
  "$@" >/dev/null 2>&1
}

# -------------------------
# Bootstrap system tools
# -------------------------
bootstrap_tools(){
  log "Bootstrap system tools"
  safe pkg update -y
  safe pkg install -y python nodejs npm curl lsof
}

# -------------------------
# Load env (never fail)
# -------------------------
load_env(){
  if [[ -f "$ENV_FILE" ]]; then
    log "Loading env: $ENV_FILE"
    # shellcheck disable=SC1090
    source "$ENV_FILE" || true
  else
    log "Env file not found (ok)"
  fi
}

# -------------------------
# Kill anything on ports
# -------------------------
kill_port(){
  local p="$1"
  if command -v lsof >/dev/null 2>&1; then
    for pid in $(lsof -tiTCP:"$p" -sTCP:LISTEN 2>/dev/null); do
      log "Killing PID $pid on port $p"
      kill -9 "$pid" >/dev/null 2>&1 || true
    done
  fi
}

# -------------------------
# Backend reset + run
# -------------------------
run_backend(){
  log "=== BACKEND RESET ==="
  cd "$BACKEND_DIR" || exit 1

  kill_port "$BACKEND_PORT"

  # activate venv if exists
  if [[ -f ".venv/bin/activate" ]]; then
    source ".venv/bin/activate"
  elif [[ -f "venv/bin/activate" ]]; then
    source "venv/bin/activate"
  fi

  # reinstall deps if broken
  if [[ -f "requirements.txt" ]]; then
    log "Ensuring backend deps"
    safe python -m pip install -U pip
    safe python -m pip install -r requirements.txt
  fi

  log "Starting backend"
  nohup python -m uvicorn backend.app:app \
    --host "$BACKEND_HOST" \
    --port "$BACKEND_PORT" \
    --reload \
    >"$LOG_DIR/backend.log" 2>&1 &
}

# -------------------------
# Wait backend health
# -------------------------
wait_backend(){
  log "Waiting backend health"
  for i in {1..80}; do
    if curl -fs "http://$BACKEND_HOST:$BACKEND_PORT/healthz" >/dev/null 2>&1 \
    || curl -fs "http://$BACKEND_HOST:$BACKEND_PORT/health" >/dev/null 2>&1; then
      log "Backend healthy"
      return
    fi
    sleep 0.5
  done
  log "Backend health failed – tailing log"
  tail -n 80 "$LOG_DIR/backend.log"
}

# -------------------------
# Frontend reset + run
# -------------------------
run_frontend(){
  log "=== FRONTEND RESET ==="
  cd "$FRONTEND_DIR" || exit 1

  kill_port "$FRONTEND_PORT"

  rm -rf dist .vite node_modules package-lock.json >/dev/null 2>&1 || true

  log "Installing frontend deps"
  safe npm install

  export VITE_BACKEND_URL="http://$BACKEND_HOST:$BACKEND_PORT"

  log "Starting frontend"
  nohup npm run dev -- --host 127.0.0.1 --port "$FRONTEND_PORT" \
    >"$LOG_DIR/frontend.log" 2>&1 &
}

# -------------------------
# Open browser
# -------------------------
open_ui(){
  sleep 1.5
  local url="http://127.0.0.1:$FRONTEND_PORT/"
  if command -v termux-open-url >/dev/null 2>&1; then
    termux-open-url "$url"
  fi
  log "UI: $url"
}

# =========================
# MAIN FLOW
# =========================
log "========== STATION ULTRA START =========="
bootstrap_tools
load_env

log "Reset ports"
kill_port "$BACKEND_PORT"
kill_port "$FRONTEND_PORT"

run_backend
wait_backend
run_frontend
open_ui

log "========== STATION ULTRA RUNNING =========="
log "Backend log : $LOG_DIR/backend.log"
log "Frontend log: $LOG_DIR/frontend.log"
