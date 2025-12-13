from fastapi import APIRouter
from pydantic import BaseModel
from app.state.rooms import snapshot, patch

router = APIRouter(tags=["rooms"])

@router.get("/api/rooms")
def get_rooms():
    return snapshot()

class PatchIn(BaseModel):
    rooms: dict | None = None
    guards: dict | None = None

@router.post("/api/rooms")
def patch_rooms(p: PatchIn):
    return patch(p.model_dump(exclude_none=True))
