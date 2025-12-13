#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"

echo "=== [STATION_010] Inspect ==="
echo "ROOT=$ROOT"
echo

if [ ! -d "$ROOT" ]; then
  echo "ERROR: station_root not found at: $ROOT"
  exit 1
fi

echo ">> Tree (depth=2):"
command -v tree >/dev/null 2>&1 && tree -L 2 "$ROOT" || find "$ROOT" -maxdepth 2 -print
echo

echo ">> Backend candidates:"
find "$ROOT/backend" -maxdepth 3 -type f \( -name "main.py" -o -name "app.py" -o -name "wsgi.py" -o -name "asgi.py" \) 2>/dev/null || true
echo

echo ">> FastAPI app occurrences (top 20):"
grep -RIn --exclude-dir=.venv --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build \
  "FastAPI(" "$ROOT/backend" 2>/dev/null | head -n 20 || true
echo

echo ">> Uvicorn occurrences (top 20):"
grep -RIn --exclude-dir=.venv --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build \
  "uvicorn" "$ROOT/backend" 2>/dev/null | head -n 20 || true
echo

echo ">> Frontend package.json:"
if [ -f "$ROOT/frontend/package.json" ]; then
  sed -n '1,120p' "$ROOT/frontend/package.json"
else
  echo "No frontend/package.json found."
fi
echo

echo "OK: Inspect completed."
