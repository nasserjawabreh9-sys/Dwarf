#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_REPO_DIR:-$HOME/station_root}"
PORT="${PORT:-8000}"
LOGS="$ROOT/.logs"
mkdir -p "$LOGS"

cd "$ROOT"

echo "== Paths =="
echo "ROOT=$ROOT"
echo "Backend=$ROOT/backend"
echo "Scripts=$ROOT/scripts"
echo

echo "== Python =="
python -V || true
echo

echo "== Backend quick check =="
if curl -fsS "http://127.0.0.1:$PORT/healthz" >/dev/null 2>&1; then
  echo "OK: /healthz responding"
else
  echo "WARN: backend not responding on localhost. Attempting to start..."
  "$ROOT/scripts/full_run_local.sh" || true
fi

echo
echo "== Endpoints =="
for p in "/" "/healthz" "/docs"; do
  code="$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT$p" || true)"
  echo "$p -> $code"
done

echo
echo "== Tail backend log =="
tail -n 80 "$LOGS/backend.log" 2>/dev/null || true
