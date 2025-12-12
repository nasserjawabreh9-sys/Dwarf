from starlette.responses import JSONResponse
from starlette.requests import Request
from starlette.routing import Route
from app.uui_store import merged_keys, write_store, expected_edit_key

# MASK_SENSITIVE_KEYS__R9600
SENSITIVE_KEYS = {
  "openai_api_key",
  "github_token",
  "render_api_key",
  "whatsapp_key",
  "web_integration_key",
  "ocr_key",
  "tts_key",
  "email_smtp"
}

def _mask_value(v: str) -> str:
  s = ("" if v is None else str(v))
  if not s:
    return ""
  if len(s) <= 4:
    return "****"
  return "****" + s[-4:]

def masked_keys(keys: dict) -> dict:
  out = {}
  for k, v in (keys or {}).items():
    if k in SENSITIVE_KEYS:
      out[k] = _mask_value(v)
    else:
      out[k] = v
  return out


def _auth_ok(request: Request) -> bool:
    got = (request.headers.get("X-Edit-Key") or "").strip()
    return got != "" and got == expected_edit_key()

async def get_config(request: Request):
    return JSONResponse({"ok": True, "keys": masked_keys(merged_keys())})
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
