import os, time, json, uuid, threading
from dataclasses import dataclass, asdict
from typing import Any, Dict, List, Optional

# Rooms (synchronization primitives)
ROOMS = ["core", "ops", "senses", "hooks", "agent", "git", "render"]
_LOCKS: Dict[str, threading.Lock] = {r: threading.Lock() for r in ROOMS}

# In-memory queue + task store (persisting can be added later)
_QUEUE: List[str] = []
_TASKS: Dict[str, Dict[str, Any]] = {}

def now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

def _mode() -> str:
    # Online if OpenAI key exists; else offline.
    k = (os.getenv("STATION_OPENAI_API_KEY") or os.getenv("OPENAI_API_KEY") or "").strip()
    return "online" if k else "offline"

@dataclass
class Task:
    id: str
    room: str
    type: str
    payload: Dict[str, Any]
    status: str
    created_at: str
    updated_at: str
    result: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
    mode: str = "offline"

def submit(room: str, ttype: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    if room not in _LOCKS:
        room = "core"
    tid = str(uuid.uuid4())
    t = Task(
        id=tid, room=room, type=ttype, payload=payload or {},
        status="queued", created_at=now_iso(), updated_at=now_iso(),
        mode=_mode()
    )
    _TASKS[tid] = asdict(t)
    _QUEUE.append(tid)
    return _TASKS[tid]

def list_tasks(limit: int = 50) -> List[Dict[str, Any]]:
    items = list(_TASKS.values())
    items.sort(key=lambda x: x.get("created_at",""), reverse=True)
    return items[: max(1, min(limit, 200))]

def get_task(tid: str) -> Optional[Dict[str, Any]]:
    return _TASKS.get(tid)

def _offline_execute(task: Dict[str, Any]) -> Dict[str, Any]:
    # Deterministic offline behaviors (extend later)
    ttype = (task.get("type") or "").strip()
    payload = task.get("payload") or {}
    if ttype == "ping":
        return {"ok": True, "mode": "offline", "echo": payload, "ts": now_iso()}
    if ttype == "room_check":
        return {"ok": True, "mode": "offline", "rooms": ROOMS, "locks": len(_LOCKS)}
    if ttype == "summarize":
        txt = str(payload.get("text",""))
        return {"ok": True, "mode": "offline", "summary": (txt[:240] + ("..." if len(txt)>240 else ""))}
    return {"ok": True, "mode": "offline", "note": "stub_task", "type": ttype, "payload": payload}

def _online_execute(task: Dict[str, Any]) -> Dict[str, Any]:
    # Online executor is a stub-by-default to avoid hard dependency.
    # Real LLM call is handled in agent routes (R9700).
    return {"ok": True, "mode": "online", "note": "llm_routed_via_agent", "task_type": task.get("type")}

def run_next() -> Optional[Dict[str, Any]]:
    if not _QUEUE:
        return None

    tid = _QUEUE.pop(0)
    task = _TASKS.get(tid)
    if not task:
        return None

    room = task.get("room") or "core"
    lock = _LOCKS.get(room) or _LOCKS["core"]

    with lock:
        task["status"] = "running"
        task["updated_at"] = now_iso()
        try:
            if task.get("mode") == "online":
                res = _online_execute(task)
            else:
                res = _offline_execute(task)
            task["result"] = res
            task["status"] = "done"
        except Exception as e:
            task["error"] = str(e)
            task["status"] = "failed"
        task["updated_at"] = now_iso()
        _TASKS[tid] = task
        return task

def status() -> Dict[str, Any]:
    return {
        "ok": True,
        "mode": _mode(),
        "queue_len": len(_QUEUE),
        "tasks_len": len(_TASKS),
        "rooms": ROOMS,
    }
