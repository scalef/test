from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models.trade import Trade, TradeStatus
from app.schemas.settings import StatusRead
from app.services.mt5_service import mt5_service
from app.services.scheduler_service import scheduler_service

router = APIRouter(tags=["status"])


def _get_daily_pnl(db: Session) -> float:
    from datetime import datetime

    today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    result = db.execute(
        select(func.coalesce(func.sum(Trade.pnl), 0.0)).where(
            Trade.closed_at >= today_start,
            Trade.status == TradeStatus.CLOSED,
            Trade.pnl.isnot(None),
        )
    )
    return float(result.scalar_one())


@router.get("/status", response_model=StatusRead)
def get_status(db: Session = Depends(get_db)):
    account = mt5_service.get_account_info()
    equity = account["equity"]

    open_count = db.execute(
        select(func.count()).where(Trade.status == TradeStatus.OPEN)
    ).scalar_one()

    daily_pnl = _get_daily_pnl(db)
    daily_dd_pct = (daily_pnl / equity * 100) if equity > 0 else 0.0

    return StatusRead(
        trading_mode=settings.trading_mode.value,
        emergency_stop=settings.emergency_stop,
        scheduler_paused=scheduler_service.is_paused,
        last_cycle=scheduler_service.last_run.isoformat() if scheduler_service.last_run else None,
        next_cycle=scheduler_service.next_run.isoformat() if scheduler_service.next_run else None,
        equity=equity,
        daily_drawdown_pct=round(daily_dd_pct, 2),
        open_trades_count=open_count,
        mt5_connected=account["connected"],
    )
