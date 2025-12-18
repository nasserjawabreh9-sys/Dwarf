from fastapi import APIRouter
from ...core.config import APP_NAME, APP_VERSION, ENV
from ...core.logging import now_iso

router = APIRouter()

@router.get("/info")
def info():
    return {
        "ok": True,
        "name": APP_NAME,
        "version": APP_VERSION,
        "env": ENV,
        "time_utc": now_iso(),
    }
