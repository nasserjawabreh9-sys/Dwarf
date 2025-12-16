from __future__ import annotations
from dataclasses import dataclass, asdict
from typing import Optional, Dict, Any, List
import asyncio
import time

from .rooms import RoomsRegistry, run_room

@dataclass
class DynamoState:
    running: bool = False
    interval_sec: int = 20
    last_tick_ts: Optional[float] = None
    last_room: Optional[str] = None
    last_status: str = "never"
    last_error: Optional[str] = None
    ticks: int = 0

class DynamoLoop:
    def __init__(self, rooms: RoomsRegistry) -> None:
        self.rooms = rooms
        self.state = DynamoState()
        self._task: Optional[asyncio.Task] = None
        self._lock = asyncio.Lock()
        self._plan: List[str] = ["room_guard", "room_health"]

    async def status(self) -> Dict[str, Any]:
        async with self._lock:
            return asdict(self.state) | {"plan": list(self._plan)}

    async def set_plan(self, plan: List[str]) -> Dict[str, Any]:
        async with self._lock:
            self._plan = plan[:] if plan else self._plan
            return await self.status()

    async def start(self, interval_sec: Optional[int] = None) -> Dict[str, Any]:
        async with self._lock:
            if interval_sec is not None:
                self.state.interval_sec = int(interval_sec)
            if self._task and not self._task.done():
                self.state.running = True
                return asdict(self.state)
            self.state.running = True
            self._task = asyncio.create_task(self._run_forever())
            return asdict(self.state)

    async def stop(self) -> Dict[str, Any]:
        async with self._lock:
            self.state.running = False
            t = self._task
        if t and not t.done():
            t.cancel()
            try:
                await t
            except Exception:
                pass
        async with self._lock:
            return asdict(self.state)

    async def _tick(self) -> None:
        # rotate rooms
        plan = list(self._plan) if self._plan else ["room_health"]
        rid = plan[self.state.ticks % len(plan)]
        self.state.last_room = rid
        self.state.last_tick_ts = time.time()
        self.state.last_status = "running"
        self.state.last_error = None
        await run_room(self.rooms, rid)
        self.state.last_status = "ok"
        self.state.ticks += 1

    async def _run_forever(self) -> None:
        while True:
            async with self._lock:
                if not self.state.running:
                    break
                interval = max(5, int(self.state.interval_sec))
            try:
                await self._tick()
            except asyncio.CancelledError:
                break
            except Exception as e:
                async with self._lock:
                    self.state.last_status = "fail"
                    self.state.last_error = repr(e)
            await asyncio.sleep(interval)
