import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database import init_db, SessionLocal
from app.routers import health, status, cycle, analysis, signals, trades, settings as settings_router, scheduler, emergency
from app.services.scheduler_service import scheduler_service

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def _restore_runtime_state() -> None:
    """Restore emergency_stop and trading_mode from DB on startup."""
    db = SessionLocal()
    try:
        from app.models.app_settings import AppSettings
        row = db.get(AppSettings, 1)
        if row:
            settings.emergency_stop = row.emergency_stop
            from app.config import TradingMode
            try:
                settings.trading_mode = TradingMode(row.trading_mode)
            except ValueError:
                settings.trading_mode = TradingMode.SIGNAL_ONLY
    finally:
        db.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting Global Macro Trader backend")
    init_db()
    _restore_runtime_state()
    scheduler_service.start()
    yield
    logger.info("Shutting down")
    scheduler_service.shutdown()


app = FastAPI(
    title="Global Macro Trader API",
    version="1.0.0",
    description="Trading dashboard backend — SIGNAL_ONLY mode by default",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(status.router)
app.include_router(cycle.router)
app.include_router(analysis.router)
app.include_router(signals.router)
app.include_router(trades.router)
app.include_router(settings_router.router)
app.include_router(scheduler.router)
app.include_router(emergency.router)
