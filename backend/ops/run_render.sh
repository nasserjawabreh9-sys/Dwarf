#!/usr/bin/env bash
set -euo pipefail
: "${PORT:=8000}"
: "${STATION_ENV:=prod}"

# Ensure backend root is importable
export PYTHONPATH="$(pwd)"

echo ">>> [RUN_RENDER] STATION_ENV=$STATION_ENV PORT=$PORT PYTHONPATH=$PYTHONPATH"
exec python -m uvicorn app.main:app --host 0.0.0.0 --port "$PORT"
