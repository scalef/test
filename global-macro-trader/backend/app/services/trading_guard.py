from fastapi import HTTPException

from app.config import Settings, TradingMode


class TradingGuard:
    """
    Safety gate. Every order execution path MUST call assert_can_send_demo()
    or assert_can_send_live() before touching the MT5 connector.
    """

    def __init__(self, settings: Settings):
        self._settings = settings

    def can_send_demo(self) -> tuple[bool, str]:
        if self._settings.emergency_stop:
            return False, "EMERGENCY_STOP_ACTIVE"
        if self._settings.trading_mode == TradingMode.SIGNAL_ONLY:
            return False, "MODE_IS_SIGNAL_ONLY"
        return True, "OK"

    def can_send_live(self) -> tuple[bool, str]:
        if self._settings.emergency_stop:
            return False, "EMERGENCY_STOP_ACTIVE"
        if self._settings.trading_mode != TradingMode.LIVE:
            return False, f"MODE_IS_{self._settings.trading_mode.value}_NOT_LIVE"
        if not self._settings.allow_live_trading:
            return False, "LIVE_NOT_ALLOWED_WITHOUT_ALLOW_LIVE_TRADING_FLAG"
        return True, "OK"

    def assert_can_send_demo(self) -> None:
        allowed, reason = self.can_send_demo()
        if not allowed:
            raise HTTPException(status_code=403, detail=f"Order blocked: {reason}")

    def assert_can_send_live(self) -> None:
        allowed, reason = self.can_send_live()
        if not allowed:
            raise HTTPException(status_code=403, detail=f"Order blocked: {reason}")
