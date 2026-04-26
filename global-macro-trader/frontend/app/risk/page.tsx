"use client";

import { useState, useEffect } from "react";
import { useSettings, useUpdateSettings } from "@/hooks/use-api";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

function NumberInput({
  label,
  value,
  onChange,
  min,
  max,
  step = 0.1,
  suffix,
}: {
  label: string;
  value: number;
  onChange: (v: number) => void;
  min?: number;
  max?: number;
  step?: number;
  suffix?: string;
}) {
  return (
    <div className="space-y-1">
      <label className="text-sm font-medium text-gray-300">{label}</label>
      <div className="flex items-center gap-2">
        <input
          type="number"
          value={value}
          min={min}
          max={max}
          step={step}
          onChange={(e) => onChange(parseFloat(e.target.value))}
          className="w-full rounded-md border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
        {suffix && <span className="text-sm text-gray-400">{suffix}</span>}
      </div>
    </div>
  );
}

export default function RiskPage() {
  const { data: settings, isLoading } = useSettings();
  const { mutate: save, isPending, isSuccess } = useUpdateSettings();

  const [form, setForm] = useState({
    risk_per_trade_pct: 1.0,
    max_daily_drawdown_pct: 5.0,
    max_total_drawdown_pct: 15.0,
    max_open_trades: 5,
    max_trades_per_symbol: 1,
    max_spread_points: 20.0,
    allowed_symbols: [] as string[],
  });
  const [symbolInput, setSymbolInput] = useState("");

  useEffect(() => {
    if (settings) {
      setForm({
        risk_per_trade_pct: settings.risk_per_trade_pct,
        max_daily_drawdown_pct: settings.max_daily_drawdown_pct,
        max_total_drawdown_pct: settings.max_total_drawdown_pct,
        max_open_trades: settings.max_open_trades,
        max_trades_per_symbol: settings.max_trades_per_symbol,
        max_spread_points: settings.max_spread_points,
        allowed_symbols: settings.allowed_symbols ?? [],
      });
    }
  }, [settings]);

  const addSymbol = () => {
    const s = symbolInput.trim().toUpperCase();
    if (s && !form.allowed_symbols.includes(s)) {
      setForm((f) => ({ ...f, allowed_symbols: [...f.allowed_symbols, s] }));
    }
    setSymbolInput("");
  };

  const removeSymbol = (sym: string) => {
    setForm((f) => ({ ...f, allowed_symbols: f.allowed_symbols.filter((s) => s !== sym) }));
  };

  if (isLoading) return <div className="text-gray-400">Loading…</div>;

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-white">Risk Settings</h1>
      <p className="text-sm text-gray-400">
        Changes apply to the next cycle. Empty allowed symbols list means all symbols are allowed.
      </p>

      <Card>
        <CardHeader>
          <CardTitle className="text-gray-200 text-base">Risk Limits</CardTitle>
        </CardHeader>
        <CardContent className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <NumberInput
            label="Risk per Trade"
            value={form.risk_per_trade_pct}
            onChange={(v) => setForm((f) => ({ ...f, risk_per_trade_pct: v }))}
            min={0.01}
            max={10}
            step={0.1}
            suffix="%"
          />
          <NumberInput
            label="Max Daily Drawdown"
            value={form.max_daily_drawdown_pct}
            onChange={(v) => setForm((f) => ({ ...f, max_daily_drawdown_pct: v }))}
            min={0.5}
            max={50}
            step={0.5}
            suffix="%"
          />
          <NumberInput
            label="Max Total Drawdown"
            value={form.max_total_drawdown_pct}
            onChange={(v) => setForm((f) => ({ ...f, max_total_drawdown_pct: v }))}
            min={1}
            max={100}
            step={1}
            suffix="%"
          />
          <NumberInput
            label="Max Open Trades"
            value={form.max_open_trades}
            onChange={(v) => setForm((f) => ({ ...f, max_open_trades: Math.round(v) }))}
            min={1}
            max={50}
            step={1}
          />
          <NumberInput
            label="Max Trades per Symbol"
            value={form.max_trades_per_symbol}
            onChange={(v) => setForm((f) => ({ ...f, max_trades_per_symbol: Math.round(v) }))}
            min={1}
            max={10}
            step={1}
          />
          <NumberInput
            label="Max Spread Points"
            value={form.max_spread_points}
            onChange={(v) => setForm((f) => ({ ...f, max_spread_points: v }))}
            min={1}
            max={200}
            step={1}
          />
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-gray-200 text-base">Allowed Symbols</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <div className="flex gap-2">
            <input
              type="text"
              placeholder="EURUSD"
              value={symbolInput}
              onChange={(e) => setSymbolInput(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && addSymbol()}
              className="flex-1 rounded-md border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
            <Button size="sm" onClick={addSymbol}>Add</Button>
          </div>
          <div className="flex flex-wrap gap-2">
            {form.allowed_symbols.length === 0 && (
              <span className="text-sm text-gray-500">No restrictions — all symbols allowed</span>
            )}
            {form.allowed_symbols.map((sym) => (
              <button
                key={sym}
                onClick={() => removeSymbol(sym)}
                className="flex items-center gap-1 rounded-full bg-gray-700 px-3 py-1 text-xs text-gray-200 hover:bg-gray-600"
              >
                {sym} ×
              </button>
            ))}
          </div>
        </CardContent>
      </Card>

      <div className="flex items-center gap-3">
        <Button onClick={() => save(form)} disabled={isPending}>
          {isPending ? "Saving…" : "Save Risk Settings"}
        </Button>
        {isSuccess && <span className="text-sm text-green-400">Saved!</span>}
      </div>
    </div>
  );
}
