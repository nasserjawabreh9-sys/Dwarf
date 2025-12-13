#!/usr/bin/env bash
set -euo pipefail

: "${PORT:=8000}"
: "${STATION_ENV:=prod}"

# Prefer venv python if exists (Render might not use venv, but this is fine)
if [ -x "$(pwd)/.venv/bin/python" ]; then
  PY="$(pwd)/.venv/bin/python"
elif [ -x "$(pwd)/venv/bin/python" ]; then
  PY="$(pwd)/venv/bin/python"
else
  PY="python3"
fi

echo ">>> [RUN_RENDER] STATION_ENV=$STATION_ENV PORT=$PORT PY=$PY"
exec "$PY" -m uvicorn app.main:app --host 0.0.0.0 --port "$PORT"
