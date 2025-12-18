from fastapi import APIRouter
from .db_core import db_health

router = APIRouter(prefix="/db", tags=["db"])

@router.get("/healthz")
def healthz():
    return db_health()

@router.get("/probe")
def probe():
    return db_health()
