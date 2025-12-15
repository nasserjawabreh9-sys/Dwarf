from fastapi import FastAPI
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from ops_routes import router as ops_router
from fastapi.middleware.cors import CORSMiddleware

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

    



# --- Ops Router ---
app.include_router(ops_router)
# --- CORS (Render + Static Frontend) ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)
@app.get("/")
    def root():
        return {"ok": True, "mode": "fallback", "hint": "Real app not found; check backend/asgi.py or backend/main.py"}

    @app.get("/healthz")
    def healthz():
        return {"ok": True}

# --- STATION_SPA_FALLBACK (serve React/Vite build + SPA fallback) ---
import pathlib
from fastapi import Request
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

SPA_DIR = pathlib.Path(r"/data/data/com.termux/files/home/station_root/frontend/dist")
if SPA_DIR.exists():
    # Serve static assets (js/css/images)
    app.mount("/assets", StaticFiles(directory=str(SPA_DIR / "assets")), name="spa-assets")

    @app.get("/__spa__", include_in_schema=False)
    def __spa_probe():
        return {"spa": True, "dir": str(SPA_DIR)}

    @app.get("/{full_path:path}", include_in_schema=False)
    def spa_fallback(full_path: str, request: Request):
        # Do NOT hijack API/docs paths
        if full_path.startswith(("api/", "docs", "openapi.json", "health", "healthz")):
            return {"ok": True, "hint": "API route not found", "path": full_path}
        # If a real file exists, serve it
        p = SPA_DIR / full_path
        if p.exists() and p.is_file():
            return FileResponse(str(p))
        # Otherwise return index.html for SPA routing
        return FileResponse(str(SPA_DIR / "index.html"))
# --- END STATION_SPA_FALLBACK ---


templates = Jinja2Templates(directory=str(__import__('pathlib').Path(__file__).parent / 'templates'))

@app.get("/ui", response_class=HTMLResponse)
def ui(request: Request):
    return templates.TemplateResponse("ui.html", {"request": request})

@app.get("/landing", response_class=HTMLResponse)
def landing(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

@app.get("/home", response_class=HTMLResponse)
def home(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})
