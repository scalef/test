import logging
from datetime import datetime
from typing import Optional

from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.interval import IntervalTrigger

from app.config import settings

logger = logging.getLogger(__name__)


class SchedulerService:
    def __init__(self):
        self._scheduler = BackgroundScheduler()
        self.last_run: Optional[datetime] = None
        self.next_run: Optional[datetime] = None
        self.is_paused: bool = False
        self._running: bool = False

    def start(self, interval_seconds: Optional[int] = None) -> None:
        interval = interval_seconds or settings.scheduler_interval_seconds
        self._scheduler.add_job(
            self._run_cycle,
            trigger=IntervalTrigger(seconds=interval),
            id="main_cycle",
            replace_existing=True,
            next_run_time=None,  # Don't run immediately on startup
        )
        self._scheduler.start()
        self._running = True
        job = self._scheduler.get_job("main_cycle")
        if job:
            self.next_run = job.next_run_time
        logger.info("Scheduler started with interval=%ds", interval)

    def _run_cycle(self) -> None:
        logger.info("Scheduler cycle starting")
        self.last_run = datetime.utcnow()
        try:
            from app.database import SessionLocal
            from app.services.llm_service import llm_service
            from app.services.signal_generator import signal_generator
            from app.services.telegram_service import telegram_service

            db = SessionLocal()
            try:
                news_items: list[dict] = []  # RSS fetch would populate this
                llm_result = llm_service.analyze(news_items)
                analysis = signal_generator.run_full_cycle(db, news_items, llm_result)
                telegram_service.notify_new_signals(analysis.signals)
                telegram_service.notify_cycle_complete(analysis)
                logger.info("Cycle complete: regime=%s signals=%d", analysis.risk_regime, len(analysis.signals))
            finally:
                db.close()
        except Exception as exc:
            logger.error("Scheduler cycle failed: %s", exc, exc_info=True)
        finally:
            job = self._scheduler.get_job("main_cycle")
            if job:
                self.next_run = job.next_run_time

    def run_now(self) -> None:
        """Trigger a cycle immediately (used by /cycle/run endpoint)."""
        self._scheduler.add_job(
            self._run_cycle,
            id="manual_cycle",
            replace_existing=True,
        )

    def pause(self) -> None:
        self._scheduler.pause()
        self.is_paused = True
        logger.info("Scheduler paused")

    def resume(self) -> None:
        self._scheduler.resume()
        self.is_paused = False
        job = self._scheduler.get_job("main_cycle")
        if job:
            self.next_run = job.next_run_time
        logger.info("Scheduler resumed")

    def shutdown(self) -> None:
        if self._running:
            self._scheduler.shutdown(wait=False)
            self._running = False


scheduler_service = SchedulerService()
