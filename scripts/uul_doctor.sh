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
