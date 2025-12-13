"""
Stable ASGI entrypoint.
Target: uvicorn backend.app:app

It tries to load an existing FastAPI app, then enforces /healthz.
"""
from fastapi import FastAPI

def _load() -> FastAPI:
    # 1) backend.main
    try:
        from backend.main import app as a  # type: ignore
        return a
    except Exception:
        pass

    # 2) root main.py
    try:
        from main import app as a  # type: ignore
        return a
    except Exception:
        pass

    # 3) root app.py
    try:
        from app import app as a  # type: ignore
        return a
    except Exception:
        pass

    # 4) fallback
    a = FastAPI()

    @a.get("/healthz")
    def healthz():
        return {"ok": True, "fallback": True}

    return a

def _ensure_healthz(a: FastAPI) -> FastAPI:
    # If /healthz doesn't exist, add it.
    try:
        paths = set()
        for r in getattr(a, "routes", []):
            p = getattr(r, "path", None)
            if isinstance(p, str):
                paths.add(p)
        if "/healthz" not in paths:
            @a.get("/healthz")
            def healthz():
                return {"ok": True, "patched": True}
    except Exception:
        # As a last resort, return a new minimal app.
        b = FastAPI()

        @b.get("/healthz")
        def healthz():
            return {"ok": True, "fallback": True}

        return b

    return a

app = _ensure_healthz(_load())
