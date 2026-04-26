# Global Macro Trader

A full-stack trading dashboard for macro FX analysis, signal management, and trade execution with safety-first design.

## Architecture

```
global-macro-trader/
├── backend/    FastAPI + SQLAlchemy + APScheduler
└── frontend/   Next.js 14 App Router + shadcn/ui
```

## Trading Modes

| Mode | Orders Sent | Description |
|------|-------------|-------------|
| `SIGNAL_ONLY` | Never | Default — only generates signals for review |
| `DEMO` | Demo only | Sends simulated orders, never real |
| `LIVE` | Live orders | Requires `ALLOW_LIVE_TRADING=true` |

**Emergency Stop**: `/emergency-stop` endpoint immediately blocks all order execution regardless of mode.

## Prerequisites

- Python 3.11+
- Node.js 20+
- Docker + Docker Compose (optional)

## Quickstart

### Backend

```bash
cd global-macro-trader/backend
cp .env.example .env
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
mkdir -p data
uvicorn app.main:app --reload --port 8000
```

### Frontend

```bash
cd global-macro-trader/frontend
cp .env.example .env.local
npm install
npm run dev
```

Open http://localhost:3000

### Docker Compose

```bash
cd global-macro-trader
docker-compose up --build
```

- Frontend: http://localhost:3000
- Backend API: http://localhost:8000
- API Docs: http://localhost:8000/docs

## Environment Variables

### Backend (`backend/.env`)

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | `sqlite:///./data/trading.db` | Database connection string |
| `TRADING_MODE` | `SIGNAL_ONLY` | `SIGNAL_ONLY` / `DEMO` / `LIVE` |
| `ALLOW_LIVE_TRADING` | `false` | Must be `true` to enable LIVE mode |
| `SCHEDULER_INTERVAL_SECONDS` | `300` | Cycle interval in seconds |
| `TELEGRAM_BOT_TOKEN` | `` | Telegram bot token |
| `TELEGRAM_CHAT_ID` | `` | Telegram chat/channel ID |
| `MT5_LOGIN` | `` | MetaTrader 5 login |
| `MT5_PASSWORD` | `` | MetaTrader 5 password |
| `MT5_SERVER` | `` | MetaTrader 5 broker server |
| `LLM_PROVIDER` | `openai` | `openai` / `anthropic` / `local` |
| `LLM_API_KEY` | `` | LLM provider API key |
| `LLM_MODEL` | `gpt-4o` | LLM model name |

### Frontend (`frontend/.env.local`)

| Variable | Default | Description |
|----------|---------|-------------|
| `NEXT_PUBLIC_API_URL` | `http://localhost:8000` | Backend API base URL |

## Safety Rules

1. **SIGNAL_ONLY is the default** — no orders are ever sent
2. **LIVE mode** requires both `TRADING_MODE=LIVE` AND `ALLOW_LIVE_TRADING=true`
3. **Emergency stop** overrides all modes instantly
4. **All trading actions** are written to the audit log
5. **MT5 connector** is a placeholder — real MT5 requires Windows + MetaTrader5 package

## Running Tests

```bash
cd global-macro-trader/backend
pytest tests/ -v
```

## API Reference

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/status` | GET | System status snapshot |
| `/cycle/run` | POST | Trigger analysis cycle manually |
| `/analysis/latest` | GET | Latest macro analysis |
| `/signals` | GET | All signals |
| `/signals/{id}/approve` | POST | Approve a signal |
| `/signals/{id}/reject` | POST | Reject a signal |
| `/signals/{id}/send-demo` | POST | Send signal to demo (mode must be DEMO+) |
| `/trades` | GET | Trade history |
| `/settings` | GET | Current settings |
| `/settings` | PUT | Update settings |
| `/scheduler/pause` | POST | Pause scheduler |
| `/scheduler/resume` | POST | Resume scheduler |
| `/emergency-stop` | POST | Activate emergency stop |
