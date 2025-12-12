import os, json
from starlette.requests import Request
from starlette.responses import JSONResponse

ROOT_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "..")
)

CFG_PATH = os.path.join(
    ROOT_DIR, "station_meta", "bindings", "uui_config.json"
)

DEFAULT_CFG = {
    "keys": {
        "openai_api_key": "",
        "github_token": "",
        "tts_key": "",
        "webhooks_url": "",
        "ocr_key": "",
        "web_integration_key": "",
        "whatsapp_key": "",
        "email_smtp": "",
        "github_repo": "",
        "render_api_key": "",
        "edit_mode_key": "1234"
    }
}


def _ensure_file():
    os.makedirs(os.path.dirname(CFG_PATH), exist_ok=True)
    if not os.path.exists(CFG_PATH):
        with open(CFG_PATH, "w", encoding="utf-8") as f:
            json.dump(DEFAULT_CFG, f, indent=2)


async def get_uui_config(request: Request):
    _ensure_file()
    try:
        with open(CFG_PATH, "r", encoding="utf-8") as f:
            data = json.load(f)
        return JSONResponse(data)
    except Exception as e:
        return JSONResponse({"error": str(e)}, status_code=500)


async def post_uui_config(request: Request):
    _ensure_file()
    try:
        body = await request.json()
        keys = body.get("keys") or {}
        with open(CFG_PATH, "w", encoding="utf-8") as f:
            json.dump({"keys": keys}, f, indent=2)
        return JSONResponse({"ok": True})
    except Exception as e:
        return JSONResponse({"error": str(e)}, status_code=500)
