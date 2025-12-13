#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
cd "$ROOT"

echo "=== [RENDER_020] Git commit + push ==="
git status

git add .python-version backend/.env.example backend/ops/preflight.py backend/ops/run_render.sh
git commit -m "render: pin python + preflight + hardened run_render" || true
git push
echo "OK: pushed."
