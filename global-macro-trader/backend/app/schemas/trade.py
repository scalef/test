from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict


class TradeRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    signal_id: Optional[int]
    mt5_ticket: Optional[int]
    symbol: str
    direction: str
    lot_size: float
    entry_price: float
    stop_loss: float
    take_profit: float
    close_price: Optional[float]
    pnl: Optional[float]
    pnl_pips: Optional[float]
    status: str
    is_demo: bool
    opened_at: datetime
    closed_at: Optional[datetime]
