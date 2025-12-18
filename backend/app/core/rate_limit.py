import time
from typing import Dict, Tuple

class SimpleRateLimiter:
    """
    In-memory rate limiter (per-process).
    Good enough for MVP/enterprise-lock baseline.
    For multi-instance production, swap to Redis later.
    """
    def __init__(self, rpm: int):
        self.rpm = max(1, rpm)
        self.window = 60.0
        self.buckets: Dict[str, Tuple[float, int]] = {}

    def allow(self, key: str) -> bool:
        now = time.time()
        start, count = self.buckets.get(key, (now, 0))
        if now - start >= self.window:
            start, count = now, 0
        count += 1
        self.buckets[key] = (start, count)
        return count <= self.rpm
