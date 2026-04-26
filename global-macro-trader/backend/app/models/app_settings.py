from sqlalchemy import String, Float, Integer, Boolean, JSON
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class AppSettings(Base):
    __tablename__ = "app_settings"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, default=1)

    # Risk
    risk_per_trade_pct: Mapped[float] = mapped_column(Float, nullable=False, default=1.0)
    max_daily_drawdown_pct: Mapped[float] = mapped_column(Float, nullable=False, default=5.0)
    max_total_drawdown_pct: Mapped[float] = mapped_column(Float, nullable=False, default=15.0)
    max_open_trades: Mapped[int] = mapped_column(Integer, nullable=False, default=5)
    max_trades_per_symbol: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    max_spread_points: Mapped[float] = mapped_column(Float, nullable=False, default=20.0)
    allowed_symbols: Mapped[list] = mapped_column(JSON, nullable=False, default=list)

    # Telegram
    telegram_bot_token: Mapped[str] = mapped_column(String(200), nullable=False, default="")
    telegram_chat_id: Mapped[str] = mapped_column(String(100), nullable=False, default="")

    # MT5
    mt5_login: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    mt5_password: Mapped[str] = mapped_column(String(200), nullable=False, default="")
    mt5_server: Mapped[str] = mapped_column(String(200), nullable=False, default="")
    mt5_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    # LLM
    llm_provider: Mapped[str] = mapped_column(String(50), nullable=False, default="openai")
    llm_api_key: Mapped[str] = mapped_column(String(500), nullable=False, default="")
    llm_model: Mapped[str] = mapped_column(String(100), nullable=False, default="gpt-4o")

    # RSS
    rss_sources: Mapped[list] = mapped_column(JSON, nullable=False, default=list)

    # Scheduler
    scheduler_interval_seconds: Mapped[int] = mapped_column(Integer, nullable=False, default=300)

    # Runtime state (persisted across restarts)
    emergency_stop: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    trading_mode: Mapped[str] = mapped_column(String(20), nullable=False, default="SIGNAL_ONLY")
