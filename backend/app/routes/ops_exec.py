import os, json, time, subprocess
from pathlib import Path
from starlette.responses import JSONResponse
from starlette.requests import Request
from starlette.routing import Route
from app.uui_store import expected_edit_key

ROOT = Path(__file__).resolve().parents[2]
LOG = ROOT / "backend" / "app" / "ops_logs" / "ops_exec.log.jsonl"
LOG.parent.mkdir(parents=True, exist_ok=True)

ALLOW = {
    "pwd": ["pwd"],
    "ls": ["ls", "-la"],
    "git_status": ["git", "status"],
    "git_log": ["git", "--no-pager", "log", "-n", "20", "--oneline"],
    "backend_health_curl": ["curl", "-sS", "http://127.0.0.1:8000/health"],
    "frontend_pkg": ["bash", "-lc", "cd frontend && npm -v && node -v"],
}

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

def _auth_ok(request: Request) -> bool:
    got = (request.headers.get("X-Edit-Key") or "").strip()
    return got != "" and got == expected_edit_key()

async def exec_cmd(request: Request):
    if not _auth_ok(request):
        return JSONResponse({"ok": False, "error": "forbidden"}, status_code=403)

    body={}
    try: body=await request.json()
    except Exception: body={}

    name = str(body.get("name") or "").strip()
    if name not in ALLOW:
        return JSONResponse({"ok": False, "error": "not_allowed", "allowed": sorted(ALLOW.keys())}, status_code=400)

    cmd = ALLOW[name]
    cwd = str(body.get("cwd") or str(ROOT)).strip()
    if not cwd:
        cwd = str(ROOT)

    entry = {"ts": now_iso(), "name": name, "cmd": cmd, "cwd": cwd}
    try:
        p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=20)
        entry["rc"] = p.returncode
        entry["stdout"] = (p.stdout or "")[:8000]
        entry["stderr"] = (p.stderr or "")[:8000]
    except Exception as e:
        entry["rc"] = -1
        entry["stderr"] = str(e)

    with LOG.open("a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")

    return JSONResponse({"ok": True, "entry": entry, "allowed": sorted(ALLOW.keys())})

async def allowed(request: Request):
    return JSONResponse({"ok": True, "allowed": sorted(ALLOW.keys()), "note": "Exec requires X-Edit-Key"})

routes = [
    Route("/api/ops/allowed", allowed, methods=["GET"]),
    Route("/api/ops/exec", exec_cmd, methods=["POST"]),
]
