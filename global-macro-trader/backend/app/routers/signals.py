from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models.signal import Signal, SignalStatus
from app.models.trade import Trade
from app.schemas.signal import SignalRead
from app.services.mt5_service import mt5_service
from app.services.risk_manager import RiskManager
from app.services.trading_guard import TradingGuard

router = APIRouter(tags=["signals"])


def _get_signal_or_404(signal_id: int, db: Session) -> Signal:
    signal = db.get(Signal, signal_id)
    if signal is None:
        raise HTTPException(status_code=404, detail="Signal not found")
    return signal


@router.get("/signals", response_model=List[SignalRead])
def list_signals(db: Session = Depends(get_db)):
    rows = db.execute(
        select(Signal).order_by(Signal.created_at.desc()).limit(200)
    ).scalars().all()
    return rows


@router.post("/signals/{signal_id}/approve")
def approve_signal(signal_id: int, db: Session = Depends(get_db)):
    signal = _get_signal_or_404(signal_id, db)
    if signal.status != SignalStatus.PENDING:
        raise HTTPException(status_code=400, detail=f"Signal status is {signal.status}, not PENDING")
    signal.status = SignalStatus.APPROVED
    risk_mgr = RiskManager(settings, db)
    risk_mgr.write_audit("SIGNAL_APPROVED", signal=signal, actor="user")
    db.commit()
    return {"ok": True, "signal_id": signal_id}


@router.post("/signals/{signal_id}/reject")
def reject_signal(signal_id: int, db: Session = Depends(get_db)):
    signal = _get_signal_or_404(signal_id, db)
    if signal.status not in (SignalStatus.PENDING, SignalStatus.APPROVED):
        raise HTTPException(
            status_code=400,
            detail=f"Signal status is {signal.status}, cannot reject"
        )
    signal.status = SignalStatus.REJECTED
    risk_mgr = RiskManager(settings, db)
    risk_mgr.write_audit("SIGNAL_REJECTED", signal=signal, actor="user")
    db.commit()
    return {"ok": True, "signal_id": signal_id}


@router.post("/signals/{signal_id}/send-demo")
def send_signal_to_demo(signal_id: int, db: Session = Depends(get_db)):
    guard = TradingGuard(settings)
    guard.assert_can_send_demo()

    signal = _get_signal_or_404(signal_id, db)
    if signal.status != SignalStatus.APPROVED:
        raise HTTPException(
            status_code=400,
            detail=f"Signal must be APPROVED before sending to demo (current: {signal.status})"
        )

    risk_mgr = RiskManager(settings, db)
    result = risk_mgr.check_signal(signal)
    if not result.passed:
        risk_mgr.write_audit(
            "ORDER_BLOCKED_RISK",
            signal=signal,
            details={"reasons": result.reasons},
        )
        raise HTTPException(status_code=422, detail={"reasons": result.reasons})

    trade = mt5_service.send_order(signal, is_demo=True)
    db.add(trade)
    db.flush()

    signal.status = SignalStatus.SENT_DEMO
    risk_mgr.write_audit(
        "ORDER_SENT_DEMO",
        signal=signal,
        trade_id=trade.id,
        details={"symbol": signal.symbol, "direction": signal.direction},
        actor="user",
    )
    db.commit()
    return {"ok": True, "signal_id": signal_id, "trade_id": trade.id}
