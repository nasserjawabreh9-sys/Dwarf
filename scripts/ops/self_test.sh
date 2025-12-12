#!/data/data/com.termux/files/usr/bin/bash
set -e
KEY="${STATION_EDIT_KEY:-1234}"

echo "== Health =="
curl -s http://127.0.0.1:8000/health || true

echo "== Config GET =="
curl -s http://127.0.0.1:8000/api/config/uui || true

echo "== Git Status (Ops) =="
curl -s -H "X-Edit-Key: $KEY" http://127.0.0.1:8000/api/ops/git/status || true

echo "Self-test done."
