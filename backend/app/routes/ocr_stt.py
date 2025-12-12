import base64
from starlette.responses import JSONResponse
from starlette.requests import Request
from starlette.routing import Route

from app.settings_store import merged_keys
from app.guards import require_room

@require_room("core")
async def ocr_stub(request: Request):
  body = {}
  try:
    body = await request.json()
  except Exception:
    body = {}

  keys = merged_keys()
  ocr_key = (keys.get("ocr_key") or "").strip()

  # Accept either: {"image_b64": "..."} or {"text_hint":"..."}
  image_b64 = (body.get("image_b64") or "").strip()
  text_hint = (body.get("text_hint") or "").strip()

  meta = {"has_ocr_key": bool(ocr_key), "has_image_b64": bool(image_b64), "has_text_hint": bool(text_hint)}
  # We do not OCR locally here; this is a safe stub to wire later to provider.
  return JSONResponse({
    "ok": True,
    "mode": "stub",
    "meta": meta,
    "result": {
      "text": text_hint if text_hint else "",
      "confidence": 0.0,
      "provider": "stub"
    }
  })

@require_room("core")
async def stt_stub(request: Request):
  body = {}
  try:
    body = await request.json()
  except Exception:
    body = {}

  keys = merged_keys()
  tts_key = (keys.get("tts_key") or "").strip()  # reused slot; can be separate later

  # Accept: {"audio_b64":"..."} or {"text_hint":"..."}
  audio_b64 = (body.get("audio_b64") or "").strip()
  text_hint = (body.get("text_hint") or "").strip()

  meta = {"has_tts_key": bool(tts_key), "has_audio_b64": bool(audio_b64), "has_text_hint": bool(text_hint)}
  return JSONResponse({
    "ok": True,
    "mode": "stub",
    "meta": meta,
    "result": {
      "text": text_hint if text_hint else "",
      "confidence": 0.0,
      "provider": "stub"
    }
  })

routes = [
  Route("/api/ocr", ocr_stub, methods=["POST"]),
  Route("/api/stt", stt_stub, methods=["POST"]),
]
