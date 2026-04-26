import enum
from datetime import datetime

from sqlalchemy import String, Float, Integer, DateTime, Text, JSON, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class RiskRegime(str, enum.Enum):
    RISK_ON = "RISK_ON"
    RISK_OFF = "RISK_OFF"
    NEUTRAL = "NEUTRAL"


class MacroAnalysis(Base):
    __tablename__ = "macro_analyses"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    risk_regime: Mapped[str] = mapped_column(String(20), nullable=False, default=RiskRegime.NEUTRAL)
    currency_scores: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    llm_summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    llm_driver: Mapped[str | None] = mapped_column(String(500), nullable=True)
    news_items_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    raw_news: Mapped[list | None] = mapped_column(JSON, nullable=True)
    cycle_duration_seconds: Mapped[float | None] = mapped_column(Float, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    signals = relationship("Signal", back_populates="analysis")
