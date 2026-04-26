from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.app_settings import AppSettings
from app.schemas.settings import AllSettingsRead, AllSettingsUpdate

router = APIRouter(tags=["settings"])


def _get_or_create_settings(db: Session) -> AppSettings:
    row = db.get(AppSettings, 1)
    if row is None:
        row = AppSettings(id=1)
        db.add(row)
        db.commit()
        db.refresh(row)
    return row


@router.get("/settings", response_model=AllSettingsRead)
def get_settings(db: Session = Depends(get_db)):
    return _get_or_create_settings(db)


@router.put("/settings", response_model=AllSettingsRead)
def update_settings(payload: AllSettingsUpdate, db: Session = Depends(get_db)):
    row = _get_or_create_settings(db)
    data = payload.model_dump(exclude_none=True)
    for key, value in data.items():
        # Don't overwrite masked values
        if value == "***":
            continue
        setattr(row, key, value)
    db.commit()
    db.refresh(row)
    return row
