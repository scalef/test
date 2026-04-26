# CLAUDE.md — Global Macro Trader

Project rules for Claude Code agents working on this repository.

## Project Structure

```
global-macro-trader/
├── backend/    Python FastAPI application
└── frontend/   Next.js TypeScript application
```

All source code lives inside `global-macro-trader/`. Never create files outside this directory.

## Running the Project

### Backend (from `global-macro-trader/backend/`)
```bash
pip install -r requirements.txt
mkdir -p data
uvicorn app.main:app --reload --port 8000
```

### Frontend (from `global-macro-trader/frontend/`)
```bash
npm install
npm run dev
```

### Tests (from `global-macro-trader/backend/`)
```bash
pytest tests/ -v
```

### Type check frontend (from `global-macro-trader/frontend/`)
```bash
npm run build
```

## Safety Rules — NEVER Violate These

1. **Never bypass `TradingGuard`** — Every order path must call `TradingGuard.assert_can_send_demo()` or `TradingGuard.assert_can_send_live()`. No router or service may call `MT5Service` directly.

2. **Never set `ALLOW_LIVE_TRADING=true` in tests** — Tests must use `SIGNAL_ONLY` mode or `DEMO` mode only. Monkeypatch or fixtures must reset `allow_live_trading=False`.

3. **All trading actions must be audit-logged** — Every `approve`, `reject`, `send-demo`, `send-live`, and `emergency-stop` action must write an `AuditLog` row before returning.

4. **MT5 service remains a placeholder** — Do not add real MT5 order execution code unless explicitly asked. The `MT5Service.send_order()` method must always log that it is a placeholder.

5. **Emergency stop is permanent per session** — Once `emergency_stopped=True` is set in the DB, it must not be cleared by any API endpoint. Only a manual DB reset or restart can clear it.

6. **SIGNAL_ONLY mode never sends orders** — `TradingGuard.can_send_demo()` must return `False` when `TRADING_MODE=SIGNAL_ONLY`.

## Code Style

### Python
- Use Black (line length 100) and Ruff
- Pydantic v2 (`model_config`, `ConfigDict`, `field_validator`)
- SQLAlchemy 2.0 (`Mapped[T]`, `mapped_column()`, async sessions)
- No `import *`
- Type annotations on all function signatures

### TypeScript / React
- Strict TypeScript — no `any` types
- All components must export a named function (not default anonymous)
- Use React Query (`@tanstack/react-query`) for all server state — no `useState` + `useEffect` for data fetching
- `"use client"` directive only on components that use hooks or browser APIs
- Tailwind CSS only — no inline styles

## Database Rules

- Never run raw `DROP TABLE` — use Alembic migrations
- Never access `.db` file directly — always use SQLAlchemy session
- JSON columns (`allowed_symbols`, `rss_sources`, `currency_scores`) must default to `[]` or `{}` not `None`
- The `AuditLog` table is append-only — never update or delete rows

## Testing Requirements

- New services must have corresponding pytest tests in `backend/tests/`
- Fixtures must use in-memory SQLite (`sqlite+aiosqlite:///:memory:`)
- Never use real API keys or Telegram tokens in tests
- Tests that simulate trading must assert the audit log was written

## Commit Conventions

Use conventional commits:
- `feat:` — new feature
- `fix:` — bug fix
- `chore:` — maintenance, deps, config
- `test:` — adding/changing tests
- `docs:` — documentation only

Example: `feat: add currency score bar chart to macro analysis page`

## Key Files

| File | Purpose |
|------|---------|
| `backend/app/services/trading_guard.py` | Safety gate — all order paths go through here |
| `backend/app/services/risk_manager.py` | Risk limit checks |
| `backend/app/config.py` | All environment variable settings |
| `backend/app/main.py` | FastAPI app + lifespan startup |
| `frontend/src/lib/api.ts` | All frontend API calls |
| `frontend/src/hooks/use-api.ts` | React Query hooks |
