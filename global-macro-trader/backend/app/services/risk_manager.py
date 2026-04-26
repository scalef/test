from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.config import Settings
from app.models.audit_log import AuditLog
from app.models.app_settings import AppSettings
from app.models.signal import Signal
from app.models.trade import Trade, TradeStatus


@dataclass
class RiskCheckResult:
    passed: bool
    reasons: list[str] = field(default_factory=list)


class RiskManager:
    def __init__(self, settings: Settings, db: Session):
        self._settings = settings
        self._db = db

    def _get_app_settings(self) -> AppSettings:
        row = self._db.get(AppSettings, 1)
        if row is None:
            row = AppSettings()
        return row

    def _count_open_trades(self) -> int:
        result = self._db.execute(
            select(func.count()).where(Trade.status == TradeStatus.OPEN)
        )
        return result.scalar_one()

    def _count_open_trades_for_symbol(self, symbol: str) -> int:
        result = self._db.execute(
            select(func.count()).where(
                Trade.status == TradeStatus.OPEN, Trade.symbol == symbol
            )
        )
        return result.scalar_one()

    def _get_daily_pnl(self) -> float:
        today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
        result = self._db.execute(
            select(func.coalesce(func.sum(Trade.pnl), 0.0)).where(
                Trade.closed_at >= today_start,
                Trade.status == TradeStatus.CLOSED,
                Trade.pnl.isnot(None),
            )
        )
        return float(result.scalar_one())

    def check_signal(
        self,
        signal: Signal,
        account_equity: float = 10000.0,
    ) -> RiskCheckResult:
        app_settings = self._get_app_settings()
        reasons: list[str] = []

        # Symbol whitelist
        if app_settings.allowed_symbols and signal.symbol not in app_settings.allowed_symbols:
            reasons.append(f"SYMBOL_NOT_ALLOWED: {signal.symbol}")

        # Max open trades
        open_count = self._count_open_trades()
        if open_count >= app_settings.max_open_trades:
            reasons.append(f"MAX_OPEN_TRADES_REACHED: {open_count}/{app_settings.max_open_trades}")

        # Max per symbol
        symbol_count = self._count_open_trades_for_symbol(signal.symbol)
        if symbol_count >= app_settings.max_trades_per_symbol:
            reasons.append(
                f"MAX_SYMBOL_TRADES_REACHED: {symbol_count}/{app_settings.max_trades_per_symbol}"
            )

        # Daily drawdown (PnL in account currency as % of equity)
        daily_pnl = self._get_daily_pnl()
        daily_dd_pct = (daily_pnl / account_equity * 100) if account_equity > 0 else 0
        if daily_dd_pct < -app_settings.max_daily_drawdown_pct:
            reasons.append(
                f"DAILY_DRAWDOWN_EXCEEDED: {daily_dd_pct:.2f}% > -{app_settings.max_daily_drawdown_pct}%"
            )

        return RiskCheckResult(passed=len(reasons) == 0, reasons=reasons)

    def write_audit(
        self,
        action: str,
        signal: Optional[Signal] = None,
        trade_id: Optional[int] = None,
        details: Optional[dict] = None,
        actor: str = "system",
    ) -> None:
        log = AuditLog(
            action=action,
            signal_id=signal.id if signal else None,
            trade_id=trade_id,
            actor=actor,
            details=details or {},
            trading_mode=self._settings.trading_mode.value,
            emergency_stop_active=self._settings.emergency_stop,
        )
        self._db.add(log)
        self._db.commit()
