import os
import datetime
from fastapi import FastAPI
from app.routers.status import router as status_router
from fastapi.middleware.cors import CORSMiddleware

# Routers (best-effort imports; safe if some modules differ)
try:
    from app.routes import (
        settings,
        uui_config,
        console,
        ops_git,
        ops_openai_test,
        ops_run_cmd,
        ops_exec,
        hooks,
        senses,
        senses_plus,
        ocr_stt,
        loop,
        dynamo,
        agent,
    )
except Exception:
    # Minimal fallback: only settings if exists
    settings = None
    uui_config = None
    console = None
    ops_git = None
    ops_openai_test = None
    ops_run_cmd = None
    ops_exec = None
    hooks = None
    senses = None
    senses_plus = None
    ocr_stt = None
    loop = None
    dynamo = None
    agent = None

app = FastAPI(
    title="Station Backend",
    version="1.0.0",
    openapi_url="/openapi.json",
    docs_url="/docs",
    redoc_url="/redoc",
)



@app.get("/api/status")
def api_status():
    """
    Lightweight runtime truth endpoint (no auth).
    Used by UUI and scripts to avoid "echo" states.
    """
    port = os.environ.get("PORT", "")
    station_env = os.environ.get("STATION_ENV", "")
    edit_key_set = bool(os.environ.get("STATION_EDIT_KEY", ""))

    # best-effort: read simple signals if files exist
    root = os.environ.get("STATION_ROOT", "")
    return {
        "ok": True,
        "service": "station-backend",
        "time_utc": datetime.datetime.utcnow().isoformat() + "Z",
        "port_env": port,
        "station_env": station_env,
        "edit_key_set": edit_key_set,
        "root_env": root,
    }
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def root():
    return {
        "ok": True,
        "service": "station-backend",
        "hint": "Use /docs or /openapi.json",
    }

# Normalize health endpoints
@app.get("/healthz")
def healthz():
    return {"ok": True}

# If there is already a /health in other module, keep this simple one as well.
@app.get("/health")
def health():
    return {"ok": True}

def _include(r):
    if r is None:
        return
    try:
        app.include_router(r.router)
    except Exception:
        pass

# Mount all known routers (best-effort)
for r in [
    settings,
    uui_config,
    console,
    ops_git,
    ops_openai_test,
    ops_run_cmd,
    ops_exec,
    hooks,
    senses,
    senses_plus,
    ocr_stt,
    loop,
    dynamo,
    agent,
]:
    _include(r)


# --- Station: Status API ---
app.include_router(status_router)
