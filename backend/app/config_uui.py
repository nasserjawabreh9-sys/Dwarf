import os, json
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[2]
UUI_STORE = ROOT_DIR / "station_meta" / "bindings" / "uui_config.json"

DEFAULT_KEYS = {
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

def read_uui_keys() -> dict:
    keys = dict(DEFAULT_KEYS)
    try:
        if UUI_STORE.exists():
            cfg = json.loads(UUI_STORE.read_text(encoding="utf-8"))
            got = (cfg.get("keys") or {})
            if isinstance(got, dict):
                keys.update(got)
    except Exception:
        pass

    # env overrides (optional)
    keys["edit_mode_key"] = (os.getenv("STATION_EDIT_KEY") or keys.get("edit_mode_key") or "1234").strip() or "1234"
    keys["webhooks_url"]  = (os.getenv("WEBHOOKS_URL") or keys.get("webhooks_url") or "").strip()
    keys["email_smtp"]    = (os.getenv("EMAIL_SMTP") or keys.get("email_smtp") or "").strip()
    keys["whatsapp_key"]  = (os.getenv("WHATSAPP_KEY") or keys.get("whatsapp_key") or "").strip()
    return keys

def expected_edit_key() -> str:
    k = (os.getenv("STATION_EDIT_KEY") or "").strip()
    if k:
        return k
    keys = read_uui_keys()
    return (keys.get("edit_mode_key") or "1234").strip() or "1234"
