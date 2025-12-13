import time
from typing import Dict, Any

STATE: Dict[str, Any] = {
    "rooms": {
        "L0": {"name": "L0", "desc": "Safe defaults", "enabled": True},
        "L1": {"name": "L1", "desc": "Automation low risk", "enabled": True},
        "L2": {"name": "L2", "desc": "Automation medium risk", "enabled": True},
        "L3": {"name": "L3", "desc": "Requires owner explicit approval", "enabled": False},
    },
    "guards": {
        "anti_repeat": True,
        "termux_safe": True,
        "no_arabic_in_code": True,
        "ports_auto_fix": True,
        "size_guard": True,
        "rate_limit": True
    },
    "updated_at": int(time.time())
}

def snapshot() -> Dict[str, Any]:
    return STATE

def patch(data: Dict[str, Any]) -> Dict[str, Any]:
    for k,v in data.items():
        if k in STATE and isinstance(STATE[k], dict) and isinstance(v, dict):
            STATE[k].update(v)
        else:
            STATE[k] = v
    STATE["updated_at"] = int(time.time())
    return STATE
