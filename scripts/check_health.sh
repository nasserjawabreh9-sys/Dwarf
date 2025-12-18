#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
URL="${1:-http://127.0.0.1:8000}"
echo "Checking: $URL/healthz"
curl -i "$URL/healthz"
echo ""
echo "OpenAPI: $URL/openapi.json"
curl -fsS "$URL/openapi.json" >/dev/null && echo "OK: openapi" || echo "FAIL: openapi"
