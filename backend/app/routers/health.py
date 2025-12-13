from fastapi import APIRouter

router = APIRouter(tags=["health"])

@router.get("/healthz")
def healthz():
    return {"ok": True}

@router.get("/info")
def info():
    return {"name": "Station", "ok": True, "version": "2.0.0-global"}
