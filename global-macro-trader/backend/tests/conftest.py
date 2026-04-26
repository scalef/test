import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base
from app.config import Settings, TradingMode
from app.models.app_settings import AppSettings


@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()

    # Seed default app settings row
    row = AppSettings(id=1)
    session.add(row)
    session.commit()

    yield session
    session.close()
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def signal_only_settings():
    return Settings(
        trading_mode=TradingMode.SIGNAL_ONLY,
        allow_live_trading=False,
        emergency_stop=False,
        database_url="sqlite:///:memory:",
    )


@pytest.fixture
def demo_settings():
    return Settings(
        trading_mode=TradingMode.DEMO,
        allow_live_trading=False,
        emergency_stop=False,
        database_url="sqlite:///:memory:",
    )


@pytest.fixture
def live_settings():
    return Settings(
        trading_mode=TradingMode.LIVE,
        allow_live_trading=True,
        emergency_stop=False,
        database_url="sqlite:///:memory:",
    )


@pytest.fixture
def emergency_stopped_settings():
    return Settings(
        trading_mode=TradingMode.DEMO,
        allow_live_trading=False,
        emergency_stop=True,
        database_url="sqlite:///:memory:",
    )


@pytest.fixture
def sample_signal():
    from app.models.signal import Signal
    return Signal(
        id=1,
        symbol="EURUSD",
        direction="BUY",
        entry_price=1.08500,
        stop_loss=1.08000,
        take_profit=1.09250,
        lot_size=0.02,
        confidence=0.75,
        risk_reward=1.5,
    )
