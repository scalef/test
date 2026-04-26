from typing import List, Optional

from pydantic import BaseModel, ConfigDict, field_validator


class RiskSettingsUpdate(BaseModel):
    risk_per_trade_pct: Optional[float] = None
    max_daily_drawdown_pct: Optional[float] = None
    max_total_drawdown_pct: Optional[float] = None
    max_open_trades: Optional[int] = None
    max_trades_per_symbol: Optional[int] = None
    max_spread_points: Optional[float] = None
    allowed_symbols: Optional[List[str]] = None

    @field_validator("risk_per_trade_pct")
    @classmethod
    def validate_risk(cls, v: Optional[float]) -> Optional[float]:
        if v is not None and not (0.01 <= v <= 10.0):
            raise ValueError("risk_per_trade_pct must be between 0.01 and 10")
        return v


class TelegramConfig(BaseModel):
    telegram_bot_token: Optional[str] = None
    telegram_chat_id: Optional[str] = None


class MT5Config(BaseModel):
    mt5_login: Optional[int] = None
    mt5_password: Optional[str] = None
    mt5_server: Optional[str] = None
    mt5_enabled: Optional[bool] = None


class LLMConfig(BaseModel):
    llm_provider: Optional[str] = None
    llm_api_key: Optional[str] = None
    llm_model: Optional[str] = None


class SchedulerConfig(BaseModel):
    scheduler_interval_seconds: Optional[int] = None


class AllSettingsUpdate(
    RiskSettingsUpdate, TelegramConfig, MT5Config, LLMConfig, SchedulerConfig
):
    rss_sources: Optional[List[str]] = None
    trading_mode: Optional[str] = None


class AllSettingsRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    risk_per_trade_pct: float
    max_daily_drawdown_pct: float
    max_total_drawdown_pct: float
    max_open_trades: int
    max_trades_per_symbol: int
    max_spread_points: float
    allowed_symbols: List[str]

    telegram_bot_token: str
    telegram_chat_id: str

    mt5_login: int
    mt5_password: str
    mt5_server: str
    mt5_enabled: bool

    llm_provider: str
    llm_api_key: str
    llm_model: str

    rss_sources: List[str]
    scheduler_interval_seconds: int
    trading_mode: str
    emergency_stop: bool

    def model_post_init(self, __context: object) -> None:
        # Mask sensitive fields
        if self.mt5_password:
            object.__setattr__(self, "mt5_password", "***")
        if self.llm_api_key:
            object.__setattr__(self, "llm_api_key", "***")
        if self.telegram_bot_token:
            object.__setattr__(self, "telegram_bot_token", "***")


class StatusRead(BaseModel):
    trading_mode: str
    emergency_stop: bool
    scheduler_paused: bool
    last_cycle: Optional[str]
    next_cycle: Optional[str]
    equity: float
    daily_drawdown_pct: float
    open_trades_count: int
    mt5_connected: bool
