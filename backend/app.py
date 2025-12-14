from fastapi import FastAPI

# Stable entrypoint for uvicorn: backend.app:app
# We try to import the real FastAPI "app" from your existing modules.
app = None

for mod_path in ("backend.asgi", "backend.main", "backend.app.main", "backend.backend.main"):
    try:
        mod = __import__(mod_path, fromlist=["app"])
        if hasattr(mod, "app"):
            app = getattr(mod, "app")
            break
    except Exception:
        pass

if app is None:
    # Fallback minimal app so Render won't 503 while you fix wiring
    app = FastAPI(title="Station Fallback", version="1.0.0")

    @app.get("/")
    def root():
        return {"ok": True, "mode": "fallback", "hint": "Real app not found; check backend/asgi.py or backend/main.py"}

    @app.get("/healthz")
    def healthz():
        return {"ok": True}
