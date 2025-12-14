#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

echo ">>> Killing uvicorn on ports 8000/8010 (best effort)"
pkill -f "uvicorn.*--port 8000" >/dev/null 2>&1 || true
pkill -f "uvicorn.*--port 8010" >/dev/null 2>&1 || true
pkill -f "python.*uvicorn.*--port 8000" >/dev/null 2>&1 || true
pkill -f "python.*uvicorn.*--port 8010" >/dev/null 2>&1 || true

echo ">>> Remaining uvicorn processes (if any):"
ps -ef | grep -E "uvicorn|python.*app\.main" | grep -v grep || true
echo "DONE"
