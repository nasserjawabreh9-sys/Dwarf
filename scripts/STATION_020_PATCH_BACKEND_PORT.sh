#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
BACK="$ROOT/backend"

echo "=== [STATION_020] Patch backend start for Render PORT ==="
echo "ROOT=$ROOT"
echo

if [ ! -d "$BACK" ]; then
  echo "ERROR: backend dir not found: $BACK"
  exit 1
fi

# Heuristic: find first file containing FastAPI() and looks like app entry
CAND="$(grep -RIl --exclude-dir=.venv --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build \
  "FastAPI(" "$BACK" 2>/dev/null | head -n 1 || true)"

if [ -z "${CAND:-}" ]; then
  echo "ERROR: Could not find a FastAPI entry file in backend."
  echo "TIP: Ensure your FastAPI app exists (e.g., backend/app/main.py with app = FastAPI())."
  exit 1
fi

echo "Detected FastAPI file: $CAND"

# Determine module path for uvicorn (best effort)
# Convert path like /.../backend/app/main.py -> app.main:app
REL="${CAND#$BACK/}"                # app/main.py
MOD="${REL%.py}"                    # app/main
MOD="${MOD//\//.}"                  # app.main

# Detect app variable name (default: app)
APPVAR="app"
if grep -qE '^[[:space:]]*application[[:space:]]*=' "$CAND"; then
  APPVAR="application"
fi

echo "Uvicorn target guess: ${MOD}:${APPVAR}"
echo

# Create a deterministic Render start script
mkdir -p "$BACK/ops"
cat > "$BACK/ops/run_render.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail

: "\${PORT:=8000}"
: "\${STATION_ENV:=prod}"

echo ">>> [RUN_RENDER] STATION_ENV=\$STATION_ENV PORT=\$PORT"
exec uvicorn ${MOD}:${APPVAR} --host 0.0.0.0 --port "\$PORT"
EOF
chmod +x "$BACK/ops/run_render.sh"

echo "Created: $BACK/ops/run_render.sh"
echo

# Quick local sanity (does not require PORT open, just checks uvicorn import)
echo ">>> Quick import test (python -c):"
PY="$(command -v python || command -v python3 || true)"
if [ -z "$PY" ]; then
  echo "ERROR: python not found."
  exit 1
fi

# Try importing the module
"$PY" - <<PY
import importlib
m = "${MOD}"
print("Importing:", m)
importlib.import_module(m)
print("OK: Import succeeded")
PY

echo
echo "OK: Backend Render start script prepared."
