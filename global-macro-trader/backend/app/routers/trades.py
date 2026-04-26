from typing import List, Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.trade import Trade, TradeStatus
from app.schemas.trade import TradeRead

router = APIRouter(tags=["trades"])


@router.get("/trades", response_model=List[TradeRead])
def list_trades(
    status: Optional[str] = Query(None, description="Filter by status: OPEN, CLOSED, CANCELLED"),
    limit: int = Query(200, le=500),
    db: Session = Depends(get_db),
):
    query = select(Trade).order_by(Trade.opened_at.desc()).limit(limit)
    if status:
        query = query.where(Trade.status == status.upper())
    rows = db.execute(query).scalars().all()
    return rows
