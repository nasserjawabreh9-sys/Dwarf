#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
BACK="$ROOT/backend"
cd "$BACK"

PY="$BACK/.venv/bin/python"
if [ ! -x "$PY" ]; then
  PY="$(command -v python3 || command -v python)"
fi

echo "=== [RENDER_030] Local sanity ==="
echo "PY=$PY"
"$PY" -c "import importlib; importlib.import_module('app.main'); print('OK import app.main')"

echo "OK: run_render.sh exists?"
ls -la ops/run_render.sh
echo "DONE."
