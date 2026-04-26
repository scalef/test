from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict


class SignalRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    symbol: str
    direction: Literal["BUY", "SELL"]
    entry_price: float
    stop_loss: float
    take_profit: float
    lot_size: float
    confidence: float
    risk_reward: float
    status: str
    analysis_id: Optional[int]
    notes: Optional[str]
    created_at: datetime
    updated_at: Optional[datetime]
