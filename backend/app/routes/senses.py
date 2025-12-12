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
