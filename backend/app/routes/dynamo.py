from starlette.responses import JSONResponse
from starlette.requests import Request
from starlette.routing import Route
from app.uui_store import expected_edit_key
from app import dynamo_core

def _auth_ok(request: Request) -> bool:
    got = (request.headers.get("X-Edit-Key") or "").strip()
    return got != "" and got == expected_edit_key()

async def dyn_status(request: Request):
    return JSONResponse(dynamo_core.status())

async def dyn_submit(request: Request):
    if not _auth_ok(request):
        return JSONResponse({"ok": False, "error": "forbidden"}, status_code=403)
    body = {}
    try:
        body = await request.json()
    except Exception:
        body = {}
    room = (body.get("room") or "core").strip()
    ttype = (body.get("type") or "ping").strip()
    payload = body.get("payload") or {}
    t = dynamo_core.submit(room, ttype, payload)
    return JSONResponse({"ok": True, "task": t})

async def dyn_run_next(request: Request):
    if not _auth_ok(request):
        return JSONResponse({"ok": False, "error": "forbidden"}, status_code=403)
    t = dynamo_core.run_next()
    if not t:
        return JSONResponse({"ok": True, "note": "queue_empty"})
    return JSONResponse({"ok": True, "task": t})

async def dyn_tasks(request: Request):
    lim = 50
    try:
        lim = int(request.query_params.get("limit") or "50")
    except Exception:
        lim = 50
    return JSONResponse({"ok": True, "tasks": dynamo_core.list_tasks(lim)})

routes = [
    Route("/api/dynamo/status", dyn_status, methods=["GET"]),
    Route("/api/dynamo/submit", dyn_submit, methods=["POST"]),
    Route("/api/dynamo/run_next", dyn_run_next, methods=["POST"]),
    Route("/api/dynamo/tasks", dyn_tasks, methods=["GET"]),
]
