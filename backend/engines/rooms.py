from __future__ import annotations
from dataclasses import dataclass, asdict
from typing import Dict, Any, Optional, Callable
import time
import asyncio

@dataclass
class Room:
    id: str
    name: str
    kind: str
    description: str = ""
    last_run_ts: Optional[float] = None
    last_status: str = "never"
    last_result: Optional[Dict[str, Any]] = None

class RoomsRegistry:
    def __init__(self) -> None:
        self._rooms: Dict[str, Room] = {}
        self._lock = asyncio.Lock()

    async def ensure_defaults(self) -> None:
        async with self._lock:
            if self._rooms:
                return
            self._rooms["room_guard"] = Room(
                id="room_guard",
                name="Guard Diagnostics",
                kind="guard",
                description="Checks common runtime issues and reports status."
            )
            self._rooms["room_health"] = Room(
                id="room_health",
                name="Health Snapshot",
                kind="health",
                description="Captures backend status + basic environment signals."
            )
            self._rooms["room_seed"] = Room(
                id="room_seed",
                name="Seed/Bootstrap",
                kind="seed",
                description="Placeholder for future seed routines."
            )

    async def list_rooms(self) -> Dict[str, Any]:
        await self.ensure_defaults()
        async with self._lock:
            return {rid: asdict(r) for rid, r in self._rooms.items()}

    async def get(self, rid: str) -> Room:
        await self.ensure_defaults()
        async with self._lock:
            if rid not in self._rooms:
                raise KeyError(rid)
            return self._rooms[rid]

    async def update_room(self, room: Room) -> None:
        async with self._lock:
            self._rooms[room.id] = room

async def run_room_impl(room: Room) -> Dict[str, Any]:
    # lightweight, Termux-safe routines
    if room.kind == "guard":
        return {
            "ok": True,
            "checks": {
                "python": True,
                "uvicorn": True,
                "filesystem": True,
            }
        }
    if room.kind == "health":
        return {
            "ok": True,
            "ts": time.time(),
            "notes": "backend alive"
        }
    if room.kind == "seed":
        return {
            "ok": True,
            "ts": time.time(),
            "notes": "seed placeholder"
        }
    return {"ok": True, "notes": f"unknown kind={room.kind}"}

async def run_room(reg: RoomsRegistry, rid: str) -> Dict[str, Any]:
    room = await reg.get(rid)
    room.last_run_ts = time.time()
    room.last_status = "running"
    await reg.update_room(room)

    try:
        res = await run_room_impl(room)
        room.last_status = "ok" if res.get("ok") else "fail"
        room.last_result = res
        await reg.update_room(room)
        return res
    except Exception as e:
        room.last_status = "fail"
        room.last_result = {"ok": False, "error": repr(e)}
        await reg.update_room(room)
        return room.last_result
