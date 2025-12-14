from fastapi import FastAPI

# Stable entrypoint for uvicorn: backend.entry:app
# Try to import the real app from common locations in your repo.
app = None
last_err = None

CANDIDATES = [
    "backend.asgi",
    "backend.main",
    "backend.app.main",
    "backend.backend.main",
    "backend.app.app",     # if someone nested strangely
]

for mod_path in CANDIDATES:
    try:
        mod = __import__(mod_path, fromlist=["app"])
        if hasattr(mod, "app"):
            app = getattr(mod, "app")
            break
    except Exception as e:
        last_err = e

if app is None:
    # Fallback minimal app to keep service alive (prevents 503 during boot)
    app = FastAPI(title="Station Fallback", version="1.0.0")

    @app.get("/")
    def root():
        return {
            "ok": True,
            "mode": "fallback",
            "hint": "Real app not found. Check backend/asgi.py or backend/main.py wiring.",
            "last_import_error": str(last_err) if last_err else None,
        }

    @app.get("/healthz")
    def healthz():
        return {"ok": True, "mode": "fallback"}
