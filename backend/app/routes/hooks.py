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
