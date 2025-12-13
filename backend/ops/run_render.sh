#!/usr/bin/env bash
set -euo pipefail
: "${PORT:=8000}"
: "${STATION_ENV:=prod}"
cd "$(dirname "$0")/.."
python3 ops/preflight.py || true
exec python3 -m uvicorn app.main:app --host 0.0.0.0 --port "$PORT"
