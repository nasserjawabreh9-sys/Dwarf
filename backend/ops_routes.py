from fastapi import APIRouter, Header, HTTPException
import os, time

router = APIRouter(prefix="/api/ops", tags=["ops"])

EDIT_KEY = os.environ.get("STATION_EDIT_KEY", "1234")

# --- in-memory minimal state (safe starter) ---
DYNAMO = {"running": False, "started_at": None}
ROOMS = [
    {"id": "room-1", "name": "Room 1", "desc": "Starter room", "enabled": True},
    {"id": "room-2", "name": "Room 2", "desc": "Starter room", "enabled": True},
]
LOGS = []

def _guard(x_edit_key: str | None):
    if (x_edit_key or "") != EDIT_KEY:
        raise HTTPException(status_code=401, detail="invalid X-Edit-Key")

def _log(msg: str):
    LOGS.append({"ts": time.time(), "msg": msg})
    # keep last 200
    if len(LOGS) > 200:
        del LOGS[:-200]

@router.get("/rooms")
def list_rooms(x_edit_key: str | None = Header(default=None, alias="X-Edit-Key")):
    _guard(x_edit_key)
    return {"ok": True, "rooms": ROOMS}

@router.post("/rooms/{rid}/run")
def run_room(rid: str, x_edit_key: str | None = Header(default=None, alias="X-Edit-Key")):
    _guard(x_edit_key)
    _log(f"run_room: {rid}")
    return {"ok": True, "room_id": rid, "status": "queued"}

@router.post("/dynamo/start")
def dynamo_start(x_edit_key: str | None = Header(default=None, alias="X-Edit-Key")):
    _guard(x_edit_key)
    if not DYNAMO["running"]:
        DYNAMO["running"] = True
        DYNAMO["started_at"] = time.time()
        _log("dynamo_start")
    return {"ok": True, "running": DYNAMO["running"], "started_at": DYNAMO["started_at"]}

@router.post("/dynamo/stop")
def dynamo_stop(x_edit_key: str | None = Header(default=None, alias="X-Edit-Key")):
    _guard(x_edit_key)
    if DYNAMO["running"]:
        DYNAMO["running"] = False
        _log("dynamo_stop")
    return {"ok": True, "running": DYNAMO["running"], "started_at": DYNAMO["started_at"]}

@router.get("/dynamo/status")
def dynamo_status(x_edit_key: str | None = Header(default=None, alias="X-Edit-Key")):
    _guard(x_edit_key)
    return {"ok": True, **DYNAMO}

@router.get("/logs/tail")
def logs_tail(x_edit_key: str | None = Header(default=None, alias="X-Edit-Key")):
    _guard(x_edit_key)
    return {"ok": True, "logs": LOGS[-80:]}
