import logging
import time
from typing import Optional

from sqlalchemy.orm import Session

from app.models.analysis import MacroAnalysis, RiskRegime
from app.models.signal import Signal

logger = logging.getLogger(__name__)

# Pairs to consider for each currency pair formation
MAJOR_PAIRS = {
    "EURUSD": ("EUR", "USD"),
    "GBPUSD": ("GBP", "USD"),
    "USDJPY": ("USD", "JPY"),
    "AUDUSD": ("AUD", "USD"),
    "NZDUSD": ("NZD", "USD"),
    "USDCAD": ("USD", "CAD"),
    "USDCHF": ("USD", "CHF"),
    "EURGBP": ("EUR", "GBP"),
    "EURJPY": ("EUR", "JPY"),
    "GBPJPY": ("GBP", "JPY"),
}

CONFIDENCE_THRESHOLD = 0.55
MIN_SCORE_DIFF = 0.3
DEFAULT_SL_PIPS = 50
DEFAULT_TP_MULTIPLIER = 1.5
DEFAULT_PIP_VALUE = 10.0  # USD per pip per standard lot (EURUSD approximation)


class SignalGenerator:
    def run_full_cycle(self, db: Session, news_items: list[dict], llm_result: dict) -> MacroAnalysis:
        from app.services.risk_manager import RiskManager
        from app.config import settings

        start = time.time()

        analysis = MacroAnalysis(
            risk_regime=llm_result["risk_regime"],
            currency_scores=llm_result["currency_scores"],
            llm_summary=llm_result["summary"],
            llm_driver=llm_result["driver"],
            news_items_count=len(news_items),
            raw_news=news_items[:20],
        )
        db.add(analysis)
        db.flush()

        signals = self._generate_signals(analysis)
        for signal in signals:
            signal.analysis_id = analysis.id
            db.add(signal)

        analysis.cycle_duration_seconds = time.time() - start
        db.commit()
        db.refresh(analysis)
        return analysis

    def _generate_signals(self, analysis: MacroAnalysis) -> list[Signal]:
        scores = analysis.currency_scores or {}
        regime = analysis.risk_regime
        signals = []

        for pair, (base, quote) in MAJOR_PAIRS.items():
            base_score = scores.get(base, 0.0)
            quote_score = scores.get(quote, 0.0)
            diff = base_score - quote_score

            if abs(diff) < MIN_SCORE_DIFF:
                continue

            # In NEUTRAL regime, only take high-conviction signals
            if regime == RiskRegime.NEUTRAL and abs(diff) < 0.5:
                continue

            direction = "BUY" if diff > 0 else "SELL"
            confidence = min(0.95, 0.5 + abs(diff) * 0.4)

            if confidence < CONFIDENCE_THRESHOLD:
                continue

            signal = self._build_signal(pair, direction, confidence, abs(diff))
            signals.append(signal)

        return signals

    def _build_signal(
        self, symbol: str, direction: str, confidence: float, score_diff: float
    ) -> Signal:
        base_price = self._get_placeholder_price(symbol)
        pip_size = 0.0001 if "JPY" not in symbol else 0.01
        sl_pips = DEFAULT_SL_PIPS
        tp_pips = sl_pips * DEFAULT_TP_MULTIPLIER
        risk_reward = DEFAULT_TP_MULTIPLIER

        if direction == "BUY":
            stop_loss = round(base_price - sl_pips * pip_size, 5)
            take_profit = round(base_price + tp_pips * pip_size, 5)
        else:
            stop_loss = round(base_price + sl_pips * pip_size, 5)
            take_profit = round(base_price - tp_pips * pip_size, 5)

        lot_size = self._compute_lot_size(
            equity=10000.0,
            risk_pct=1.0,
            sl_pips=sl_pips,
        )

        return Signal(
            symbol=symbol,
            direction=direction,
            entry_price=base_price,
            stop_loss=stop_loss,
            take_profit=take_profit,
            lot_size=lot_size,
            confidence=round(confidence, 3),
            risk_reward=risk_reward,
        )

    @staticmethod
    def _compute_lot_size(equity: float, risk_pct: float, sl_pips: float) -> float:
        risk_amount = equity * (risk_pct / 100)
        lot_size = risk_amount / (sl_pips * DEFAULT_PIP_VALUE)
        return round(max(0.01, min(lot_size, 100.0)), 2)

    @staticmethod
    def _get_placeholder_price(symbol: str) -> float:
        prices = {
            "EURUSD": 1.08500,
            "GBPUSD": 1.27000,
            "USDJPY": 149.500,
            "AUDUSD": 0.65000,
            "NZDUSD": 0.60000,
            "USDCAD": 1.36000,
            "USDCHF": 0.91000,
            "EURGBP": 0.85400,
            "EURJPY": 162.200,
            "GBPJPY": 190.000,
        }
        return prices.get(symbol, 1.00000)


signal_generator = SignalGenerator()
