from app.main import app

# --- DWARF_IDENTITY_LOCK_BEGIN ---
import os, platform, time
from datetime import datetime

_DWARF_BOOT_TS = time.time()

def _dwarf_env(key: str, default: str = "") -> str:
    v = os.environ.get(key, default)
    return v if v is not None else default

DWARF_NAME = _dwarf_env("DWARF_NAME", "Dwarf")
DWARF_ENV  = _dwarf_env("DWARF_ENV", "prod")
DWARF_VER  = _dwarf_env("DWARF_VERSION", "1.0.0")
DWARF_BUILD = _dwarf_env("DWARF_BUILD", "")
GIT_SHA    = _dwarf_env("GIT_SHA", "")
RENDER_SERVICE_ID = _dwarf_env("RENDER_SERVICE_ID", "")

def _uptime_s() -> int:
    return int(time.time() - _DWARF_BOOT_TS)

@app.get("/version")
def version():
    return {
        "name": DWARF_NAME,
        "version": DWARF_VER,
        "env": DWARF_ENV,
        "build": DWARF_BUILD,
        "git_sha": GIT_SHA,
        "render_service_id": RENDER_SERVICE_ID,
        "python": platform.python_version(),
        "uptime_s": _uptime_s(),
        "ts_utc": datetime.utcnow().isoformat() + "Z"
    }

@app.get("/readyz")
def readyz():
    # Readiness should stay simple: process is up and routes loaded.
    return {"ready": True, "uptime_s": _uptime_s()}

@app.get("/info")
def info():
    return {
        "service": DWARF_NAME,
        "env": DWARF_ENV,
        "docs": "/docs",
        "openapi": "/openapi.json",
        "health": "/healthz",
        "ready": "/readyz"
    }
# --- DWARF_IDENTITY_LOCK_END ---

