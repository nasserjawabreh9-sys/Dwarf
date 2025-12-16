import os
import time
from typing import Callable, Dict, Tuple, Optional
from fastapi import Request, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response

def _now() -> float:
    return time.time()

class ApiKeyGuardMiddleware(BaseHTTPMiddleware):
    """
    Protect selected path prefixes with X-API-Key.
    Configure:
      STATION_API_KEY (required for protected routes)
      STATION_PROTECT_PREFIXES="/ops,/admin,/api/ops"  (comma-separated)
    """
    def __init__(self, app, api_key: str, prefixes: Tuple[str, ...]):
        super().__init__(app)
        self.api_key = api_key
        self.prefixes = prefixes

    async def dispatch(self, request: Request, call_next: Callable):
        path = request.url.path or "/"
        if self.api_key and any(path.startswith(p) for p in self.prefixes):
            got = request.headers.get("x-api-key") or request.headers.get("X-API-Key")
            if got != self.api_key:
                raise HTTPException(status_code=401, detail="Unauthorized")
        return await call_next(request)

class SimpleRateLimitMiddleware(BaseHTTPMiddleware):
    """
    Naive in-memory sliding window rate limit per client IP.
    Configure:
      RL_WINDOW_SEC=60
      RL_MAX_REQ=240
    Notes: Suitable for small/medium workloads; for heavy traffic use a real gateway/WAF.
    """
    def __init__(self, app, window_sec: int, max_req: int):
        super().__init__(app)
        self.window_sec = max(5, window_sec)
        self.max_req = max(30, max_req)
        self._buckets: Dict[str, Tuple[float, int]] = {}

    def _client_ip(self, request: Request) -> str:
        # Render/Proxies: use X-Forwarded-For first
        xff = request.headers.get("x-forwarded-for")
        if xff:
            return xff.split(",")[0].strip()
        client = request.client.host if request.client else "unknown"
        return client

    async def dispatch(self, request: Request, call_next: Callable):
        ip = self._client_ip(request)
        t = _now()
        start, cnt = self._buckets.get(ip, (t, 0))
        if t - start > self.window_sec:
            start, cnt = t, 0
        cnt += 1
        self._buckets[ip] = (start, cnt)
        if cnt > self.max_req:
            return Response("Too Many Requests", status_code=429)
        return await call_next(request)

class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: Callable):
        resp: Response = await call_next(request)
        resp.headers.setdefault("X-Content-Type-Options", "nosniff")
        resp.headers.setdefault("X-Frame-Options", "DENY")
        resp.headers.setdefault("Referrer-Policy", "no-referrer")
        resp.headers.setdefault("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
        # Basic CSP (safe default; relax later if you embed external assets)
        resp.headers.setdefault("Content-Security-Policy", "default-src 'self'; frame-ancestors 'none'; base-uri 'self'")
        return resp
