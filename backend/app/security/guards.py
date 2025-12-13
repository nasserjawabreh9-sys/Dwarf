import time
from fastapi import Request, HTTPException
from app.core.config import settings

# very light in-memory rate limiter by client ip
_BUCKET = {}

def body_size_guard(request: Request):
    cl = request.headers.get("content-length")
    if not cl:
        return
    try:
        n = int(cl)
    except ValueError:
        return
    if n > settings.max_body_kb * 1024:
        raise HTTPException(status_code=413, detail="payload too large")

def rate_limit_guard(request: Request):
    ip = request.client.host if request.client else "unknown"
    now = int(time.time())
    key = (ip, now // 60)
    _BUCKET[key] = _BUCKET.get(key, 0) + 1
    if _BUCKET[key] > settings.rate_limit_rpm:
        raise HTTPException(status_code=429, detail="rate limit exceeded")
