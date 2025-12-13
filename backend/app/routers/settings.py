from fastapi import APIRouter
from pydantic import BaseModel
from app.core.config import settings
from app.services.store import read_settings, write_settings

router = APIRouter(tags=["settings"])

SENSITIVE = {
    "openai_api_key","github_token","render_api_key","tts_key","ocr_key",
    "web_integration_key","whatsapp_key"
}

def mask(v: str) -> str:
    if not v:
        return ""
    if len(v) <= 8:
        return "****"
    return v[:4] + "..." + v[-4:]

class SettingsIn(BaseModel):
    openai_api_key: str | None = None
    github_token: str | None = None
    github_repo: str | None = None
    render_api_key: str | None = None
    render_service_id: str | None = None
    edit_mode_key: str | None = None

    webhooks_url: str | None = None
    tts_key: str | None = None
    ocr_key: str | None = None
    web_integration_key: str | None = None
    whatsapp_key: str | None = None
    email_smtp: str | None = None

@router.get("/api/settings")
def get_settings():
    data = read_settings(settings.station_root)
    masked = {}
    for k,v in data.items():
        if k in SENSITIVE and isinstance(v, str):
            masked[k] = mask(v)
        else:
            masked[k] = v
    return {"ok": True, "stored": masked, "has": {k: bool(data.get(k)) for k in data.keys()}}

@router.post("/api/settings")
def set_settings(payload: SettingsIn):
    current = read_settings(settings.station_root)
    d = payload.model_dump(exclude_none=True)
    current.update(d)
    write_settings(settings.station_root, current)
    return {"ok": True}
