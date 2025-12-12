from starlette.responses import JSONResponse
from starlette.requests import Request
from starlette.routing import Route

from app.settings_store import expected_edit_key
from app.guards import require_room

# Console commands are aliases to ops_run_cmd allowlist keys
# This endpoint is a "Termux-like" console surface but stays safe by design.
ALIAS = {
  "pwd": "pwd",
  "ls": "ls",
  "git status": "git_status",
  "git log": "git_log",
}

def _auth_ok(request: Request) -> bool:
  got = (request.headers.get("X-Edit-Key") or "").strip()
  return got != "" and got == expected_edit_key()

@require_room("ops")
async def post_console(request: Request):
  if not _auth_ok(request):
    return JSONResponse({"ok": False, "error": "forbidden"}, status_code=403)

  body = {}
  try:
    body = await request.json()
  except Exception:
    body = {}

  line = (body.get("line") or "").strip()
  if not line:
    return JSONResponse({"ok": False, "error": "empty_line"}, status_code=400)

  # map to allowed ops cmd
  cmd = ALIAS.get(line)
  if not cmd:
    return JSONResponse({"ok": False, "error": "alias_not_allowed", "allowed": sorted(ALIAS.keys())}, status_code=400)

  # Import ops_run_cmd handler logic locally (no subprocess duplication)
  from app.routes.ops_run_cmd import ALLOWED
  import subprocess
  from pathlib import Path

  if cmd not in ALLOWED:
    return JSONResponse({"ok": False, "error": "cmd_not_allowed"}, status_code=400)

  try:
    p = subprocess.run(
      ALLOWED[cmd],
      capture_output=True,
      text=True,
      cwd=str(Path(__file__).resolve().parents[3])
    )
    return JSONResponse({
      "ok": True,
      "line": line,
      "cmd": cmd,
      "returncode": p.returncode,
      "stdout": (p.stdout or "")[-6000:],
      "stderr": (p.stderr or "")[-6000:]
    })
  except Exception as e:
    return JSONResponse({"ok": False, "error": str(e)}, status_code=500)

routes = [
  Route("/api/console", post_console, methods=["POST"]),
]
