#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ENV_FILE="${1:-$HOME/station_root/scripts/render_secrets.env}"
[ -f "$ENV_FILE" ] || { echo "Missing env file: $ENV_FILE"; exit 1; }
# shellcheck disable=SC1090
source "$ENV_FILE"
: "${RENDER_API_KEY:?missing}"
: "${RENDER_SERVICE_ID:?missing}"

curl -sS -H "Authorization: Bearer ${RENDER_API_KEY}" \
  "https://api.render.com/v1/services/${RENDER_SERVICE_ID}" | sed -n '1,260p'
