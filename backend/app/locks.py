import time, os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOCK_DIR = ROOT / "station_meta" / "locks"
LOCK_DIR.mkdir(parents=True, exist_ok=True)

class GlobalLock:
    def __init__(self, name: str, ttl: float = 10.0):
        self.path = LOCK_DIR / f"{name}.lock"
        self.ttl = float(ttl)

    def acquire(self) -> bool:
        now = time.time()
        if self.path.exists():
            try:
                ts = float(self.path.read_text().strip() or 0)
                if now - ts < self.ttl:
                    return False
            except Exception:
                pass
        try:
            self.path.write_text(str(now))
            return True
        except Exception:
            return False

    def release(self):
        try:
            self.path.unlink(missing_ok=True)
        except Exception:
            pass
