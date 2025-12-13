import os, platform, subprocess, pathlib

def _cmd(s: str) -> str:
    try:
        out = subprocess.check_output(s, shell=True, stderr=subprocess.STDOUT, timeout=3)
        return out.decode("utf-8", "ignore").strip()
    except Exception:
        return ""

def doctor(_payload=None):
    root = os.environ.get("STATION_ROOT", str(pathlib.Path.home() / "station_root"))
    return {
        "status": "ok",
        "mode": "termux-safe",
        "python": _cmd("python -V"),
        "node": _cmd("node -v"),
        "npm": _cmd("npm -v"),
        "git": _cmd("git --version"),
        "platform": platform.platform(),
        "root": root
    }
