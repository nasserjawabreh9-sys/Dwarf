import os
import sqlite3
from urllib.parse import urlparse

def get_database_url() -> str:
    return os.environ.get("DATABASE_URL", "").strip()

def _sqlite_path_from_url(url: str) -> str:
    # accepts: sqlite:////abs/path.db or sqlite:///rel/path.db
    if url.startswith("sqlite:////"):
        return url.replace("sqlite:////", "/")
    if url.startswith("sqlite:///"):
        return url.replace("sqlite:///", "")
    raise ValueError("Bad sqlite url")

def sqlite_init_if_needed(url: str) -> dict:
    path = _sqlite_path_from_url(url)
    conn = sqlite3.connect(path)
    try:
        cur = conn.cursor()
        cur.execute("PRAGMA journal_mode=WAL;")
        cur.execute("CREATE TABLE IF NOT EXISTS station_meta (k TEXT PRIMARY KEY, v TEXT);")
        cur.execute("INSERT OR REPLACE INTO station_meta (k, v) VALUES ('db', 'sqlite');")
        conn.commit()
        return {"ok": True, "engine": "sqlite", "path": path}
    finally:
        conn.close()

def sqlite_probe(url: str) -> dict:
    path = _sqlite_path_from_url(url)
    conn = sqlite3.connect(path)
    try:
        cur = conn.cursor()
        cur.execute("SELECT v FROM station_meta WHERE k='db';")
        row = cur.fetchone()
        return {"ok": True, "engine": "sqlite", "db": (row[0] if row else None), "path": path}
    finally:
        conn.close()

def tcp_probe_postgres(url: str, timeout_s: float = 2.5) -> dict:
    # We do a network reachability probe only (Termux-safe, no psycopg build).
    import socket
    u = urlparse(url)
    host = u.hostname
    port = u.port or 5432
    if not host:
        return {"ok": False, "engine": "postgres", "error": "no host"}
    s = socket.socket()
    s.settimeout(timeout_s)
    try:
        s.connect((host, port))
        return {"ok": True, "engine": "postgres", "host": host, "port": port}
    except Exception as e:
        return {"ok": False, "engine": "postgres", "host": host, "port": port, "error": str(e)}
    finally:
        try: s.close()
        except Exception: pass

def db_health() -> dict:
    url = get_database_url()
    if not url:
        return {"ok": False, "error": "DATABASE_URL missing"}
    if url.startswith("sqlite:"):
        init = sqlite_init_if_needed(url)
        probe = sqlite_probe(url)
        return {"ok": True, "url_kind": "sqlite", "init": init, "probe": probe}
    # postgres or other
    p = tcp_probe_postgres(url)
    return {"ok": p.get("ok", False), "url_kind": "postgres", "probe": p, "note": "tcp reachability only"}
