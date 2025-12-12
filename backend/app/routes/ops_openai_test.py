import os, json
import urllib.request
from starlette.requests import Request
from starlette.responses import JSONResponse

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
UUI_STORE = os.path.join(ROOT_DIR, "station_meta", "bindings", "uui_config.json")

def _read_uui_keys():
    try:
        with open(UUI_STORE, "r", encoding="utf-8") as f:
            cfg = json.load(f)
        return (cfg.get("keys") or {})
    except Exception:
        return {}

def _auth_ok(request: Request) -> bool:
    # reuse same edit-mode gate as ops_git: header X-Edit-Key
    got = (request.headers.get("X-Edit-Key") or "").strip()
    envk = (os.getenv("STATION_EDIT_KEY") or "").strip()
    if envk:
        return got != "" and got == envk
    k = (_read_uui_keys().get("edit_mode_key") or "").strip() or "1234"
    return got != "" and got == k

def _pick_api_key(body: dict) -> str:
    # Priority: explicit api_key in request -> stored uui_config -> env
    k = (body.get("api_key") or "").strip()
    if k:
        return k
    keys = _read_uui_keys()
    k = (keys.get("openai_api_key") or "").strip()
    if k:
        return k
    return (os.getenv("OPENAI_API_KEY") or os.getenv("STATION_OPENAI_API_KEY") or "").strip()

async def openai_test(request: Request):
    if not _auth_ok(request):
        return JSONResponse({"error": "forbidden"}, status_code=403)

    try:
        body = await request.json()
    except Exception:
        body = {}

    api_key = _pick_api_key(body)
    if not api_key:
        return JSONResponse({"ok": False, "error": "missing_api_key"}, status_code=400)

    # Minimal, safe test: list models (works if key is valid)
    req = urllib.request.Request(
        "https://api.openai.com/v1/models",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="GET",
    )

    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
        data = json.loads(raw)
        items = data.get("data") or []
        sample = [m.get("id") for m in items[:8] if isinstance(m, dict)]
        return JSONResponse({
            "ok": True,
            "models_count": len(items),
            "models_sample": sample
        })
    except Exception as e:
        return JSONResponse({"ok": False, "error": str(e)}, status_code=502)
