import time
from typing import Dict, Any

STATE: Dict[str, Any] = {
    "enabled": True,
    "last_tick": 0,
    "events": [],
    "max_events": 250
}

def add_event(kind: str, payload: dict):
    ev = {"ts": int(time.time()), "kind": kind, "payload": payload}
    STATE["events"].append(ev)
    if len(STATE["events"]) > STATE["max_events"]:
        STATE["events"] = STATE["events"][-STATE["max_events"]:]
    return ev

def tick(meta: dict | None = None):
    STATE["last_tick"] = int(time.time())
    add_event("tick", {"ok": True, "meta": meta or {}})
    return STATE

def get_state():
    return STATE
