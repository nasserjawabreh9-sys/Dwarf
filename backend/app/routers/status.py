from __future__ import annotations
from fastapi import APIRouter
from pathlib import Path
import os, time, json

router = APIRouter()

ROOT = Path(os.environ.get("STATION_ROOT", str(Path.home() / "station_root")))
META = ROOT / "station_meta"
LOGS = ROOT / "global" / "logs"
BACK = ROOT / "backend"

def _exists(p: Path) -> bool:
    try:
        return p.exists()
    except Exception:
        return False

def _read_text(p: Path, limit: int = 4000) -> str:
    try:
        return p.read_text(encoding="utf-8", errors="ignore")[:limit]
    except Exception:
        return ""

def _pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except Exception:
        return False

def _pidfile_status(pidfile: Path) -> dict:
    if not _exists(pidfile):
        return {"pidfile": str(pidfile), "running": False, "pid": None}
    raw = _read_text(pidfile).strip()
    try:
        pid = int(raw)
    except Exception:
        return {"pidfile": str(pidfile), "running": False, "pid": None, "raw": raw}
    return {"pidfile": str(pidfile), "running": _pid_alive(pid), "pid": pid}

@router.get("/api/status")
def status():
    # runtime markers
    dyn_pid = META / "pids" / "dynamo_worker.pid"
    loop_pid = META / "pids" / "loop_worker.pid"

    # db/state indicators
    station_db = ROOT / "state" / "station.db"
    agent_q = BACK / "agent_queue.sqlite3"

    # logs indicators
    dyn_log = META / "logs" / "dynamo_worker.log"
    loop_log = META / "logs" / "loop_worker.log"

    now = int(time.time())
    payload = {
        "ok": True,
        "ts": now,
        "root": str(ROOT),
        "paths": {
            "station_db": str(station_db),
            "agent_queue": str(agent_q),
            "logs_dir": str(LOGS),
            "meta_dir": str(META),
        },
        "files": {
            "station_db_exists": _exists(station_db),
            "agent_queue_exists": _exists(agent_q),
            "dynamo_log_exists": _exists(dyn_log),
            "loop_log_exists": _exists(loop_log),
        },
        "process": {
            "dynamo_worker": _pidfile_status(dyn_pid),
            "loop_worker": _pidfile_status(loop_pid),
        },
        "hints": {
            "start": "/ops/loop/start  | /ops/dynamo/start",
            "stop":  "/ops/loop/stop   | /ops/dynamo/stop",
            "status":"/api/status",
        }
    }
    return payload
