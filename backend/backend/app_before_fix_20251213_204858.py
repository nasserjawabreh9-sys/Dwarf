"""
Stable ASGI entrypoint for Termux.
Target: uvicorn backend.app:app
"""
from fastapi import FastAPI

def _load():
    # Try existing bigger app first (if present)
    try:
        from backend.main import app as a  # type: ignore
        return a
    except Exception:
        pass
    try:
        from main import app as a  # type: ignore
        return a
    except Exception:
        pass
    try:
        from app import app as a  # type: ignore
        return a
    except Exception:
        pass

    a = FastAPI()
    @a.get("/healthz")
    def healthz():
        return {"ok": True, "fallback": True}
    return a

app = _load()
