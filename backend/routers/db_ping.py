from fastapi import APIRouter, HTTPException
from backend.db import ping

router = APIRouter(prefix="/db", tags=["db"])

@router.get("/ping")
def db_ping():
    try:
        return ping()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"db_ping_failed: {e}")
