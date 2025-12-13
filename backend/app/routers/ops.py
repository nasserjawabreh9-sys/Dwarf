import os, subprocess, shlex
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.core.config import settings
from app.services.store import read_settings

router = APIRouter(tags=["ops"])

def require_edit_key(key: str):
    store = read_settings(settings.station_root)
    expected = store.get("edit_mode_key") or settings.edit_mode_key
    if settings.require_edit_key_for_ops and key != expected:
        raise HTTPException(status_code=403, detail="Edit mode key required")

class OpsIn(BaseModel):
    edit_mode_key: str
    message: str | None = "station ops"

@router.get("/api/ops/git/status")
def git_status():
    root = os.path.expanduser(settings.station_root) or os.path.expanduser("~/station_root")
    r = subprocess.run(["bash","-lc", f"cd {shlex.quote(root)} && git status -sb || true"], capture_output=True, text=True)
    return {"ok": True, "out": r.stdout[-4000:]}

@router.post("/api/ops/git/push")
def git_push(p: OpsIn):
    require_edit_key(p.edit_mode_key)
    root = os.path.expanduser(settings.station_root) or os.path.expanduser("~/station_root")
    cmd = f"""
    set -e
    cd {shlex.quote(root)}
    git add -A
    git commit -m {shlex.quote(p.message)} || true
    git push -u origin main
    """
    r = subprocess.run(["bash","-lc", cmd], capture_output=True, text=True)
    if r.returncode != 0:
        raise HTTPException(status_code=500, detail=(r.stderr[-2000:] or r.stdout[-2000:]))
    return {"ok": True, "out": (r.stdout[-4000:] or "pushed")}

@router.post("/api/ops/render/ping")
def render_ping(p: OpsIn):
    require_edit_key(p.edit_mode_key)
    store = read_settings(settings.station_root)
    api = store.get("render_api_key","")
    if not api:
        raise HTTPException(status_code=400, detail="render_api_key missing in settings")
    import requests
    resp = requests.get("https://api.render.com/v1/services", headers={"Authorization": f"Bearer {api}"}, timeout=20)
    ct = resp.headers.get("content-type","")
    data = resp.json() if ct.startswith("application/json") else {"text": resp.text[:300]}
    return {"ok": True, "status": resp.status_code, "sample": data[:1] if isinstance(data, list) else data}
