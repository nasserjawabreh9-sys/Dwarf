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
