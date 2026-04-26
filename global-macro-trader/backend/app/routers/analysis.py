from typing import Optional

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.analysis import MacroAnalysis
from app.schemas.analysis import MacroAnalysisRead

router = APIRouter(tags=["analysis"])


@router.get("/analysis/latest", response_model=Optional[MacroAnalysisRead])
def get_latest_analysis(db: Session = Depends(get_db)):
    row = db.execute(
        select(MacroAnalysis).order_by(MacroAnalysis.created_at.desc()).limit(1)
    ).scalar_one_or_none()
    return row
