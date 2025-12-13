#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
BACK="$ROOT/backend"
FRONT="$ROOT/frontend"

echo "=== [STATION_021] Fix No-Module + Render startCommand ==="
echo "ROOT=$ROOT"
echo

if [ ! -d "$BACK" ]; then
  echo "ERROR: backend dir not found: $BACK"
  exit 1
fi

# 1) Detect FastAPI entry file (best effort)
CAND="$(grep -RIl --exclude-dir=.venv --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build \
  "FastAPI(" "$BACK" 2>/dev/null | head -n 1 || true)"

if [ -z "${CAND:-}" ]; then
  echo "ERROR: Could not find FastAPI() in backend."
  exit 1
fi

echo "Detected FastAPI file: $CAND"

# 2) Build module path relative to backend root
REL="${CAND#$BACK/}"          # e.g. app/main.py
MOD="${REL%.py}"              # e.g. app/main
MOD="${MOD//\//.}"            # e.g. app.main

# detect variable name
APPVAR="app"
if grep -qE '^[[:space:]]*application[[:space:]]*=' "$CAND"; then
  APPVAR="application"
fi

echo "Uvicorn target: ${MOD}:${APPVAR}"
echo

# 3) Ensure packages have __init__.py along the path (e.g. app/__init__.py)
PKG_DIR="$(dirname "$CAND")"
while [ "$PKG_DIR" != "$BACK" ] && [ "$PKG_DIR" != "/" ]; do
  if [ ! -f "$PKG_DIR/__init__.py" ]; then
    : > "$PKG_DIR/__init__.py"
    echo "Added __init__.py -> $PKG_DIR/__init__.py"
  fi
  PKG_DIR="$(dirname "$PKG_DIR")"
done
echo

# 4) Create/overwrite ops/run_render.sh with correct working dir behavior
mkdir -p "$BACK/ops"
cat > "$BACK/ops/run_render.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
: "\${PORT:=8000}"
: "\${STATION_ENV:=prod}"

# Ensure backend root is importable
export PYTHONPATH="\$(pwd)"

echo ">>> [RUN_RENDER] STATION_ENV=\$STATION_ENV PORT=\$PORT PYTHONPATH=\$PYTHONPATH"
exec python -m uvicorn ${MOD}:${APPVAR} --host 0.0.0.0 --port "\$PORT"
EOF
chmod +x "$BACK/ops/run_render.sh"
echo "Created/Updated: $BACK/ops/run_render.sh"
echo

# 5) Import test MUST run inside backend dir
PY="$(command -v python || command -v python3 || true)"
if [ -z "$PY" ]; then
  echo "ERROR: python not found."
  exit 1
fi

echo ">>> Import test (inside backend):"
( cd "$BACK" && "$PY" - <<PY
import importlib
m = "${MOD}"
print("CWD:", __import__("os").getcwd())
print("Importing:", m)
importlib.import_module(m)
print("OK: Import succeeded")
PY
)

echo
# 6) Patch render.yaml startCommand path if present
if [ -f "$ROOT/render.yaml" ]; then
  if grep -q "startCommand: backend/ops/run_render.sh" "$ROOT/render.yaml"; then
    sed -i 's|startCommand: backend/ops/run_render.sh|startCommand: ops/run_render.sh|g' "$ROOT/render.yaml"
    echo "Patched render.yaml startCommand -> ops/run_render.sh"
  else
    echo "render.yaml startCommand looks OK (or different)."
  fi
else
  echo "NOTE: render.yaml not found at ROOT (skip patch)."
fi

echo
echo "OK: Fix applied."
echo "Next: Commit + Push, then Render Blueprint deploy."
