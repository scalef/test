import enum
from datetime import datetime

from sqlalchemy import String, Float, Integer, DateTime, Text, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class SignalStatus(str, enum.Enum):
    PENDING = "PENDING"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"
    SENT_DEMO = "SENT_DEMO"
    SENT_LIVE = "SENT_LIVE"
    EXPIRED = "EXPIRED"


class Signal(Base):
    __tablename__ = "signals"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    symbol: Mapped[str] = mapped_column(String(20), nullable=False)
    direction: Mapped[str] = mapped_column(String(4), nullable=False)
    entry_price: Mapped[float] = mapped_column(Float, nullable=False)
    stop_loss: Mapped[float] = mapped_column(Float, nullable=False)
    take_profit: Mapped[float] = mapped_column(Float, nullable=False)
    lot_size: Mapped[float] = mapped_column(Float, nullable=False, default=0.01)
    confidence: Mapped[float] = mapped_column(Float, nullable=False, default=0.5)
    risk_reward: Mapped[float] = mapped_column(Float, nullable=False, default=1.0)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default=SignalStatus.PENDING)
    analysis_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("macro_analyses.id"), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    updated_at: Mapped[datetime | None] = mapped_column(DateTime, onupdate=func.now(), nullable=True)

    analysis = relationship("MacroAnalysis", back_populates="signals")
    trades = relationship("Trade", back_populates="signal")
