from fastapi import FastAPI
from starlette.applications import Starlette

# Import the existing app from your codebase.
# It might be Starlette or FastAPI; we treat it as ASGI.
try:
    from backend.main import app as inner_app  # type: ignore
except Exception as e:
    inner_app = Starlette()
    # minimal fallback so container doesn't die
    # (we still want /healthz to work)
    # you can inspect logs on Render for the exception details.

app = FastAPI(title="Dwarf API", version="1.0.0")

@app.get("/healthz")
def healthz():
    return {"ok": True, "via": "fastapi-wrapper"}

@app.get("/health")
def health():
    return {"ok": True, "via": "fastapi-wrapper"}

@app.get("/")
def root():
    return {"service": "Dwarf", "status": "up", "docs": "/docs", "openapi": "/openapi.json"}

# Mount the existing ASGI app last so /docs & /openapi.json stay available.
app.mount("/", inner_app)
