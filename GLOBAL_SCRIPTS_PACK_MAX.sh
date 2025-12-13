#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
SCRIPTS="$ROOT/scripts"
OPS="$ROOT/ops"
LOGS="$ROOT/station_logs"
BACKEND="$ROOT/backend"
FRONTEND="$ROOT/frontend"

mkdir -p "$SCRIPTS" "$OPS" "$LOGS" "$ROOT"/{db,seed,backups,artifacts,docs,app_storage}

ts(){ date +"%Y-%m-%d %H:%M:%S"; }
say(){ echo "[$(ts)] $*"; }

ensure_pkgs(){
  pkg update -y >/dev/null 2>&1 || true
  pkg install -y git curl jq lsof ca-certificates python nodejs npm openssh openssl termux-tools >/dev/null 2>&1 || true
}

write_env_template(){
  if [[ ! -f "$ROOT/station_env.sh" ]]; then
    cat > "$ROOT/station_env.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -e

export STATION_ROOT="$HOME/station_root"
export STATION_BACKEND_HOST="127.0.0.1"
export STATION_BACKEND_PORT="8000"
export STATION_FRONTEND_HOST="127.0.0.1"
export STATION_FRONTEND_PORT="5173"

export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export PYTHONIOENCODING="utf-8"

# Do not store secrets here. Use UI -> LocalStorage/Backend Store.
export STATION_EDIT_MODE_KEY="${STATION_EDIT_MODE_KEY:-1234}"

echo "[station_env] Loaded."
EOF
    chmod +x "$ROOT/station_env.sh"
  fi
}

write_gitignore(){
  cat > "$ROOT/.gitignore" <<'EOF'
# Python
__pycache__/
*.pyc
.venv/
**/.venv/

# Node
node_modules/
dist/
.vite/

# Runtime
station_logs/
app_storage/
backups/
artifacts/
EOF
}

write_readme(){
  cat > "$ROOT/README.md" <<'EOF'
# Station - Global Scripts Pack

## One command ops
bash scripts/station_ops.sh status
bash scripts/station_ops.sh build
bash scripts/station_ops.sh run
bash scripts/station_ops.sh restart
bash scripts/station_ops.sh stop
bash scripts/station_ops.sh logs backend
bash scripts/station_ops.sh logs frontend
bash scripts/station_ops.sh doctor
bash scripts/station_ops.sh backup
bash scripts/station_ops.sh restore <backup.tgz>
bash scripts/station_ops.sh git init
bash scripts/station_ops.sh git push "message"

## Health
curl -fsS http://127.0.0.1:8000/healthz
EOF
}

write_script_doctor(){
  cat > "$SCRIPTS/uul_doctor.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
source "$ROOT/station_env.sh" 2>/dev/null || true

echo "=== DOCTOR ==="
echo "ROOT=$ROOT"
echo "Python: $(python -V 2>/dev/null || true)"
echo "Node:   $(node -v 2>/dev/null || true)"
echo "Npm:    $(npm -v 2>/dev/null || true)"
echo "Git:    $(git --version 2>/dev/null || true)"
echo ""

echo "=== Ports (listeners) ==="
lsof -iTCP:8000 -sTCP:LISTEN 2>/dev/null || true
lsof -iTCP:5173 -sTCP:LISTEN 2>/dev/null || true
echo ""

echo "=== Tree ==="
ls -la "$ROOT" || true
echo ""
ls -la "$ROOT/backend" || true
echo ""
ls -la "$ROOT/frontend" || true
echo ""

echo "=== Logs (tail) ==="
tail -n 40 "$ROOT/station_logs/backend.log" 2>/dev/null || true
echo ""
tail -n 40 "$ROOT/station_logs/frontend.log" 2>/dev/null || true
EOF
  chmod +x "$SCRIPTS/uul_doctor.sh"
}

write_script_ports(){
  cat > "$SCRIPTS/uul_ports.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
kill_port(){
  local p="$1"
  for pid in $(lsof -tiTCP:"$p" -sTCP:LISTEN 2>/dev/null); do
    kill -9 "$pid" >/dev/null 2>&1 || true
  done
}
case "${1:-}" in
  kill)
    kill_port "${2:-8000}"
    kill_port "${3:-5173}"
    ;;
  show|*)
    lsof -iTCP:8000 -sTCP:LISTEN 2>/dev/null || true
    lsof -iTCP:5173 -sTCP:LISTEN 2>/dev/null || true
    ;;
esac
EOF
  chmod +x "$SCRIPTS/uul_ports.sh"
}

write_script_logs(){
  cat > "$SCRIPTS/uul_logs.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
LOGS="$ROOT/station_logs"
mkdir -p "$LOGS"

target="${1:-}"
case "$target" in
  backend)  tail -n 200 "$LOGS/backend.log" 2>/dev/null || true ;;
  frontend) tail -n 200 "$LOGS/frontend.log" 2>/dev/null || true ;;
  trace)    tail -n 200 "$LOGS/ops_trace.log" 2>/dev/null || true ;;
  *) echo "usage: uul_logs.sh backend|frontend|trace"; exit 2 ;;
esac
EOF
  chmod +x "$SCRIPTS/uul_logs.sh"
}

write_script_snapshot(){
  cat > "$SCRIPTS/uul_snapshot.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
OUT="$ROOT/artifacts/snapshot_$(date +%Y%m%d_%H%M%S).txt"
mkdir -p "$ROOT/artifacts"

{
  echo "SNAPSHOT $(date -Iseconds)"
  echo "ROOT=$ROOT"
  echo ""
  echo "== Versions =="
  python -V 2>/dev/null || true
  node -v 2>/dev/null || true
  npm -v 2>/dev/null || true
  git --version 2>/dev/null || true
  echo ""
  echo "== Ports =="
  lsof -iTCP:8000 -sTCP:LISTEN 2>/dev/null || true
  lsof -iTCP:5173 -sTCP:LISTEN 2>/dev/null || true
  echo ""
  echo "== Backend health =="
  curl -fsS http://127.0.0.1:8000/healthz 2>/dev/null || true
  echo ""
  echo "== Tree =="
  (cd "$ROOT" && find . -maxdepth 3 -type f | sed 's|^\./||') 2>/dev/null || true
} > "$OUT"

echo "Wrote: $OUT"
EOF
  chmod +x "$SCRIPTS/uul_snapshot.sh"
}

write_script_backup_restore(){
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
  -C "$ROOT" \
  backend frontend scripts ops docs README.md .gitignore station_env.sh app_storage station_logs 2>/dev/null || true

echo "BACKUP: $OUT"
EOF

  cat > "$SCRIPTS/uul_restore.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
ARCH="${1:-}"
if [[ -z "$ARCH" || ! -f "$ARCH" ]]; then
  echo "usage: uul_restore.sh <backup.tgz>"
  exit 2
fi

mkdir -p "$ROOT/_restore_tmp"
tar -xzf "$ARCH" -C "$ROOT/_restore_tmp"
cp -R "$ROOT/_restore_tmp/"* "$ROOT/" 2>/dev/null || true
rm -rf "$ROOT/_restore_tmp"

echo "RESTORED from: $ARCH"
EOF

  chmod +x "$SCRIPTS/uul_backup.sh" "$SCRIPTS/uul_restore.sh"
}

write_script_build(){
  cat > "$SCRIPTS/uul_build.sh" <<'EOF'
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
EOF
  chmod +x "$SCRIPTS/uul_build.sh"
}

write_script_run_stop_restart(){
  cat > "$SCRIPTS/uul_run.sh" <<'EOF'
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
nohup python -m uvicorn backend.app:app --host "$HOST" --port "$BPORT" --reload >"$LOGS/backend.log" 2>&1 &

sleep 1
health_wait || { echo "Backend unhealthy"; tail -n 120 "$LOGS/backend.log"; exit 1; }

echo "=== RUN FRONTEND ==="
cd "$FRONTEND"
nohup npm run dev -- --host "$FHOST" --port "$FPORT" >"$LOGS/frontend.log" 2>&1 &

sleep 1
echo "UI: http://$FHOST:$FPORT/"
EOF

  cat > "$SCRIPTS/uul_stop.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
for p in 8000 5173; do
  for pid in $(lsof -tiTCP:"$p" -sTCP:LISTEN 2>/dev/null); do
    kill -9 "$pid" >/dev/null 2>&1 || true
  done
done
echo "Stopped ports 8000/5173 (if any)."
EOF

  cat > "$SCRIPTS/uul_restart.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
bash "$ROOT/scripts/uul_stop.sh"
bash "$ROOT/scripts/uul_run.sh"
EOF

  chmod +x "$SCRIPTS/uul_run.sh" "$SCRIPTS/uul_stop.sh" "$SCRIPTS/uul_restart.sh"
}

write_script_hardening(){
  cat > "$SCRIPTS/uul_harden_local.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
mkdir -p "$ROOT/ops/hardening"

cat > "$ROOT/ops/hardening/HARDENING.md" <<'MD'
# Hardening (Local / Termux)

## Baseline
- Bind backend to 127.0.0.1 (default).
- Keep secrets out of repo and env files.
- Use UI/LocalStorage + backend settings store.

## Runtime
- Logs: station_logs/
- Backups: backups/
- Artifacts: artifacts/

## If exposing externally
- Put behind reverse proxy + TLS + auth.
- Add allowlist CORS.
- Add stronger rate limit + auth tokens.
MD

echo "Wrote: $ROOT/ops/hardening/HARDENING.md"
EOF
  chmod +x "$SCRIPTS/uul_harden_local.sh"
}

write_script_git_ops(){
  cat > "$SCRIPTS/uul_git.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
cmd="${1:-}"
msg="${2:-station update}"

case "$cmd" in
  init)
    cd "$ROOT"
    git init
    git branch -M main
    git add -A
    git commit -m "init station" || true
    echo "Git initialized. Add remote manually: git remote add origin <url>"
    ;;
  status)
    cd "$ROOT"
    git status -sb || true
    ;;
  push)
    cd "$ROOT"
    git add -A
    git commit -m "$msg" || true
    git push -u origin main
    ;;
  *)
    echo "usage: uul_git.sh init|status|push [message]"
    exit 2
    ;;
esac
EOF
  chmod +x "$SCRIPTS/uul_git.sh"
}

write_script_render_check(){
  cat > "$SCRIPTS/uul_render_check.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
API="${RENDER_API_KEY:-${1:-}}"
if [[ -z "$API" ]]; then
  echo "usage: RENDER_API_KEY=... uul_render_check.sh"
  exit 2
fi
curl -fsS "https://api.render.com/v1/services" -H "Authorization: Bearer $API" | head -c 2000
echo ""
EOF
  chmod +x "$SCRIPTS/uul_render_check.sh"
}

write_script_ops_unified(){
  cat > "$SCRIPTS/station_ops.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
LOGS="$ROOT/station_logs"; mkdir -p "$LOGS"
cmd="${1:-status}"; shift || true

trace(){
  echo "[ops] $(date -Iseconds) $cmd $*" >> "$LOGS/ops_trace.log"
}
trace "$@"

case "$cmd" in
  status)
    echo "=== STATUS ==="
    bash "$ROOT/scripts/uul_ports.sh" show || true
    echo ""
    curl -fsS http://127.0.0.1:8000/healthz 2>/dev/null && echo "" || echo "Backend healthz not reachable"
    ;;
  build)   bash "$ROOT/scripts/uul_build.sh" ;;
  run)     bash "$ROOT/scripts/uul_run.sh" ;;
  stop)    bash "$ROOT/scripts/uul_stop.sh" ;;
  restart) bash "$ROOT/scripts/uul_restart.sh" ;;
  doctor)  bash "$ROOT/scripts/uul_doctor.sh" ;;
  snapshot)bash "$ROOT/scripts/uul_snapshot.sh" ;;
  backup)  bash "$ROOT/scripts/uul_backup.sh" ;;
  restore) bash "$ROOT/scripts/uul_restore.sh" "${1:-}" ;;
  logs)    bash "$ROOT/scripts/uul_logs.sh" "${1:-backend}" ;;
  harden)  bash "$ROOT/scripts/uul_harden_local.sh" ;;
  git)     bash "$ROOT/scripts/uul_git.sh" "${1:-status}" "${2:-station update}" ;;
  render)  bash "$ROOT/scripts/uul_render_check.sh" "${1:-}" ;;
  *)
    echo "usage: station_ops.sh status|build|run|stop|restart|doctor|snapshot|backup|restore|logs|harden|git|render"
    exit 2
    ;;
esac
EOF
  chmod +x "$SCRIPTS/station_ops.sh"
}

main(){
  say "GLOBAL: generating scripts pack..."
  ensure_pkgs
  write_env_template
  write_gitignore
  write_readme

  write_script_doctor
  write_script_ports
  write_script_logs
  write_script_snapshot
  write_script_backup_restore
  write_script_build
  write_script_run_stop_restart
  write_script_hardening
  write_script_git_ops
  write_script_render_check
  write_script_ops_unified

  say "DONE: scripts created under $SCRIPTS"
  say "Try: bash $SCRIPTS/station_ops.sh status"
}

main "$@"
