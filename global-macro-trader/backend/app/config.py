from enum import Enum
from pydantic_settings import BaseSettings, SettingsConfigDict


class TradingMode(str, Enum):
    SIGNAL_ONLY = "SIGNAL_ONLY"
    DEMO = "DEMO"
    LIVE = "LIVE"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Safety
    trading_mode: TradingMode = TradingMode.SIGNAL_ONLY
    allow_live_trading: bool = False
    emergency_stop: bool = False

    # Database
    database_url: str = "sqlite:///./data/trading.db"

    # Scheduler
    scheduler_interval_seconds: int = 300

    # Telegram
    telegram_bot_token: str = ""
    telegram_chat_id: str = ""

    # MT5
    mt5_login: int = 0
    mt5_password: str = ""
    mt5_server: str = ""
    mt5_enabled: bool = False

    # LLM
    llm_provider: str = "openai"
    llm_api_key: str = ""
    llm_model: str = "gpt-4o"


settings = Settings()
