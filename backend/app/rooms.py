from typing import Dict
from app.locks import GlobalLock

ROOMS: Dict[str, GlobalLock] = {
    "core": GlobalLock("room_core", ttl=8.0),
    "git":  GlobalLock("room_git",  ttl=12.0),
    "ops":  GlobalLock("room_ops",  ttl=12.0),
    "llm":  GlobalLock("room_llm",  ttl=10.0),
}

def acquire_room(room: str) -> bool:
    lock = ROOMS.get(room)
    return lock.acquire() if lock else False

def release_room(room: str):
    lock = ROOMS.get(room)
    if lock:
        lock.release()
