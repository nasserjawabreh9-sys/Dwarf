#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
cd "$ROOT"

echo "=== GET merged keys (should include defaults) ==="
curl -sS http://127.0.0.1:8000/api/config/uui | head -c 800 && echo
echo

EDIT_KEY="$(python - <<'PY'
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

echo "=== POST write store (test override webhooks_url) ==="
curl -sS -X POST http://127.0.0.1:8000/api/config/uui \
  -H "Content-Type: application/json" \
  -H "X-Edit-Key: $EDIT_KEY" \
  -d '{"keys":{"webhooks_url":"http://127.0.0.1:9999/new_webhook"}}' | head -c 800 && echo
echo

echo "=== GET again (should reflect new stored value) ==="
curl -sS http://127.0.0.1:8000/api/config/uui | head -c 800 && echo
