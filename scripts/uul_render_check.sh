#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
API="${RENDER_API_KEY:-${1:-}}"
if [[ -z "$API" ]]; then
  echo "usage: RENDER_API_KEY=... uul_render_check.sh"
  exit 2
fi
curl -fsS "https://api.render.com/v1/services" -H "Authorization: Bearer $API" | head -c 2000
echo ""
