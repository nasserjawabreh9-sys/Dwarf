from fastapi import FastAPI
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
import os
import platform
from .security import ApiKeyGuardMiddleware, SimpleRateLimitMiddleware, SecurityHeadersMiddleware

APP_VERSION = os.environ.get("APP_VERSION", "1.0.0")
ENV_NAME = os.environ.get("ENV_NAME", "production")

STATION_API_KEY = os.environ.get("STATION_API_KEY", "")
PROTECT_PREFIXES = tuple(
    p.strip() for p in os.environ.get("STATION_PROTECT_PREFIXES", "/ops,/admin,/api/ops").split(",") if p.strip()
)

RL_WINDOW_SEC = int(os.environ.get("RL_WINDOW_SEC", "60"))
RL_MAX_REQ = int(os.environ.get("RL_MAX_REQ", "240"))
CORS_ORIGINS = [o.strip() for o in os.environ.get("CORS_ORIGINS", "*").split(",") if o.strip()]

BUILD_FINGERPRINT = os.environ.get("BUILD_FINGERPRINT", "fp-local")

app = FastAPI(title="Station Enterprise", version=APP_VERSION)

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS if CORS_ORIGINS != ["*"] else ["*"],
    allow_credentials=False,
    allow_methods=["GET","POST","PUT","PATCH","DELETE","OPTIONS"],
    allow_headers=["*"],
)

app.add_middleware(SecurityHeadersMiddleware)
app.add_middleware(SimpleRateLimitMiddleware, window_sec=RL_WINDOW_SEC, max_req=RL_MAX_REQ)
app.add_middleware(ApiKeyGuardMiddleware, api_key=STATION_API_KEY, prefixes=PROTECT_PREFIXES)

@app.get("/healthz")
def healthz():
    return {"ok": True, "service":"station", "env": ENV_NAME, "version": APP_VERSION}

@app.get("/info")
def info():
    return {
        "env": ENV_NAME,
        "version": APP_VERSION,
        "python": platform.python_version(),
        "platform": platform.platform(),
        "protected_prefixes": list(PROTECT_PREFIXES),
        "rate_limit": {"window_sec": RL_WINDOW_SEC, "max_req": RL_MAX_REQ},
    }

@app.get("/build_fingerprint")
def build_fingerprint():
    return {"fingerprint": BUILD_FINGERPRINT}

# --- Ops (Protected) ---
@app.get("/api/ops/ping")
def ops_ping():
    return {"ok": True, "ops": "pong"}

@app.get("/ops", response_class=HTMLResponse)
def ops_page():
    return HTMLResponse("<h2>Ops (Protected)</h2><p>Use X-API-Key for /api/ops/ping</p>", status_code=200)

@app.get("/", response_class=HTMLResponse)
def root():
    return HTMLResponse(
        "<h1>Station Enterprise</h1>"
        "<ul>"
        "<li><a href='/docs'>/docs</a></li>"
        "<li><a href='/healthz'>/healthz</a></li>"
        "<li><a href='/info'>/info</a></li>"
        "<li><a href='/build_fingerprint'>/build_fingerprint</a></li>"
        "<li><a href='/ops'>/ops</a></li>"
        "</ul>"
    )

# -----------------------------
# Database Health Check
# -----------------------------
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine
import os

_db_engine = None

def get_db_engine():
    global _db_engine
    if _db_engine is None:
        url = os.environ.get("DATABASE_URL")
        if not url:
            raise RuntimeError("DATABASE_URL not set")
        _db_engine = create_async_engine(url, pool_pre_ping=True)
    return _db_engine

@app.get("/db/health")
async def db_health():
    try:
        engine = get_db_engine()
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        return {"db": "ok"}
    except Exception as e:
        return {"db": "fail", "error": str(e)}
