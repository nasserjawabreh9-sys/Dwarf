#!/usr/bin/env bash
set -e
PORT="${PORT:-8000}"
exec uvicorn backend.asgi:app --host 0.0.0.0 --port "$PORT"
