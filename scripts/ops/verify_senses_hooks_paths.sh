#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

echo "=== BACKEND URL ==="
echo "http://127.0.0.1:8000"

echo
echo "=== HEALTH ==="
curl -sS http://127.0.0.1:8000/health && echo

echo
echo "=== SENSE TEXT (POST /api/senses/text) ==="
curl -sS -X POST http://127.0.0.1:8000/api/senses/text \
  -H "Content-Type: application/json" \
  -d '{"text":"hello"}' && echo

echo
echo "=== HOOK EMAIL (POST /api/hooks/email) - requires X-Edit-Key ==="
KEY="$(python - <<'PY'
import json, os
p=os.path.expanduser("~/station_root/station_meta/bindings/uui_config.json")
k="1234"
try:
  j=json.load(open(p,"r",encoding="utf-8"))
  k=((j.get("keys") or {}).get("edit_mode_key") or "1234").strip() or "1234"
except Exception:
  pass
print(k)
PY
)"
curl -sS -X POST http://127.0.0.1:8000/api/hooks/email \
  -H "Content-Type: application/json" \
  -H "X-Edit-Key: $KEY" \
  -d '{"to":"x@y.com","subject":"t","body":"b"}' && echo
