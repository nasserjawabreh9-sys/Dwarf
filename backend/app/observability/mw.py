import time, uuid
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware

class RequestIdMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        rid = request.headers.get("x-request-id") or str(uuid.uuid4())
        request.state.request_id = rid
        start = time.time()
        resp = await call_next(request)
        ms = int((time.time() - start) * 1000)
        resp.headers["x-request-id"] = rid
        resp.headers["x-response-ms"] = str(ms)
        return resp
