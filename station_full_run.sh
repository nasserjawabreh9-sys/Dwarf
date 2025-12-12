#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
ENV_FILE="$HOME/station_env.sh"

BACKEND_PORT="${BACKEND_PORT:-8000}"
FRONTEND_PORT_BASE="${FRONTEND_PORT_BASE:-5173}"
FRONTEND_PORT_MAX_TRIES="${FRONTEND_PORT_MAX_TRIES:-20}"

log() { printf ">>> [STATION] %s\n" "$*"; }

is_port_busy() {
  local p="$1"
  # Try ss (preferred), fallback to netstat if available
  if command -v ss >/dev/null 2>&1; then
    ss -ltn | awk '{print $4}' | grep -qE "[:.]${p}$"
  elif command -v netstat >/dev/null 2>&1; then
    netstat -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${p}$"
  else
    # Worst-case: assume not busy
    return 1
  fi
}

pick_free_port() {
  local start="$1"
  local tries="$2"
  local p="$start"
  local i=0
  while [ "$i" -lt "$tries" ]; do
    if is_port_busy "$p"; then
      p=$((p+1))
      i=$((i+1))
      continue
    fi
    echo "$p"
    return 0
  done
  return 1
}

start_backend() {
  log "Starting backend on port ${BACKEND_PORT}..."
  cd "$ROOT/backend"

  if [ -f ".venv/bin/activate" ]; then
    # shellcheck disable=SC1091
    source .venv/bin/activate
  fi

  mkdir -p "$ROOT/station_logs"

  # Stop old backend if pid exists and running
  if [ -f "$ROOT/station_meta/dynamo/backend.pid" ]; then
    oldpid="$(cat "$ROOT/station_meta/dynamo/backend.pid" 2>/dev/null || true)"
    if [ -n "${oldpid:-}" ] && kill -0 "$oldpid" 2>/dev/null; then
      log "Stopping old backend pid=${oldpid}"
      kill "$oldpid" 2>/dev/null || true
      sleep 0.5
    fi
  fi

  nohup uvicorn app.main:app --host 0.0.0.0 --port "$BACKEND_PORT" \
    > "$ROOT/station_logs/backend.log" 2>&1 &

  echo $! > "$ROOT/station_meta/dynamo/backend.pid"
}

start_frontend() {
  local port
  port="$(pick_free_port "$FRONTEND_PORT_BASE" "$FRONTEND_PORT_MAX_TRIES")" || {
    log "ERROR: could not find a free frontend port starting from ${FRONTEND_PORT_BASE}"
    exit 2
  }

  log "Starting frontend (Vite) on port ${port}..."
  cd "$ROOT/frontend"

  mkdir -p "$ROOT/station_logs"

  # Stop old frontend if pid exists and running
  if [ -f "$ROOT/station_meta/dynamo/frontend.pid" ]; then
    oldpid="$(cat "$ROOT/station_meta/dynamo/frontend.pid" 2>/dev/null || true)"
    if [ -n "${oldpid:-}" ] && kill -0 "$oldpid" 2>/dev/null; then
      log "Stopping old frontend pid=${oldpid}"
      kill "$oldpid" 2>/dev/null || true
      sleep 0.5
    fi
  fi

  nohup npm run dev -- --host 0.0.0.0 --port "$port" \
    > "$ROOT/station_logs/frontend.log" 2>&1 &

  echo $! > "$ROOT/station_meta/dynamo/frontend.pid"

  # Save the chosen port for other scripts/tools
  mkdir -p "$ROOT/station_meta/bindings"
  cat > "$ROOT/station_meta/bindings/runtime_ports.json" << JSON
{
  "backend_port": ${BACKEND_PORT},
  "frontend_port": ${port},
  "ts": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSON

  echo "$port"
}

main() {
  log "Starting full Station (backend + frontend)..."

  if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    log "Environment loaded from $ENV_FILE"
  else
    log "WARNING: $ENV_FILE not found. Continuing without it."
  fi

  cd "$ROOT"
  mkdir -p station_meta/{dynamo,bindings} station_logs

  start_backend

  # Quick backend health check (best-effort)
  sleep 0.7
  if command -v curl >/dev/null 2>&1; then
    log "Backend health: curl http://127.0.0.1:${BACKEND_PORT}/health"
  fi

  fport="$(start_frontend)"

  log "All services started."
  log "Backend URL:   http://127.0.0.1:${BACKEND_PORT}/"
  log "Frontend URL:  http://127.0.0.1:${fport}/"
  log "Open in browser:"
  echo "termux-open-url http://127.0.0.1:${fport}/"
  log "Logs:"
  echo "tail -f $ROOT/station_logs/backend.log"
  echo "tail -f $ROOT/station_logs/frontend.log"
}

main "$@"
