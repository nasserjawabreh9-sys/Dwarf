from __future__ import annotations
from fastapi import APIRouter, Header, HTTPException
from typing import Any, Optional, Dict, List
import os
import pathlib

from ..engines.rooms import RoomsRegistry, run_room
from ..engines.dynamo import DynamoLoop

router = APIRouter(prefix="/api/ops", tags=["ops"])

def _require_edit_key(x_edit_key: Optional[str]) -> None:
    expected = os.environ.get("STATION_EDIT_KEY", "1234")
    if not x_edit_key or x_edit_key != expected:
        raise HTTPException(status_code=401, detail="Missing/invalid X-Edit-Key")

@router.get("/rooms")
async def rooms_list(x_edit_key: Optional[str] = Header(default=None, alias="X-Edit-Key")) -> Any:
    _require_edit_key(x_edit_key)
    reg: RoomsRegistry = router.state.rooms
    return {"ok": True, "rooms": await reg.list_rooms()}

@router.post("/rooms/{rid}/run")
async def rooms_run(rid: str, x_edit_key: Optional[str] = Header(default=None, alias="X-Edit-Key")) -> Any:
    _require_edit_key(x_edit_key)
    reg: RoomsRegistry = router.state.rooms
    res = await run_room(reg, rid)
    return {"ok": True, "room_id": rid, "result": res}

@router.get("/dynamo/status")
async def dynamo_status(x_edit_key: Optional[str] = Header(default=None, alias="X-Edit-Key")) -> Any:
    _require_edit_key(x_edit_key)
    loop: DynamoLoop = router.state.dynamo
    return {"ok": True, "state": await loop.status()}

@router.post("/dynamo/start")
async def dynamo_start(payload: Dict[str, Any] | None = None,
                      x_edit_key: Optional[str] = Header(default=None, alias="X-Edit-Key")) -> Any:
    _require_edit_key(x_edit_key)
    loop: DynamoLoop = router.state.dynamo
    interval = None
    if payload:
        interval = payload.get("interval_sec")
    st = await loop.start(interval_sec=interval)
    return {"ok": True, "state": st}

@router.post("/dynamo/stop")
async def dynamo_stop(x_edit_key: Optional[str] = Header(default=None, alias="X-Edit-Key")) -> Any:
    _require_edit_key(x_edit_key)
    loop: DynamoLoop = router.state.dynamo
    st = await loop.stop()
    return {"ok": True, "state": st}

@router.post("/dynamo/plan")
async def dynamo_plan(payload: Dict[str, Any],
                      x_edit_key: Optional[str] = Header(default=None, alias="X-Edit-Key")) -> Any:
    _require_edit_key(x_edit_key)
    plan = payload.get("plan") or []
    if not isinstance(plan, list):
        raise HTTPException(status_code=400, detail="plan must be list")
    loop: DynamoLoop = router.state.dynamo
    st = await loop.set_plan([str(x) for x in plan])
    return {"ok": True, "state": st}

@router.get("/logs/tail")
async def logs_tail(n: int = 120, x_edit_key: Optional[str] = Header(default=None, alias="X-Edit-Key")) -> Any:
    _require_edit_key(x_edit_key)
    root = pathlib.Path.home() / "station_root" / "station_logs"
    log = root / "backend_8000.log"
    if not log.exists():
        # fallback
        cands = sorted(root.glob("backend_*.log"))
        if cands:
            log = cands[-1]
    if not log.exists():
        return {"ok": True, "file": None, "lines": []}
    try:
        lines = log.read_text(encoding="utf-8", errors="ignore").splitlines()[-max(1, int(n)):]
    except Exception as e:
        return {"ok": False, "error": repr(e)}
    return {"ok": True, "file": str(log), "lines": lines}
