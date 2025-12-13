#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
BACK="$ROOT/backend"
VENV="$BACK/.venv"

echo "=== [STATION_022] Backend venv + requirements install ==="
echo "ROOT=$ROOT"
echo "BACK=$BACK"
echo "VENV=$VENV"
echo

if [ ! -d "$BACK" ]; then
  echo "ERROR: backend dir not found: $BACK"
  exit 1
fi

if [ ! -f "$BACK/requirements.txt" ]; then
  echo "ERROR: requirements.txt not found in backend/"
  echo "Found files:"
  ls -la "$BACK" | head -n 50
  exit 1
fi

PY="$(command -v python || command -v python3 || true)"
if [ -z "$PY" ]; then
  echo "ERROR: python not found."
  exit 1
fi

echo ">>> Python:"
"$PY" -V
echo

# Create venv if missing
if [ ! -d "$VENV" ]; then
  echo ">>> Creating venv..."
  ( cd "$BACK" && "$PY" -m venv .venv )
else
  echo ">>> venv already exists."
fi

# Activate venv
# shellcheck disable=SC1090
source "$VENV/bin/activate"

echo ">>> Upgrading pip/setuptools/wheel..."
python -m pip install --upgrade pip setuptools wheel

echo ">>> Installing backend requirements..."
python -m pip install -r "$BACK/requirements.txt"

echo
echo ">>> Verify packages:"
python - <<'PY'
import fastapi, uvicorn
print("fastapi:", fastapi.__version__)
print("uvicorn:", uvicorn.__version__)
PY

echo
echo ">>> Import test (inside backend, with venv):"
( cd "$BACK" && python - <<'PY'
import importlib, os
print("CWD:", os.getcwd())
m="app.main"
print("Importing:", m)
importlib.import_module(m)
print("OK: Import succeeded")
PY
)

echo
echo "OK: Backend environment ready."
echo "Next: use venv python/uvicorn when running locally."
