from fastapi import APIRouter
from ..v1 import system

router = APIRouter(prefix="/v1")
router.include_router(system.router, tags=["system"])
