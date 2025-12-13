import json
from pathlib import Path
from typing import Dict, Any

def base_root(station_root: str) -> Path:
    if station_root:
        return Path(station_root).expanduser()
    return Path.home() / "station_root"

def store_dir(station_root: str) -> Path:
    d = base_root(station_root) / "app_storage"
    d.mkdir(parents=True, exist_ok=True)
    return d

def store_path(station_root: str) -> Path:
    return store_dir(station_root) / "settings.json"

def read_settings(station_root: str) -> Dict[str, Any]:
    p = store_path(station_root)
    if not p.exists():
        return {}
    return json.loads(p.read_text(encoding="utf-8"))

def write_settings(station_root: str, data: Dict[str, Any]) -> Dict[str, Any]:
    p = store_path(station_root)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    return data
