#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
cd "$ROOT"

echo ">>> [R9300] Backend Defaults + Store + UI Sync (uui_config) @ $ROOT"

mkdir -p backend/app station_meta/bindings
touch backend/app/__init__.py

# ---------------------------------------------------
# 1) Truth defaults in backend (single source of truth)
# ---------------------------------------------------
cat > backend/app/default_keys.py <<'PY'
# English-only file (UUL rule)
DEFAULT_KEYS = {
    "openai_api_key": "CHANGE_ME_OPENAI",
    "github_token": "CHANGE_ME_GITHUB",
    "tts_key": "CHANGE_ME_TTS",
    "webhooks_url": "http://127.0.0.1:9009/webhook",
    "ocr_key": "CHANGE_ME_OCR",
    "web_integration_key": "CHANGE_ME_WEB",
    "whatsapp_key": "CHANGE_ME_WHATSAPP",
    "email_smtp": "smtp://user:pass@smtp.example.com:587",
    "email_from": "station@example.com",
    "email_to_default": "ops@example.com",
    "github_repo": "owner/repo",
    "render_api_key": "CHANGE_ME_RENDER",
    "edit_mode_key": "1234"
}
PY

# ---------------------------------------------------
# 2) Backend store manager: defaults <- stored <- env
# ---------------------------------------------------
cat > backend/app/uui_store.py <<'PY'
import os, json
from pathlib import Path
from app.default_keys import DEFAULT_KEYS

ROOT_DIR = Path(__file__).resolve().parents[2]
STORE_PATH = ROOT_DIR / "station_meta" / "bindings" / "uui_config.json"

ENV_MAP = {
    "openai_api_key": ["STATION_OPENAI_API_KEY", "OPENAI_API_KEY"],
    "github_token": ["GITHUB_TOKEN"],
    "tts_key": ["TTS_KEY"],
    "webhooks_url": ["WEBHOOKS_URL"],
    "ocr_key": ["OCR_KEY"],
    "web_integration_key": ["WEB_INTEGRATION_KEY"],
    "whatsapp_key": ["WHATSAPP_KEY", "WHATSAPP_TOKEN"],
    "email_smtp": ["EMAIL_SMTP"],
    "email_from": ["EMAIL_FROM"],
    "render_api_key": ["RENDER_API_KEY"],
    "edit_mode_key": ["STATION_EDIT_KEY", "EDIT_MODE_KEY"],
}

def _read_store() -> dict:
    if not STORE_PATH.exists():
        return {}
    try:
        j = json.loads(STORE_PATH.read_text(encoding="utf-8"))
        keys = (j.get("keys") or {})
        return keys if isinstance(keys, dict) else {}
    except Exception:
        return {}

def _ensure_store_exists():
    if STORE_PATH.exists():
        return
    STORE_PATH.parent.mkdir(parents=True, exist_ok=True)
    STORE_PATH.write_text(json.dumps({"keys": DEFAULT_KEYS}, ensure_ascii=False, indent=2), encoding="utf-8")

def merged_keys() -> dict:
    _ensure_store_exists()
    keys = dict(DEFAULT_KEYS)

    # stored overrides defaults
    stored = _read_store()
    keys.update({k: v for k, v in stored.items() if v is not None})

    # env overrides stored
    for k, envs in ENV_MAP.items():
        for env in envs:
            val = (os.getenv(env) or "").strip()
            if val:
                keys[k] = val
                break

    # guarantee edit_mode_key always exists
    keys["edit_mode_key"] = (keys.get("edit_mode_key") or "1234").strip() or "1234"
    return keys

def write_store(new_keys: dict) -> dict:
    _ensure_store_exists()
    base = merged_keys()

    # only allow known keys
    allowed = set(DEFAULT_KEYS.keys())
    sanitized = {}
    for k, v in (new_keys or {}).items():
        if k in allowed:
            sanitized[k] = "" if v is None else str(v)

    merged = dict(base)
    merged.update(sanitized)

    STORE_PATH.parent.mkdir(parents=True, exist_ok=True)
    STORE_PATH.write_text(json.dumps({"keys": merged}, ensure_ascii=False, indent=2), encoding="utf-8")
    return merged

def expected_edit_key() -> str:
    return merged_keys().get("edit_mode_key", "1234").strip() or "1234"
PY

# ---------------------------------------------------
# 3) Backend route: GET/POST /api/config/uui
#    - GET returns merged keys (defaults+store+env)
#    - POST writes store (protected by X-Edit-Key)
# ---------------------------------------------------
mkdir -p backend/app/routes
touch backend/app/routes/__init__.py

cat > backend/app/routes/uui_config.py <<'PY'
from starlette.responses import JSONResponse
from starlette.requests import Request
from starlette.routing import Route
from app.uui_store import merged_keys, write_store, expected_edit_key

def _auth_ok(request: Request) -> bool:
    got = (request.headers.get("X-Edit-Key") or "").strip()
    return got != "" and got == expected_edit_key()

async def get_config(request: Request):
    return JSONResponse({"ok": True, "keys": merged_keys()})

async def set_config(request: Request):
    if not _auth_ok(request):
        return JSONResponse({"ok": False, "error": "forbidden"}, status_code=403)

    body = {}
    try:
        body = await request.json()
    except Exception:
        body = {}

    keys = (body.get("keys") or {})
    merged = write_store(keys)
    return JSONResponse({"ok": True, "keys": merged})

routes = [
    Route("/api/config/uui", get_config, methods=["GET"]),
    Route("/api/config/uui", set_config, methods=["POST"]),
]
PY

# ---------------------------------------------------
# 4) Patch backend/app/main.py to include uui_config.routes
# ---------------------------------------------------
python - <<'PY'
from pathlib import Path
import re

p = Path("backend/app/main.py")
txt = p.read_text(encoding="utf-8")

if "from app.routes import uui_config" not in txt:
    txt = txt.replace(
        "from starlette.routing import Route",
        "from starlette.routing import Route\nfrom app.routes import uui_config"
    )

if "/api/config/uui" not in txt:
    # insert into routes list
    txt = re.sub(r"routes\s*=\s*\[", "routes = [\n    *uui_config.routes,\n", txt, count=1)

p.write_text(txt, encoding="utf-8")
print("OK: main.py wired uui_config.routes")
PY

# ---------------------------------------------------
# 5) Frontend: ensure "Save to Backend" uses /api/config/uui
#    and sends X-Edit-Key header (edit_mode_key)
#    (We patch lightly; do not rewrite whole file.)
# ---------------------------------------------------
python - <<'PY'
from pathlib import Path
import re

p = Path("frontend/src/pages/Settings.tsx")
txt = p.read_text(encoding="utf-8")

# Ensure saveToBackend hits /api/config/uui
txt = re.sub(r'fetch\("(/api/config/uui|/api/config/uui/?)"', 'fetch("/api/config/uui"', txt)

# Ensure header key name matches backend expectation "X-Edit-Key"
# If file uses X-Edit-Key already, fine. If it uses X-EDIT-KEY, normalize to X-Edit-Key.
txt = txt.replace('"X-EDIT-KEY"', '"X-Edit-Key"')

p.write_text(txt, encoding="utf-8")
print("OK: Settings.tsx normalized Save-> /api/config/uui + X-Edit-Key")
PY

# ---------------------------------------------------
# 6) Verification helper
# ---------------------------------------------------
cat > scripts/ops/verify_uui_defaults_and_store.sh <<'EOF'
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
EOF
chmod +x scripts/ops/verify_uui_defaults_and_store.sh

echo ">>> [R9300] DONE."
echo "Next:"
echo "  1) cd $ROOT/backend && source .venv/bin/activate && python -m pip install -r requirements.txt"
echo "  2) cd $ROOT && ./station_full_run.sh"
echo "  3) bash scripts/ops/verify_uui_defaults_and_store.sh"
echo "  4) UI: Settings -> Save to Backend (will override defaults in backend store)"
