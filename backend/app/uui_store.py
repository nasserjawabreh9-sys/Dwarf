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
