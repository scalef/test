from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, ConfigDict


class MacroAnalysisRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    risk_regime: str
    currency_scores: Dict[str, float]
    llm_summary: Optional[str]
    llm_driver: Optional[str]
    news_items_count: int
    raw_news: Optional[List[Any]]
    cycle_duration_seconds: Optional[float]
    created_at: datetime
