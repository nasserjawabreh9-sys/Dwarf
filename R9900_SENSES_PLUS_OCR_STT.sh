#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
cd "$ROOT"

echo ">>> [R9900] Senses+ (OCR/STT endpoints with provider switch) ..."

mkdir -p backend/app/routes
touch backend/app/routes/__init__.py

cat > backend/app/routes/senses_plus.py <<'PY'
import os, base64, requests, time
from starlette.responses import JSONResponse
from starlette.requests import Request
from starlette.routing import Route
from starlette.datastructures import UploadFile
from app.uui_store import merged_keys

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

def mode(keys: dict) -> str:
    k = (os.getenv("STATION_OPENAI_API_KEY") or os.getenv("OPENAI_API_KEY") or keys.get("openai_api_key") or "").strip()
    return "online" if k and not k.startswith("CHANGE_ME") else "offline"

async def sense_ocr(request: Request):
    keys = merged_keys()
    m = mode(keys)
    form = await request.form()
    f: UploadFile | None = form.get("image")  # type: ignore
    b = await f.read() if f else b""
    if not b:
        return JSONResponse({"ok": False, "error": "missing_image"}, status_code=400)

    # If webhooks_url exists, forward bytes (base64) to user's integration
    url = (keys.get("webhooks_url") or "").strip()
    if url:
        payload = {"event":"senses_ocr", "ts": now_iso(), "mode": m, "b64": base64.b64encode(b).decode("ascii")[:200000]}
        try:
            r = requests.post(url, json=payload, timeout=15)
            return JSONResponse({"ok": True, "mode": m, "forwarded": True, "status_code": r.status_code})
        except Exception as e:
            return JSONResponse({"ok": False, "mode": m, "forwarded": False, "error": str(e)}, status_code=500)

    # Offline stub
    return JSONResponse({"ok": True, "mode": m, "note": "ocr_stub_no_webhook", "bytes": len(b)})

async def sense_stt(request: Request):
    keys = merged_keys()
    m = mode(keys)
    form = await request.form()
    f: UploadFile | None = form.get("audio")  # type: ignore
    b = await f.read() if f else b""
    if not b:
        return JSONResponse({"ok": False, "error": "missing_audio"}, status_code=400)

    url = (keys.get("webhooks_url") or "").strip()
    if url:
        payload = {"event":"senses_stt", "ts": now_iso(), "mode": m, "b64": base64.b64encode(b).decode("ascii")[:200000]}
        try:
            r = requests.post(url, json=payload, timeout=15)
            return JSONResponse({"ok": True, "mode": m, "forwarded": True, "status_code": r.status_code})
        except Exception as e:
            return JSONResponse({"ok": False, "mode": m, "forwarded": False, "error": str(e)}, status_code=500)

    return JSONResponse({"ok": True, "mode": m, "note": "stt_stub_no_webhook", "bytes": len(b)})

routes = [
    Route("/api/senses/ocr", sense_ocr, methods=["POST"]),
    Route("/api/senses/stt", sense_stt, methods=["POST"]),
]
PY

# Patch main.py
python - <<'PY'
from pathlib import Path
import re
p = Path("backend/app/main.py")
txt = p.read_text(encoding="utf-8")

def ensure_import(line: str):
    global txt
    if line in txt: return
    txt = txt.replace("from starlette.routing import Route",
                      "from starlette.routing import Route\n"+line, 1)

ensure_import("from app.routes import senses_plus")

if "/api/senses/ocr" not in txt:
    txt = re.sub(r"routes\s*=\s*\[", "routes = [\n    *senses_plus.routes,\n", txt, count=1)

p.write_text(txt, encoding="utf-8")
print("OK: main.py wired senses_plus.routes")
PY

REQ="backend/requirements.txt"
grep -q "^requests==" "$REQ" 2>/dev/null || echo "requests==2.31.0" >> "$REQ"

echo ">>> [R9900] DONE."
echo "Test (after restart):"
echo "  curl -sS -X POST http://127.0.0.1:8000/api/senses/ocr -F image=@/path/to/img.jpg"
echo "  curl -sS -X POST http://127.0.0.1:8000/api/senses/stt -F audio=@/path/to/a.wav"
