import pytest
from app.models.app_settings import AppSettings
from app.models.signal import Signal
from app.models.trade import Trade, TradeStatus
from app.services.risk_manager import RiskManager


def make_signal(symbol="EURUSD", direction="BUY"):
    return Signal(
        symbol=symbol,
        direction=direction,
        entry_price=1.08500,
        stop_loss=1.08000,
        take_profit=1.09250,
        lot_size=0.02,
        confidence=0.75,
        risk_reward=1.5,
    )


def make_closed_trade(symbol="EURUSD", pnl=-100.0):
    from datetime import datetime
    return Trade(
        symbol=symbol,
        direction="BUY",
        lot_size=0.01,
        entry_price=1.085,
        stop_loss=1.080,
        take_profit=1.092,
        is_demo=True,
        status=TradeStatus.CLOSED,
        pnl=pnl,
        closed_at=datetime.utcnow(),
    )


def make_open_trade(symbol="EURUSD"):
    return Trade(
        symbol=symbol,
        direction="BUY",
        lot_size=0.01,
        entry_price=1.085,
        stop_loss=1.080,
        take_profit=1.092,
        is_demo=True,
        status=TradeStatus.OPEN,
    )


# ── TradingGuard tests ──────────────────────────────────────────────────────

def test_signal_only_blocks_demo(signal_only_settings):
    from app.services.trading_guard import TradingGuard
    guard = TradingGuard(signal_only_settings)
    allowed, reason = guard.can_send_demo()
    assert not allowed
    assert reason == "MODE_IS_SIGNAL_ONLY"


def test_signal_only_blocks_live(signal_only_settings):
    from app.services.trading_guard import TradingGuard
    guard = TradingGuard(signal_only_settings)
    allowed, reason = guard.can_send_live()
    assert not allowed


def test_demo_mode_allows_demo(demo_settings):
    from app.services.trading_guard import TradingGuard
    guard = TradingGuard(demo_settings)
    allowed, reason = guard.can_send_demo()
    assert allowed
    assert reason == "OK"


def test_live_mode_without_flag_blocks_live(live_settings):
    from app.config import Settings, TradingMode
    from app.services.trading_guard import TradingGuard
    s = Settings(trading_mode=TradingMode.LIVE, allow_live_trading=False, emergency_stop=False, database_url="sqlite:///:memory:")
    guard = TradingGuard(s)
    allowed, reason = guard.can_send_live()
    assert not allowed
    assert "ALLOW_LIVE_TRADING" in reason


def test_live_mode_with_flag_allows_live(live_settings):
    from app.services.trading_guard import TradingGuard
    guard = TradingGuard(live_settings)
    allowed, reason = guard.can_send_live()
    assert allowed
    assert reason == "OK"


def test_emergency_stop_blocks_demo(emergency_stopped_settings):
    from app.services.trading_guard import TradingGuard
    guard = TradingGuard(emergency_stopped_settings)
    allowed, reason = guard.can_send_demo()
    assert not allowed
    assert reason == "EMERGENCY_STOP_ACTIVE"


def test_emergency_stop_blocks_live(live_settings):
    from app.config import Settings, TradingMode
    from app.services.trading_guard import TradingGuard
    s = Settings(trading_mode=TradingMode.LIVE, allow_live_trading=True, emergency_stop=True, database_url="sqlite:///:memory:")
    guard = TradingGuard(s)
    allowed, reason = guard.can_send_live()
    assert not allowed
    assert reason == "EMERGENCY_STOP_ACTIVE"


# ── RiskManager check_signal tests ──────────────────────────────────────────

def test_check_signal_passes_clean_state(db, demo_settings):
    signal = make_signal()
    rm = RiskManager(demo_settings, db)
    result = rm.check_signal(signal, account_equity=10000.0)
    assert result.passed
    assert result.reasons == []


def test_max_open_trades_blocks(db, demo_settings):
    # Set max_open_trades to 1
    row = db.get(AppSettings, 1)
    row.max_open_trades = 1
    db.add(make_open_trade())
    db.commit()

    signal = make_signal()
    rm = RiskManager(demo_settings, db)
    result = rm.check_signal(signal)
    assert not result.passed
    assert any("MAX_OPEN_TRADES" in r for r in result.reasons)


def test_max_trades_per_symbol_blocks(db, demo_settings):
    row = db.get(AppSettings, 1)
    row.max_trades_per_symbol = 1
    db.add(make_open_trade(symbol="EURUSD"))
    db.commit()

    signal = make_signal(symbol="EURUSD")
    rm = RiskManager(demo_settings, db)
    result = rm.check_signal(signal)
    assert not result.passed
    assert any("MAX_SYMBOL" in r for r in result.reasons)


def test_symbol_not_in_whitelist_blocks(db, demo_settings):
    row = db.get(AppSettings, 1)
    row.allowed_symbols = ["GBPUSD", "USDJPY"]
    db.commit()

    signal = make_signal(symbol="EURUSD")
    rm = RiskManager(demo_settings, db)
    result = rm.check_signal(signal)
    assert not result.passed
    assert any("SYMBOL_NOT_ALLOWED" in r for r in result.reasons)


def test_symbol_in_whitelist_passes(db, demo_settings):
    row = db.get(AppSettings, 1)
    row.allowed_symbols = ["EURUSD", "GBPUSD"]
    db.commit()

    signal = make_signal(symbol="EURUSD")
    rm = RiskManager(demo_settings, db)
    result = rm.check_signal(signal, account_equity=10000.0)
    assert result.passed


def test_daily_drawdown_blocks(db, demo_settings):
    row = db.get(AppSettings, 1)
    row.max_daily_drawdown_pct = 2.0  # 2% max
    db.commit()

    # Add enough losing trades to exceed 2% of 10000 equity = $200 loss
    for _ in range(3):
        db.add(make_closed_trade(pnl=-100.0))
    db.commit()

    signal = make_signal()
    rm = RiskManager(demo_settings, db)
    result = rm.check_signal(signal, account_equity=10000.0)
    assert not result.passed
    assert any("DAILY_DRAWDOWN" in r for r in result.reasons)


def test_empty_whitelist_allows_all_symbols(db, demo_settings):
    # allowed_symbols=[] means no restriction
    row = db.get(AppSettings, 1)
    row.allowed_symbols = []
    db.commit()

    signal = make_signal(symbol="EURUSD")
    rm = RiskManager(demo_settings, db)
    result = rm.check_signal(signal)
    assert result.passed
