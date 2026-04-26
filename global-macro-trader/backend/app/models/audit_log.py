from datetime import datetime

from sqlalchemy import String, Integer, Boolean, DateTime, JSON, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    action: Mapped[str] = mapped_column(String(100), nullable=False)
    signal_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    trade_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    actor: Mapped[str] = mapped_column(String(50), nullable=False, default="system")
    details: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    trading_mode: Mapped[str] = mapped_column(String(20), nullable=False, default="SIGNAL_ONLY")
    emergency_stop_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
