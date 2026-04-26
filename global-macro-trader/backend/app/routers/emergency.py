from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models.app_settings import AppSettings
from app.models.audit_log import AuditLog
from app.services.telegram_service import telegram_service

router = APIRouter(tags=["emergency"])


@router.post("/emergency-stop")
def emergency_stop(db: Session = Depends(get_db)):
    # Mutate singleton immediately so all in-flight requests see it
    settings.emergency_stop = True

    # Persist to DB so it survives restarts
    row = db.get(AppSettings, 1)
    if row:
        row.emergency_stop = True

    log = AuditLog(
        action="EMERGENCY_STOP_ACTIVATED",
        actor="user",
        details={"previous_mode": settings.trading_mode.value},
        trading_mode=settings.trading_mode.value,
        emergency_stop_active=True,
    )
    db.add(log)
    db.commit()

    telegram_service.notify_emergency_stop()

    return {"ok": True, "emergency_stop": True}
