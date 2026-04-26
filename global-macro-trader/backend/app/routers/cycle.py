from fastapi import APIRouter

from app.services.scheduler_service import scheduler_service

router = APIRouter(tags=["cycle"])


@router.post("/cycle/run")
def run_cycle():
    scheduler_service.run_now()
    return {"ok": True, "message": "Cycle triggered"}
