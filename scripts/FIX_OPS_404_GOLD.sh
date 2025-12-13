#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
BACK="$ROOT/backend"
OPS="$ROOT/scripts"
LOGS="$ROOT/station_logs"

mkdir -p "$BACK" "$OPS" "$LOGS"

# 1) Kill ports hard
cat > "$OPS/uul_kill_ports.sh" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
kill_port(){ local p="$1"; for pid in $(lsof -tiTCP:"$p" -sTCP:LISTEN 2>/dev/null); do kill -9 "$pid" >/dev/null 2>&1 || true; done; }
kill_port 8000
kill_port 5173
echo "OK: killed listeners on 8000/5173 (if any)."
SH
chmod +x "$OPS/uul_kill_ports.sh"
bash "$OPS/uul_kill_ports.sh" >/dev/null 2>&1 || true

# 2) Force-write GOLD asgi.py (single source of truth)
cat > "$BACK/asgi.py" <<'PY'
from fastapi import FastAPI, Header, HTTPException
from typing import Any, Optional
import os, json, time, pathlib, subprocess, platform, tarfile, sqlite3, threading, uuid, hashlib

ROOT = os.environ.get("STATION_ROOT", str(pathlib.Path.home() / "station_root"))
STATE_DIR = pathlib.Path(ROOT) / "state"
LOGS_DIR  = pathlib.Path(ROOT) / "station_logs"
STATE_DIR.mkdir(parents=True, exist_ok=True)
LOGS_DIR.mkdir(parents=True, exist_ok=True)

DB_PATH = str(STATE_DIR / "station.db")
EDIT_KEY = os.environ.get("STATION_EDIT_KEY", "1234")

# ---------- Rate limit (simple in-memory) ----------
_rl_lock = threading.Lock()
_rl_bucket: dict[str, list[float]] = {}

def _now() -> float:
    return time.time()

def rate_limit(key: str, limit: int = 60, window_sec: int = 60):
    t = _now()
    with _rl_lock:
        arr = _rl_bucket.get(key, [])
        arr = [x for x in arr if t - x <= window_sec]
        if len(arr) >= limit:
            raise HTTPException(status_code=429, detail="rate limit")
        arr.append(t)
        _rl_bucket[key] = arr

def guard(edit_key: Optional[str]):
    if edit_key != EDIT_KEY:
        raise HTTPException(status_code=403, detail="edit key required")

# ---------- SQLite store ----------
def db():
    con = sqlite3.connect(DB_PATH)
    con.execute("PRAGMA journal_mode=WAL;")
    return con

def db_init():
    con = db()
    con.execute("""CREATE TABLE IF NOT EXISTS kv (
        k TEXT PRIMARY KEY,
        v TEXT NOT NULL,
        updated_at REAL NOT NULL
    )""")
    con.execute("""CREATE TABLE IF NOT EXISTS jobs (
        id TEXT PRIMARY KEY,
        room TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at REAL NOT NULL,
        updated_at REAL NOT NULL,
        payload TEXT,
        result TEXT,
        error TEXT
    )""")
    con.execute("""CREATE TABLE IF NOT EXISTS audit (
        id TEXT PRIMARY KEY,
        ts REAL NOT NULL,
        actor TEXT,
        action TEXT NOT NULL,
        data TEXT
    )""")
    con.commit()
    con.close()

db_init()

def audit(action: str, data: dict | None = None, actor: str = "local"):
    con = db()
    con.execute(
        "INSERT INTO audit(id, ts, actor, action, data) VALUES(?,?,?,?,?)",
        (str(uuid.uuid4()), _now(), actor, action, json.dumps(data or {}))
    )
    con.commit()
    con.close()

def kv_get(k: str, default=None):
    con = db()
    cur = con.execute("SELECT v FROM kv WHERE k=?", (k,))
    row = cur.fetchone()
    con.close()
    return json.loads(row[0]) if row else default

def kv_set(k: str, v: Any):
    con = db()
    con.execute(
        "INSERT INTO kv(k,v,updated_at) VALUES(?,?,?) "
        "ON CONFLICT(k) DO UPDATE SET v=excluded.v, updated_at=excluded.updated_at",
        (k, json.dumps(v), _now())
    )
    con.commit()
    con.close()

def job_create(room: str, payload: dict):
    jid = str(uuid.uuid4())
    con = db()
    con.execute(
        "INSERT INTO jobs(id,room,status,created_at,updated_at,payload) VALUES(?,?,?,?,?,?)",
        (jid, room, "queued", _now(), _now(), json.dumps(payload))
    )
    con.commit()
    con.close()
    return jid

def job_update(jid: str, **fields):
    allowed = {"status","result","error"}
    sets, vals = [], []
    for k,v in fields.items():
        if k in allowed:
            sets.append(f"{k}=?")
            if k == "result" and v is not None:
                vals.append(json.dumps(v))
            else:
                vals.append(v)
    if not sets:
        return
    sets.append("updated_at=?")
    vals.append(_now())
    vals.append(jid)
    con = db()
    con.execute(f"UPDATE jobs SET {', '.join(sets)} WHERE id=?", tuple(vals))
    con.commit()
    con.close()

def job_get(jid: str):
    con = db()
    cur = con.execute("SELECT id,room,status,created_at,updated_at,payload,result,error FROM jobs WHERE id=?", (jid,))
    row = cur.fetchone()
    con.close()
    if not row:
        return None
    return {
        "id": row[0], "room": row[1], "status": row[2],
        "created_at": row[3], "updated_at": row[4],
        "payload": json.loads(row[5]) if row[5] else {},
        "result": json.loads(row[6]) if row[6] else None,
        "error": row[7],
    }

def jobs_list(limit: int = 50):
    con = db()
    cur = con.execute("SELECT id,room,status,created_at,updated_at FROM jobs ORDER BY created_at DESC LIMIT ?", (limit,))
    rows = cur.fetchall()
    con.close()
    return [{"id":r[0],"room":r[1],"status":r[2],"created_at":r[3],"updated_at":r[4]} for r in rows]

# ---------- Helpers ----------
def _cmd(s: str) -> str:
    try:
        out = subprocess.check_output(s, shell=True, stderr=subprocess.STDOUT, timeout=8)
        return out.decode("utf-8","ignore").strip()
    except Exception:
        return ""

def _safe_path(p: str) -> pathlib.Path:
    base = pathlib.Path(ROOT).resolve()
    tgt  = (base / p).resolve()
    if tgt != base and base not in tgt.parents:
        raise HTTPException(status_code=400, detail="forbidden path")
    return tgt

def _file_hash(path: str) -> str:
    try:
        b = pathlib.Path(path).read_bytes()
        return hashlib.sha256(b).hexdigest()[:16]
    except Exception:
        return "na"

ASGI_FILE = __file__
ASGI_HASH = _file_hash(__file__)

# ---------- Kernel / Rooms ----------
class Kernel:
    def __init__(self):
        self.rooms: dict[str, Any] = {}
    def register(self, name: str, fn: Any):
        self.rooms[name] = fn
    def run(self, name: str, payload: dict):
        if name not in self.rooms:
            return {"error":"room not found","room":name,"available":sorted(self.rooms)}
        return self.rooms[name](payload or {})

kernel = Kernel()

def room_doctor(_):
    return {
        "status":"ok",
        "mode":"termux-safe",
        "python": _cmd("python -V"),
        "node": _cmd("node -v"),
        "npm": _cmd("npm -v"),
        "git": _cmd("git --version"),
        "platform": platform.platform(),
        "root": ROOT,
        "db": DB_PATH
    }

def room_rooms_list(_):
    return {"rooms": sorted(kernel.rooms)}

def room_fs(payload):
    action = payload.get("action")
    tgt = _safe_path(payload.get("path",""))
    if action == "ls":
        if not tgt.exists(): return {"error":"not found"}
        return {"path": str(tgt), "files": [p.name for p in tgt.iterdir()]}
    if action == "read":
        if not tgt.exists(): return {"error":"not found"}
        return {"path": str(tgt), "content": tgt.read_text(errors="ignore")[:200000]}
    if action == "write":
        content = payload.get("content","")
        tgt.parent.mkdir(parents=True, exist_ok=True)
        tgt.write_text(content)
        return {"ok": True, "path": str(tgt), "bytes": len(content.encode("utf-8","ignore"))}
    return {"error":"unknown fs action"}

def room_env(payload):
    allow = set(payload.get("keys", []))
    out = {}
    for k in allow:
        if k.startswith("STATION_") or k in ("OPENAI_API_KEY","GITHUB_TOKEN","RENDER_API_KEY"):
            out[k] = ("set" if os.environ.get(k) else None)
    return out

def room_snapshot(_):
    snap_dir = pathlib.Path(ROOT) / "snapshots"
    snap_dir.mkdir(exist_ok=True)
    name = f"snapshot_{int(time.time())}.tgz"
    f = snap_dir / name
    with tarfile.open(f, "w:gz") as tar:
        tar.add(ROOT, arcname="station_root")
    audit("snapshot", {"file": str(f)})
    return {"snapshot": str(f)}

def room_restore(payload):
    f = payload.get("file")
    if not f: return {"error":"file required"}
    fp = pathlib.Path(f)
    if not fp.exists(): return {"error":"not found"}
    with tarfile.open(fp, "r:gz") as tar:
        tar.extractall(path=pathlib.Path(ROOT).parent)
    audit("restore", {"file": str(fp)})
    return {"restored": str(fp)}

kernel.register("doctor", room_doctor)
kernel.register("rooms_list", room_rooms_list)
kernel.register("fs", room_fs)
kernel.register("env", room_env)
kernel.register("snapshot", room_snapshot)
kernel.register("restore", room_restore)

# ---------- Jobs ----------
def _run_job(jid: str, room: str, payload: dict):
    try:
        job_update(jid, status="running")
        res = kernel.run(room, payload)
        job_update(jid, status="done", result=res)
    except Exception as e:
        job_update(jid, status="failed", error=str(e))

def enqueue(room: str, payload: dict):
    jid = job_create(room, payload)
    t = threading.Thread(target=_run_job, args=(jid, room, payload), daemon=True)
    t.start()
    return jid

# ---------- FastAPI (Factory API) ----------
app = FastAPI(title="Station Factory Kernel", version="1.1.0")

@app.get("/__whoami")
def whoami():
    return {"asgi_file": ASGI_FILE, "asgi_hash": ASGI_HASH, "rooms": sorted(kernel.rooms)}

@app.get("/healthz")
def healthz():
    return {"ok": True, "entry": "asgi.factory", "rooms": len(kernel.rooms), "db": True, "hash": ASGI_HASH}

@app.get("/info")
def info():
    return {"root": ROOT, "db": DB_PATH, "rooms": sorted(kernel.rooms), "edit_key_required": True}

@app.get("/ops/rooms")
def ops_rooms():
    return {"rooms": sorted(kernel.rooms)}

@app.post("/ops/run/{room}")
def ops_run(room: str, payload: dict | None = None, x_edit_key: str | None = Header(None)):
    guard(x_edit_key)
    rate_limit(x_edit_key or "none")
    audit("ops_run", {"room": room})
    return kernel.run(room, payload or {})

@app.post("/ops/enqueue/{room}")
def ops_enqueue(room: str, payload: dict | None = None, x_edit_key: str | None = Header(None)):
    guard(x_edit_key)
    rate_limit(x_edit_key or "none")
    jid = enqueue(room, payload or {})
    audit("ops_enqueue", {"room": room, "job": jid})
    return {"job_id": jid}

@app.get("/ops/jobs")
def ops_jobs(limit: int = 50, x_edit_key: str | None = Header(None)):
    guard(x_edit_key)
    return {"jobs": jobs_list(limit)}

@app.get("/ops/jobs/{job_id}")
def ops_job(job_id: str, x_edit_key: str | None = Header(None)):
    guard(x_edit_key)
    j = job_get(job_id)
    if not j:
        raise HTTPException(status_code=404, detail="job not found")
    return j

@app.get("/ops/logs/tail")
def ops_logs_tail(file: str = "backend.log", n: int = 200, x_edit_key: str | None = Header(None)):
    guard(x_edit_key)
    p = (LOGS_DIR / file).resolve()
    if LOGS_DIR not in p.parents and p != LOGS_DIR:
        raise HTTPException(status_code=400, detail="forbidden log path")
    if not p.exists():
        return {"file": str(p), "lines": []}
    lines = p.read_text(errors="ignore").splitlines()[-max(1, min(n, 800)):]
    return {"file": str(p), "lines": lines}
PY

# 3) Official runner (forces correct module)
cat > "$BACK/run_backend_official.sh" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
LOGS="$ROOT/station_logs"; mkdir -p "$LOGS"
cd "$ROOT/backend"
source .venv/bin/activate 2>/dev/null || true
bash "$ROOT/scripts/uul_kill_ports.sh" >/dev/null 2>&1 || true
nohup python -m uvicorn asgi:app --host 127.0.0.1 --port 8000 >"$LOGS/backend.log" 2>&1 &
sleep 1
curl -fsS http://127.0.0.1:8000/healthz >/dev/null 2>&1 && echo "OK: backend up" || { echo "Backend failed"; tail -n 140 "$LOGS/backend.log" || true; exit 1; }
echo "Backend: http://127.0.0.1:8000"
SH
chmod +x "$BACK/run_backend_official.sh"

# 4) Start & verify (must show asgi.factory + ops works)
echo "=== START (FORCE GOLD) ==="
bash "$BACK/run_backend_official.sh"

echo "=== VERIFY ==="
echo "[1] /healthz"
curl -s http://127.0.0.1:8000/healthz ; echo
echo "[2] /__whoami"
curl -s http://127.0.0.1:8000/__whoami ; echo
echo "[3] /info"
curl -s http://127.0.0.1:8000/info ; echo
echo "[4] /ops/rooms"
curl -s http://127.0.0.1:8000/ops/rooms ; echo
echo "[5] /ops/run/doctor"
curl -s -X POST http://127.0.0.1:8000/ops/run/doctor -H "X-EDIT-KEY: 1234" ; echo

echo "=== DONE ==="
