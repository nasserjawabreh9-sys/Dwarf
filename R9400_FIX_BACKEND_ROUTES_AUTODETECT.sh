#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
cd "$ROOT"

echo ">>> [R9400] Autodetect running ASGI file (Starlette + /health) and wire routes..."

# 1) Find the real running file (contains /health + Starlette)
TARGET="$(python - <<'PY'
import os, re
cands=[]
for base, _, files in os.walk("backend"):
    for fn in files:
        if fn.endswith(".py"):
            p=os.path.join(base, fn)
            try:
                t=open(p,"r",encoding="utf-8").read()
            except Exception:
                continue
            if ("/health" in t) and ("Starlette" in t or "starlette" in t):
                cands.append(p)
# prefer typical entry names
pref = ["backend/app/main.py","backend/app/app.py","backend/main.py","backend/server.py"]
for x in pref:
    if x in cands:
        print(x); raise SystemExit
print(cands[0] if cands else "")
PY
)"

if [ -z "${TARGET}" ]; then
  echo "!!! [R9400] Could not find ASGI file. Show backend tree:"
  find backend -maxdepth 3 -type f -name "*.py" | sed 's|^| - |'
  exit 1
fi

echo ">>> [R9400] TARGET = $TARGET"

# 2) Ensure our route modules exist (no overwrite of your existing ones)
mkdir -p backend/app/routes station_meta/bindings
touch backend/app/__init__.py backend/app/routes/__init__.py

# uui store + config route (if missing)
if [ ! -f backend/app/default_keys.py ]; then
cat > backend/app/default_keys.py <<'PY'
DEFAULT_KEYS = {
  "openai_api_key": "CHANGE_ME_OPENAI",
  "github_token": "CHANGE_ME_GITHUB",
  "tts_key": "CHANGE_ME_TTS",
  "webhooks_url": "",
  "ocr_key": "CHANGE_ME_OCR",
  "web_integration_key": "CHANGE_ME_WEB",
  "whatsapp_key": "CHANGE_ME_WHATSAPP",
  "email_smtp": "",
  "email_from": "",
  "email_to_default": "",
  "github_repo": "",
  "render_api_key": "CHANGE_ME_RENDER",
  "edit_mode_key": "1234"
}
PY
fi

if [ ! -f backend/app/uui_store.py ]; then
cat > backend/app/uui_store.py <<'PY'
import os, json
from pathlib import Path
from app.default_keys import DEFAULT_KEYS

ROOT_DIR = Path(__file__).resolve().parents[2]
STORE_PATH = ROOT_DIR / "station_meta" / "bindings" / "uui_config.json"

ENV_MAP = {
  "openai_api_key": ["STATION_OPENAI_API_KEY","OPENAI_API_KEY"],
  "github_token": ["GITHUB_TOKEN"],
  "tts_key": ["TTS_KEY"],
  "webhooks_url": ["WEBHOOKS_URL"],
  "ocr_key": ["OCR_KEY"],
  "web_integration_key": ["WEB_INTEGRATION_KEY"],
  "whatsapp_key": ["WHATSAPP_KEY","WHATSAPP_TOKEN"],
  "email_smtp": ["EMAIL_SMTP"],
  "email_from": ["EMAIL_FROM"],
  "render_api_key": ["RENDER_API_KEY"],
  "edit_mode_key": ["STATION_EDIT_KEY","EDIT_MODE_KEY"],
}

def _ensure_store():
  if STORE_PATH.exists(): return
  STORE_PATH.parent.mkdir(parents=True, exist_ok=True)
  STORE_PATH.write_text(json.dumps({"keys": DEFAULT_KEYS}, indent=2), encoding="utf-8")

def _read_store():
  if not STORE_PATH.exists(): return {}
  try:
    j=json.loads(STORE_PATH.read_text(encoding="utf-8"))
    k=j.get("keys") or {}
    return k if isinstance(k, dict) else {}
  except Exception:
    return {}

def merged_keys():
  _ensure_store()
  keys=dict(DEFAULT_KEYS)
  keys.update(_read_store())
  for k, envs in ENV_MAP.items():
    for env in envs:
      v=(os.getenv(env) or "").strip()
      if v:
        keys[k]=v
        break
  keys["edit_mode_key"]=(keys.get("edit_mode_key") or "1234").strip() or "1234"
  return keys

def write_store(new_keys: dict):
  _ensure_store()
  base=merged_keys()
  allow=set(DEFAULT_KEYS.keys())
  for k,v in (new_keys or {}).items():
    if k in allow:
      base[k] = "" if v is None else str(v)
  STORE_PATH.write_text(json.dumps({"keys": base}, indent=2), encoding="utf-8")
  return base

def expected_edit_key():
  return merged_keys().get("edit_mode_key","1234").strip() or "1234"
PY
fi

if [ ! -f backend/app/routes/uui_config.py ]; then
cat > backend/app/routes/uui_config.py <<'PY'
from starlette.responses import JSONResponse
from starlette.requests import Request
from starlette.routing import Route
from app.uui_store import merged_keys, write_store, expected_edit_key

def _auth_ok(request: Request) -> bool:
  got=(request.headers.get("X-Edit-Key") or "").strip()
  return got != "" and got == expected_edit_key()

async def get_config(request: Request):
  return JSONResponse({"ok": True, "keys": merged_keys()})

async def set_config(request: Request):
  if not _auth_ok(request):
    return JSONResponse({"ok": False, "error": "forbidden"}, status_code=403)
  body={}
  try: body=await request.json()
  except Exception: body={}
  keys=(body.get("keys") or {})
  merged=write_store(keys)
  return JSONResponse({"ok": True, "keys": merged})

routes = [
  Route("/api/config/uui", get_config, methods=["GET"]),
  Route("/api/config/uui", set_config, methods=["POST"]),
]
PY
fi

# senses + hooks modules (light stubs)
cat > backend/app/routes/senses.py <<'PY'
from starlette.responses import JSONResponse
from starlette.requests import Request
from starlette.routing import Route
from starlette.datastructures import UploadFile

async def sense_text(request: Request):
  data={}
  try: data=await request.json()
  except Exception: data={}
  return JSONResponse({"ok": True, "sense": "text", "input": data})

async def _upload_bytes(request: Request, field: str):
  form=await request.form()
  f: UploadFile|None = form.get(field)  # type: ignore
  b=await f.read() if f else b""
  return len(b)

async def sense_audio(request: Request):
  n=await _upload_bytes(request, "audio")
  return JSONResponse({"ok": True, "sense": "audio", "bytes": n})

async def sense_image(request: Request):
  n=await _upload_bytes(request, "image")
  return JSONResponse({"ok": True, "sense": "image", "bytes": n})

async def sense_video(request: Request):
  n=await _upload_bytes(request, "video")
  return JSONResponse({"ok": True, "sense": "video", "bytes": n})

routes = [
  Route("/api/senses/text", sense_text, methods=["POST"]),
  Route("/api/senses/audio", sense_audio, methods=["POST"]),
  Route("/api/senses/image", sense_image, methods=["POST"]),
  Route("/api/senses/video", sense_video, methods=["POST"]),
]
PY

cat > backend/app/routes/hooks.py <<'PY'
import requests
from starlette.responses import JSONResponse
from starlette.requests import Request
from starlette.routing import Route
from app.uui_store import expected_edit_key, merged_keys

def _auth_ok(request: Request) -> bool:
  got=(request.headers.get("X-Edit-Key") or "").strip()
  return got != "" and got == expected_edit_key()

async def hook_email(request: Request):
  if not _auth_ok(request):
    return JSONResponse({"ok": False, "error": "forbidden"}, status_code=403)
  payload={}
  try: payload=await request.json()
  except Exception: payload={}
  keys=merged_keys()
  return JSONResponse({"ok": True, "hook":"email", "smtp": bool(keys.get("email_smtp")), "payload": payload})

async def hook_whatsapp(request: Request):
  if not _auth_ok(request):
    return JSONResponse({"ok": False, "error": "forbidden"}, status_code=403)
  payload={}
  try: payload=await request.json()
  except Exception: payload={}
  keys=merged_keys()
  return JSONResponse({"ok": True, "hook":"whatsapp", "key": bool(keys.get("whatsapp_key")), "payload": payload})

async def hook_webhook(request: Request):
  if not _auth_ok(request):
    return JSONResponse({"ok": False, "error": "forbidden"}, status_code=403)
  payload={}
  try: payload=await request.json()
  except Exception: payload={}
  keys=merged_keys()
  url=(keys.get("webhooks_url") or "").strip()
  if not url:
    return JSONResponse({"ok": False, "hook":"webhook", "error":"webhooks_url_missing"}, status_code=400)
  try:
    r=requests.post(url, json=payload, timeout=8)
    return JSONResponse({"ok": True, "hook":"webhook", "status_code": r.status_code})
  except Exception as e:
    return JSONResponse({"ok": False, "hook":"webhook", "error": str(e)}, status_code=500)

routes = [
  Route("/api/hooks/email", hook_email, methods=["POST"]),
  Route("/api/hooks/whatsapp", hook_whatsapp, methods=["POST"]),
  Route("/api/hooks/webhook", hook_webhook, methods=["POST"]),
]
PY

# ensure store file exists (do not clobber if present)
if [ ! -f station_meta/bindings/uui_config.json ]; then
cat > station_meta/bindings/uui_config.json <<'JSON'
{"keys":{"openai_api_key":"","github_token":"","tts_key":"","webhooks_url":"","ocr_key":"","web_integration_key":"","whatsapp_key":"","email_smtp":"","email_from":"","email_to_default":"","github_repo":"","render_api_key":"","edit_mode_key":"1234"}}
JSON
fi

# deps
REQ="backend/requirements.txt"
grep -q "^python-multipart==" "$REQ" 2>/dev/null || echo "python-multipart==0.0.9" >> "$REQ"
grep -q "^requests==" "$REQ" 2>/dev/null || echo "requests==2.31.0" >> "$REQ"

# 3) Patch TARGET to mount *routes
python - <<PY
from pathlib import Path
import re
p=Path("$TARGET")
txt=p.read_text(encoding="utf-8")

# ensure imports once
def ensure_import(line):
  global txt
  if line not in txt:
    # place after Route import if possible
    m=re.search(r"from\s+starlette\.routing\s+import\s+Route.*", txt)
    if m:
      ins=m.group(0) + "\\n" + line
      txt=txt.replace(m.group(0), ins, 1)
    else:
      txt=line+"\\n"+txt

ensure_import("from app.routes import uui_config")
ensure_import("from app.routes import senses")
ensure_import("from app.routes import hooks")

# ensure routes list exists
if re.search(r"routes\\s*=\\s*\\[", txt) is None:
  raise SystemExit("TARGET has no routes=[...] list; open file and confirm structure: "+str(p))

def inject_once(marker, block):
  global txt
  if marker in txt:
    return
  txt=re.sub(r"routes\\s*=\\s*\\[", "routes = [\\n"+block, txt, count=1)

inject_once("/api/config/uui", "    *uui_config.routes,\\n")
inject_once("/api/senses/text", "    *senses.routes,\\n")
inject_once("/api/hooks/email", "    *hooks.routes,\\n")

p.write_text(txt, encoding="utf-8")
print("OK: Patched", p)
PY

echo ">>> [R9400] Install deps (backend venv) ..."
cd "$ROOT/backend"
source .venv/bin/activate
python -m pip install -r requirements.txt >/dev/null
echo ">>> [R9400] Restart Station ..."
cd "$ROOT"
./station_full_run.sh >/dev/null 2>&1 || true

echo ">>> [R9400] Quick verify:"
curl -sS http://127.0.0.1:8000/health && echo
curl -sS -X POST http://127.0.0.1:8000/api/senses/text -H "Content-Type: application/json" -d '{"text":"hi"}' && echo
curl -sS http://127.0.0.1:8000/api/config/uui | head -c 300 && echo
