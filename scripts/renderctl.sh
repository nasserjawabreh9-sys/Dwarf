#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

: "${RENDER_API_KEY:?Set RENDER_API_KEY first}"

API="https://api.render.com/v1"
AUTH="Authorization: Bearer ${RENDER_API_KEY}"

cmd="${1:-help}"

list() {
  curl -fsS -H "$AUTH" "$API/services" | python -m json.tool
}

find() {
  q="${2:-}"
  curl -fsS -H "$AUTH" "$API/services" \
  | python - <<'PY' "$q"
import sys, json
q=sys.argv[1].lower()
data=json.load(sys.stdin)
out=[]
for s in data:
    name=(s.get("name") or "")
    if q in name.lower():
        out.append({"name":name,"id":s.get("id"),"type":s.get("type"),"url":s.get("serviceDetails",{}).get("url")})
print(json.dumps(out, indent=2))
PY
}

get() {
  curl -fsS -H "$AUTH" "$API/services/${2:?serviceId}" | python -m json.tool
}

deploy() {
  curl -fsS -X POST -H "$AUTH" -H "Content-Type: application/json" \
    "$API/services/${2:?serviceId}/deploys" -d '{}' | python -m json.tool
}

case "$cmd" in
  list) list ;;
  find) find "$@" ;;
  get) get "$@" ;;
  deploy) deploy "$@" ;;
  *) echo "Usage:
  renderctl.sh list
  renderctl.sh find dwarf
  renderctl.sh get <serviceId>
  renderctl.sh deploy <serviceId>"
esac
