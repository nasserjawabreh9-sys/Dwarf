from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware

from .core.config import APP_NAME, APP_VERSION, ALLOW_ORIGINS, RATE_LIMIT_RPM
from .core.logging import setup_logging, now_iso
from .core.rate_limit import SimpleRateLimiter
from .api.v1.router import router as v1_router

setup_logging()
rate = SimpleRateLimiter(rpm=RATE_LIMIT_RPM)

app = FastAPI(title=APP_NAME, version=APP_VERSION)

# CORS lock
allow_origins = ["*"] if ALLOW_ORIGINS == ["*"] else ALLOW_ORIGINS

app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.middleware("http")
async def security_and_rate_mw(request: Request, call_next):
    ip = request.headers.get("x-forwarded-for", request.client.host if request.client else "unknown")
    ip = ip.split(",")[0].strip()

    if not rate.allow(ip):
        return JSONResponse(status_code=429, content={"ok": False, "detail": "rate_limited", "time_utc": now_iso()})

    response = await call_next(request)

    # Security headers (safe defaults)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Permissions-Policy"] = "geolocation=(), microphone=(), camera=()"
    # If you later serve frontend from same domain with HTTPS, you can enable HSTS:
    # response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"

    return response

@app.get("/")
def root():
    return {"ok": True, "service": "dwarf", "version": APP_VERSION, "time_utc": now_iso()}

@app.get("/healthz")
def healthz():
    return {"ok": True, "status": "healthy", "time_utc": now_iso()}

app.include_router(v1_router)
