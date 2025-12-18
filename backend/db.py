import os
from sqlalchemy import create_engine, text

def _normalize_db_url(url: str) -> str:
    if url.startswith("postgres://"):
        return "postgresql://" + url[len("postgres://"):]
    return url

def get_db_url() -> str:
    url = os.environ.get("DATABASE_URL", "").strip()
    if not url:
        raise RuntimeError("DATABASE_URL is missing")
    return _normalize_db_url(url)

_ENGINE = None

def engine():
    global _ENGINE
    if _ENGINE is None:
        _ENGINE = create_engine(get_db_url(), pool_pre_ping=True, future=True)
    return _ENGINE

def ping() -> dict:
    with engine().connect() as conn:
        conn.execute(text("SELECT 1"))
    return {"db": "ok"}
