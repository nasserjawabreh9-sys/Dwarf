import json, os
from pathlib import Path
from typing import Any, Dict, List

ROOT = Path(__file__).resolve().parents[2]
LOG = ROOT / "station_meta" / "agent" / "decisions.log.jsonl"
LOG.parent.mkdir(parents=True, exist_ok=True)

def append(entry: Dict[str, Any]) -> None:
    with LOG.open("a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")

def tail(n: int = 50) -> List[Dict[str, Any]]:
    if not LOG.exists():
        return []
    lines = LOG.read_text(encoding="utf-8").splitlines()
    out=[]
    for s in lines[-max(1, min(n, 200)):]:
        try: out.append(json.loads(s))
        except Exception: pass
    return out
