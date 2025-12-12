import time
from collections import defaultdict
from starlette.requests import Request

# simple in-memory rate limit (per IP)
_BUCKET = defaultdict(list)
WINDOW = 5.0     # seconds
MAX_REQ = 20

def rate_limit_ok(request: Request) -> bool:
    ip = request.client.host if request.client else "local"
    now = time.time()
    q = _BUCKET[ip]
    q[:] = [t for t in q if now - t < WINDOW]
    if len(q) >= MAX_REQ:
        return False
    q.append(now)
    return True

def require_room(room: str):
    from app.rooms import acquire_room, release_room
    def decorator(fn):
        async def wrapper(request: Request, *a, **kw):
            if not rate_limit_ok(request):
                return {"ok": False, "error": "rate_limited"}
            if not acquire_room(room):
                return {"ok": False, "error": "room_busy", "room": room}
            try:
                return await fn(request, *a, **kw)
            finally:
                release_room(room)
        return wrapper
    return decorator
