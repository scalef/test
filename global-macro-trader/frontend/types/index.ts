export type TradingMode = "SIGNAL_ONLY" | "DEMO" | "LIVE";
export type SignalStatus =
  | "PENDING"
  | "APPROVED"
  | "REJECTED"
  | "SENT_DEMO"
  | "SENT_LIVE"
  | "EXPIRED";
export type RiskRegime = "RISK_ON" | "RISK_OFF" | "NEUTRAL";
export type TradeStatus = "OPEN" | "CLOSED" | "CANCELLED";

export interface SystemStatus {
  trading_mode: TradingMode;
  emergency_stop: boolean;
  scheduler_paused: boolean;
  last_cycle: string | null;
  next_cycle: string | null;
  equity: number;
  daily_drawdown_pct: number;
  open_trades_count: number;
  mt5_connected: boolean;
}

export interface Signal {
  id: number;
  symbol: string;
  direction: "BUY" | "SELL";
  entry_price: number;
  stop_loss: number;
  take_profit: number;
  lot_size: number;
  confidence: number;
  risk_reward: number;
  status: SignalStatus;
  analysis_id: number | null;
  notes: string | null;
  created_at: string;
  updated_at: string | null;
}

export interface MacroAnalysis {
  id: number;
  risk_regime: RiskRegime;
  currency_scores: Record<string, number>;
  llm_summary: string | null;
  llm_driver: string | null;
  news_items_count: number;
  raw_news: Array<{ title: string; source: string; url: string; published: string }> | null;
  cycle_duration_seconds: number | null;
  created_at: string;
}

export interface Trade {
  id: number;
  signal_id: number | null;
  mt5_ticket: number | null;
  symbol: string;
  direction: "BUY" | "SELL";
  lot_size: number;
  entry_price: number;
  stop_loss: number;
  take_profit: number;
  close_price: number | null;
  pnl: number | null;
  pnl_pips: number | null;
  status: TradeStatus;
  is_demo: boolean;
  opened_at: string;
  closed_at: string | null;
}

export interface AppSettings {
  risk_per_trade_pct: number;
  max_daily_drawdown_pct: number;
  max_total_drawdown_pct: number;
  max_open_trades: number;
  max_trades_per_symbol: number;
  max_spread_points: number;
  allowed_symbols: string[];
  telegram_bot_token: string;
  telegram_chat_id: string;
  mt5_login: number;
  mt5_password: string;
  mt5_server: string;
  mt5_enabled: boolean;
  llm_provider: string;
  llm_api_key: string;
  llm_model: string;
  rss_sources: string[];
  scheduler_interval_seconds: number;
  trading_mode: TradingMode;
  emergency_stop: boolean;
}
