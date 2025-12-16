from fastapi import FastAPI
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
import os
import pathlib
import platform
from .security import ApiKeyGuardMiddleware, SimpleRateLimitMiddleware, SecurityHeadersMiddleware

APP_VERSION = os.environ.get("APP_VERSION", "1.0.0")
ENV_NAME = os.environ.get("ENV_NAME", "production")
STATION_API_KEY = os.environ.get("STATION_API_KEY", "")  # set in Render env
PROTECT_PREFIXES = tuple(
    p.strip() for p in os.environ.get("STATION_PROTECT_PREFIXES", "/ops,/admin,/api/ops").split(",") if p.strip()
)

RL_WINDOW_SEC = int(os.environ.get("RL_WINDOW_SEC", "60"))
RL_MAX_REQ = int(os.environ.get("RL_MAX_REQ", "240"))

ALLOWED_ORIGINS = [o.strip() for o in os.environ.get("CORS_ORIGINS", "*").split(",") if o.strip()]

ROOT_DIR = pathlib.Path(__file__).resolve().parents[2]
FRONT_DIST = ROOT_DIR / "frontend" / "dist"
FRONT_PUBLIC = ROOT_DIR / "frontend" / "public"

app = FastAPI(title="Station Enterprise", version=APP_VERSION)

# CORS (tighten later; '*' is okay for public docs + health)
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS if ALLOWED_ORIGINS != ["*"] else ["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

# Enterprise middlewares
app.add_middleware(SecurityHeadersMiddleware)
app.add_middleware(SimpleRateLimitMiddleware, window_sec=RL_WINDOW_SEC, max_req=RL_MAX_REQ)
app.add_middleware(ApiKeyGuardMiddleware, api_key=STATION_API_KEY, prefixes=PROTECT_PREFIXES)

@app.get("/healthz")
def healthz():
    return {"ok": True, "service": "station", "env": ENV_NAME, "version": APP_VERSION}

@app.get("/version")
def version():
    return {"version": APP_VERSION}

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

@app.get("/", response_class=HTMLResponse)
def root():
    if FRONT_DIST.exists() and (FRONT_DIST / "index.html").exists():
        return (FRONT_DIST / "index.html").read_text(encoding="utf-8", errors="ignore")
    if FRONT_PUBLIC.exists() and (FRONT_PUBLIC / "index.html").exists():
        return (FRONT_PUBLIC / "index.html").read_text(encoding="utf-8", errors="ignore")
    return HTMLResponse(
        "<h1>Station Enterprise</h1><p>OK</p><ul>"
        "<li><a href='/docs'>/docs</a></li>"
        "<li><a href='/healthz'>/healthz</a></li>"
        "<li><a href='/info'>/info</a></li>"
        "</ul>",
        status_code=200,
    )

# --- Enterprise Ops Endpoints ---

from fastapi.responses import JSONResponse

@app.get("/api/ops/ping")
def ops_ping():
    return {"ok": True, "ops": "pong"}

@app.get("/ops", response_class=HTMLResponse)
def ops_page():
    return HTMLResponse(
        "<h2>Ops (Protected)</h2>"
        "<p>Try: <code>/api/ops/ping</code> with X-API-Key.</p>"
        "<p>Status: OK</p>",
        status_code=200,
    )
