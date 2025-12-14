#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# مطلوب: حط مفتاح Render API هنا أو بالبيئة
: "${RENDER_API_KEY:?Set RENDER_API_KEY first (export RENDER_API_KEY=...)}"

API="https://api.render.com/v1"
AUTH="Authorization: Bearer ${RENDER_API_KEY}"

cmd="${1:-help}"

list_services() {
  curl -fsS -H "$AUTH" "$API/services" | python -m json.tool
}

# فلترة سريعة بالاسم (اختياري)
find_service() {
  local q="${1:?usage: find <substring>}"
  curl -fsS -H "$AUTH" "$API/services" \
    | python - <<'PY' "$q"
import sys, json
q=sys.argv[1].lower()
data=json.load(sys.stdin)
hits=[]
for s in data:
    name=(s.get("name") or "").lower()
    sid=s.get("id")
    stype=s.get("type")
    if q in name:
        hits.append({"name":s.get("name"),"id":sid,"type":stype})
print(json.dumps(hits, indent=2))
PY
}

# Trigger deploy: POST /services/{serviceId}/deploys
deploy() {
  local service_id="${1:?usage: deploy <serviceId>}"
  curl -fsS -X POST -H "$AUTH" -H "Content-Type: application/json" \
    "$API/services/${service_id}/deploys" \
    -d '{}' | python -m json.tool
}

# معلومات خدمة (استخدمها لتتأكد من الـ URL/النوع)
get_service() {
  local service_id="${1:?usage: get <serviceId>}"
  curl -fsS -H "$AUTH" "$API/services/${service_id}" | python -m json.tool
}

case "$cmd" in
  list) list_services ;;
  find) find_service "${2:-}" ;;
  get)  get_service "${2:-}" ;;
  deploy) deploy "${2:-}" ;;
  help|*) echo "Usage:
  export RENDER_API_KEY='...'
  bash RENDER_CONTROL.sh list
  bash RENDER_CONTROL.sh find dwarf
  bash RENDER_CONTROL.sh get <serviceId>
  bash RENDER_CONTROL.sh deploy <serviceId>
" ;;
esac
