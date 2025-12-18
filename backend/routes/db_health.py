from fastapi import APIRouter
import os

router = APIRouter(tags=["db"])

@router.get("/db/healthz")
def db_healthz():
    dsn = (os.environ.get("DATABASE_URL") or "").strip()
    if not dsn:
        return {"status": "fail", "reason": "DATABASE_URL missing"}
    try:
        import psycopg2  # type: ignore
        conn = psycopg2.connect(dsn, connect_timeout=5)
        try:
            cur = conn.cursor()
            cur.execute("SELECT 1;")
            val = cur.fetchone()[0]
            cur.close()
            return {"status": "ok", "select": val}
        finally:
            conn.close()
    except Exception as e:
        return {"status": "fail", "error": str(e)}
