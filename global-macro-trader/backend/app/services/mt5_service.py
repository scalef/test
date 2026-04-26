import logging

from app.config import settings
from app.models.signal import Signal
from app.models.trade import Trade, TradeStatus

logger = logging.getLogger(__name__)


class MT5Service:
    """
    Placeholder MT5 connector. No live orders are sent by default.
    Real MetaTrader5 integration requires Windows + MetaTrader5 Python package.
    Set MT5_ENABLED=true to attempt real connection (not implemented here).
    """

    def __init__(self):
        self._connected = False

    def connect(self) -> bool:
        if not settings.mt5_enabled:
            logger.info("MT5 disabled (MT5_ENABLED=false) — using placeholder")
            return False
        # Real MT5 connection would go here (Windows only)
        logger.warning("MT5_ENABLED=true but real MT5 connection is not implemented in this placeholder")
        return False

    def send_order(self, signal: Signal, is_demo: bool = True) -> Trade:
        """
        Placeholder order execution. Always creates a simulated trade record.
        Real MT5 send_order() would call mt5.order_send() here.
        """
        logger.info(
            "[PLACEHOLDER] MT5 order: %s %s @ %.5f (demo=%s)",
            signal.direction,
            signal.symbol,
            signal.entry_price,
            is_demo,
        )
        trade = Trade(
            signal_id=signal.id,
            mt5_ticket=None,
            symbol=signal.symbol,
            direction=signal.direction,
            lot_size=signal.lot_size,
            entry_price=signal.entry_price,
            stop_loss=signal.stop_loss,
            take_profit=signal.take_profit,
            is_demo=is_demo,
            status=TradeStatus.OPEN,
        )
        return trade

    def get_account_info(self) -> dict:
        """Returns placeholder account info when MT5 is not connected."""
        return {
            "equity": 10000.0,
            "balance": 10000.0,
            "margin": 0.0,
            "free_margin": 10000.0,
            "connected": self._connected,
        }

    def get_open_positions(self) -> list[dict]:
        """Returns empty list when MT5 is not connected."""
        return []


mt5_service = MT5Service()
