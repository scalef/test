from fastapi import APIRouter

from app.services.scheduler_service import scheduler_service

router = APIRouter(tags=["scheduler"])


@router.post("/scheduler/pause")
def pause_scheduler():
    scheduler_service.pause()
    return {"ok": True, "paused": True}


@router.post("/scheduler/resume")
def resume_scheduler():
    scheduler_service.resume()
    return {"ok": True, "paused": False}
