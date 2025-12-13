from fastapi import APIRouter
from pydantic import BaseModel
from app.state.dynamo import tick, get_state, add_event

router = APIRouter(tags=["dynamo"])

@router.get("/api/dynamo")
def dynamo_state():
    return get_state()

class TickIn(BaseModel):
    meta: dict | None = None

@router.post("/api/dynamo/tick")
def dynamo_tick(t: TickIn):
    return tick(t.meta or {})

class EvIn(BaseModel):
    kind: str
    payload: dict = {}

@router.post("/api/dynamo/event")
def dynamo_event(e: EvIn):
    return add_event(e.kind, e.payload)
