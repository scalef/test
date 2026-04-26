import pytest
from app.models.analysis import MacroAnalysis, RiskRegime
from app.services.signal_generator import SignalGenerator
from app.services.llm_service import CURRENCIES


@pytest.fixture
def generator():
    return SignalGenerator()


@pytest.fixture
def risk_on_llm_result():
    return {
        "risk_regime": "RISK_ON",
        "currency_scores": {
            "USD": -0.3,
            "EUR": 0.2,
            "GBP": 0.6,
            "JPY": -0.8,
            "AUD": 0.7,
            "NZD": 0.5,
            "CAD": 0.1,
            "CHF": -0.4,
        },
        "summary": "Risk-on environment driven by strong global growth data.",
        "driver": "Fed rate cut expectations",
    }


@pytest.fixture
def risk_off_llm_result():
    return {
        "risk_regime": "RISK_OFF",
        "currency_scores": {
            "USD": 0.5,
            "EUR": -0.2,
            "GBP": -0.5,
            "JPY": 0.9,
            "AUD": -0.7,
            "NZD": -0.6,
            "CAD": -0.1,
            "CHF": 0.6,
        },
        "summary": "Risk-off driven by geopolitical tensions.",
        "driver": "Geopolitical risk",
    }


@pytest.fixture
def neutral_llm_result():
    return {
        "risk_regime": "NEUTRAL",
        "currency_scores": {c: 0.0 for c in CURRENCIES},
        "summary": "No clear direction.",
        "driver": "Mixed signals",
    }


def test_risk_on_generates_signals(db, generator, risk_on_llm_result):
    analysis = generator.run_full_cycle(db, news_items=[], llm_result=risk_on_llm_result)
    assert analysis.risk_regime == RiskRegime.RISK_ON
    assert len(analysis.signals) > 0


def test_risk_off_generates_signals(db, generator, risk_off_llm_result):
    analysis = generator.run_full_cycle(db, news_items=[], llm_result=risk_off_llm_result)
    assert analysis.risk_regime == RiskRegime.RISK_OFF
    assert len(analysis.signals) > 0


def test_neutral_flat_scores_no_signals(db, generator, neutral_llm_result):
    analysis = generator.run_full_cycle(db, news_items=[], llm_result=neutral_llm_result)
    assert analysis.risk_regime == RiskRegime.NEUTRAL
    assert len(analysis.signals) == 0


def test_signals_have_required_fields(db, generator, risk_on_llm_result):
    analysis = generator.run_full_cycle(db, news_items=[], llm_result=risk_on_llm_result)
    for signal in analysis.signals:
        assert signal.symbol
        assert signal.direction in ("BUY", "SELL")
        assert signal.entry_price > 0
        assert signal.stop_loss > 0
        assert signal.take_profit > 0
        assert 0 < signal.confidence <= 1.0
        assert signal.risk_reward > 0
        assert signal.lot_size >= 0.01


def test_buy_signal_tp_above_entry(db, generator, risk_on_llm_result):
    analysis = generator.run_full_cycle(db, news_items=[], llm_result=risk_on_llm_result)
    for signal in analysis.signals:
        if signal.direction == "BUY":
            assert signal.take_profit > signal.entry_price
            assert signal.stop_loss < signal.entry_price


def test_sell_signal_tp_below_entry(db, generator, risk_off_llm_result):
    analysis = generator.run_full_cycle(db, news_items=[], llm_result=risk_off_llm_result)
    for signal in analysis.signals:
        if signal.direction == "SELL":
            assert signal.take_profit < signal.entry_price
            assert signal.stop_loss > signal.entry_price


def test_lot_size_calculation():
    lot = SignalGenerator._compute_lot_size(equity=10000.0, risk_pct=1.0, sl_pips=50)
    expected = (10000.0 * 0.01) / (50 * 10.0)  # = 0.20
    assert abs(lot - expected) < 0.01


def test_lot_size_minimum():
    lot = SignalGenerator._compute_lot_size(equity=100.0, risk_pct=0.1, sl_pips=100)
    assert lot >= 0.01


def test_lot_size_maximum():
    lot = SignalGenerator._compute_lot_size(equity=10_000_000.0, risk_pct=10.0, sl_pips=1)
    assert lot <= 100.0


def test_cycle_creates_analysis_in_db(db, generator, risk_on_llm_result):
    from sqlalchemy import select
    from app.models.analysis import MacroAnalysis

    analysis = generator.run_full_cycle(db, news_items=[], llm_result=risk_on_llm_result)

    rows = db.execute(select(MacroAnalysis)).scalars().all()
    assert len(rows) == 1
    assert rows[0].id == analysis.id


def test_fallback_analysis_neutral_regime(generator):
    from app.services.llm_service import LLMService
    svc = LLMService()
    result = svc._fallback_analysis("No key")
    assert result["risk_regime"] == "NEUTRAL"
    assert all(v == 0.0 for v in result["currency_scores"].values())
    assert len(result["currency_scores"]) == 8


def test_currency_scores_clamped(generator):
    from app.services.llm_service import LLMService
    svc = LLMService()
    raw = '{"risk_regime":"RISK_ON","currency_scores":{"USD":2.0,"EUR":-3.0,"GBP":0.5,"JPY":-0.5,"AUD":0.0,"NZD":0.0,"CAD":0.0,"CHF":0.0},"summary":"test","driver":"test"}'
    result = svc._parse_response(raw)
    assert result["currency_scores"]["USD"] == 1.0
    assert result["currency_scores"]["EUR"] == -1.0
