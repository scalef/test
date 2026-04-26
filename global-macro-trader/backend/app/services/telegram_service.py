import logging
from typing import Optional

import httpx

from app.config import settings

logger = logging.getLogger(__name__)


class TelegramService:
    def _is_configured(self) -> bool:
        return bool(settings.telegram_bot_token and settings.telegram_chat_id)

    def send_message(self, text: str) -> bool:
        if not self._is_configured():
            logger.debug("Telegram not configured — skipping notification")
            return False
        try:
            resp = httpx.post(
                f"https://api.telegram.org/bot{settings.telegram_bot_token}/sendMessage",
                json={
                    "chat_id": settings.telegram_chat_id,
                    "text": text,
                    "parse_mode": "HTML",
                },
                timeout=10.0,
            )
            if resp.status_code != 200:
                logger.warning("Telegram API returned %s: %s", resp.status_code, resp.text)
                return False
            return True
        except Exception as exc:
            logger.error("Telegram send failed: %s", exc)
            return False

    def notify_new_signals(self, signals: list) -> None:
        if not signals:
            return
        lines = [f"<b>New Signals ({len(signals)})</b>"]
        for s in signals:
            lines.append(
                f"• {s.symbol} {s.direction} @ {s.entry_price:.5f} | RR {s.risk_reward:.1f} | conf {s.confidence:.0%}"
            )
        self.send_message("\n".join(lines))

    def notify_emergency_stop(self) -> None:
        self.send_message(
            "<b>🚨 EMERGENCY STOP ACTIVATED</b>\nAll trading has been halted immediately."
        )

    def notify_cycle_complete(self, analysis) -> None:
        self.send_message(
            f"<b>Cycle Complete</b>\n"
            f"Regime: {analysis.risk_regime}\n"
            f"Signals generated: {len(analysis.signals)}\n"
            f"Duration: {analysis.cycle_duration_seconds:.1f}s"
        )


telegram_service = TelegramService()
