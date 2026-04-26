"use client";

import { useState, useEffect } from "react";
import { useSettings, useUpdateSettings } from "@/hooks/use-api";
import { Button } from "@/components/ui/button";
import type { TradingMode } from "@/types";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";

function Field({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <div className="space-y-1">
      <label className="text-sm font-medium text-gray-300">{label}</label>
      {children}
    </div>
  );
}

function TextInput({
  value,
  onChange,
  placeholder,
  type = "text",
}: {
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  type?: string;
}) {
  return (
    <input
      type={type}
      value={value}
      placeholder={placeholder}
      onChange={(e) => onChange(e.target.value)}
      className="w-full rounded-md border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-white placeholder-gray-600 focus:outline-none focus:ring-2 focus:ring-blue-500"
    />
  );
}

export default function SettingsPage() {
  const { data: settings, isLoading } = useSettings();
  const { mutate: save, isPending, isSuccess } = useUpdateSettings();

  const [form, setForm] = useState({
    telegram_bot_token: "",
    telegram_chat_id: "",
    mt5_login: 0,
    mt5_password: "",
    mt5_server: "",
    mt5_enabled: false,
    llm_provider: "openai",
    llm_api_key: "",
    llm_model: "gpt-4o",
    rss_sources: [] as string[],
    scheduler_interval_seconds: 300,
    trading_mode: "SIGNAL_ONLY" as TradingMode,
  });
  const [rssInput, setRssInput] = useState("");

  useEffect(() => {
    if (settings) {
      setForm({
        telegram_bot_token: settings.telegram_bot_token,
        telegram_chat_id: settings.telegram_chat_id,
        mt5_login: settings.mt5_login,
        mt5_password: settings.mt5_password,
        mt5_server: settings.mt5_server,
        mt5_enabled: settings.mt5_enabled,
        llm_provider: settings.llm_provider,
        llm_api_key: settings.llm_api_key,
        llm_model: settings.llm_model,
        rss_sources: settings.rss_sources ?? [],
        scheduler_interval_seconds: settings.scheduler_interval_seconds,
        trading_mode: settings.trading_mode,
      });
    }
  }, [settings]);

  const addRss = () => {
    const url = rssInput.trim();
    if (url && !form.rss_sources.includes(url)) {
      setForm((f) => ({ ...f, rss_sources: [...f.rss_sources, url] }));
    }
    setRssInput("");
  };

  const removeRss = (url: string) => {
    setForm((f) => ({ ...f, rss_sources: f.rss_sources.filter((u) => u !== url) }));
  };

  if (isLoading) return <div className="text-gray-400">Loading…</div>;

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-white">Settings</h1>

      <Tabs defaultValue="telegram">
        <TabsList>
          <TabsTrigger value="telegram">Telegram</TabsTrigger>
          <TabsTrigger value="mt5">MT5</TabsTrigger>
          <TabsTrigger value="llm">LLM</TabsTrigger>
          <TabsTrigger value="scheduler">Scheduler / RSS</TabsTrigger>
        </TabsList>

        <TabsContent value="telegram">
          <Card>
            <CardHeader><CardTitle className="text-base text-gray-200">Telegram Notifications</CardTitle></CardHeader>
            <CardContent className="space-y-4">
              <Field label="Bot Token">
                <TextInput
                  type="password"
                  value={form.telegram_bot_token}
                  onChange={(v) => setForm((f) => ({ ...f, telegram_bot_token: v }))}
                  placeholder={settings?.telegram_bot_token === "***" ? "Saved (hidden)" : "1234567890:AAF..."}
                />
              </Field>
              <Field label="Chat ID">
                <TextInput
                  value={form.telegram_chat_id}
                  onChange={(v) => setForm((f) => ({ ...f, telegram_chat_id: v }))}
                  placeholder="-1001234567890"
                />
              </Field>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="mt5">
          <Card>
            <CardHeader><CardTitle className="text-base text-gray-200">MetaTrader 5 (Placeholder)</CardTitle></CardHeader>
            <CardContent className="space-y-4">
              <p className="text-sm text-yellow-400">
                MT5 connector is a placeholder. Real connection requires Windows + MetaTrader5 Python package.
              </p>
              <Field label="Login">
                <TextInput
                  value={String(form.mt5_login)}
                  onChange={(v) => setForm((f) => ({ ...f, mt5_login: parseInt(v) || 0 }))}
                  placeholder="12345678"
                />
              </Field>
              <Field label="Password">
                <TextInput
                  type="password"
                  value={form.mt5_password}
                  onChange={(v) => setForm((f) => ({ ...f, mt5_password: v }))}
                  placeholder={settings?.mt5_password === "***" ? "Saved (hidden)" : "password"}
                />
              </Field>
              <Field label="Server">
                <TextInput
                  value={form.mt5_server}
                  onChange={(v) => setForm((f) => ({ ...f, mt5_server: v }))}
                  placeholder="BrokerName-Demo"
                />
              </Field>
              <label className="flex items-center gap-2 text-sm text-gray-300">
                <input
                  type="checkbox"
                  checked={form.mt5_enabled}
                  onChange={(e) => setForm((f) => ({ ...f, mt5_enabled: e.target.checked }))}
                  className="rounded"
                />
                Enable MT5 connection
              </label>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="llm">
          <Card>
            <CardHeader><CardTitle className="text-base text-gray-200">LLM Provider</CardTitle></CardHeader>
            <CardContent className="space-y-4">
              <Field label="Provider">
                <select
                  value={form.llm_provider}
                  onChange={(e) => setForm((f) => ({ ...f, llm_provider: e.target.value }))}
                  className="w-full rounded-md border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="openai">OpenAI</option>
                  <option value="anthropic">Anthropic</option>
                  <option value="local">Local (disabled)</option>
                </select>
              </Field>
              <Field label="API Key">
                <TextInput
                  type="password"
                  value={form.llm_api_key}
                  onChange={(v) => setForm((f) => ({ ...f, llm_api_key: v }))}
                  placeholder={settings?.llm_api_key === "***" ? "Saved (hidden)" : "sk-..."}
                />
              </Field>
              <Field label="Model">
                <TextInput
                  value={form.llm_model}
                  onChange={(v) => setForm((f) => ({ ...f, llm_model: v }))}
                  placeholder="gpt-4o"
                />
              </Field>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="scheduler">
          <div className="space-y-4">
            <Card>
              <CardHeader><CardTitle className="text-base text-gray-200">Scheduler</CardTitle></CardHeader>
              <CardContent className="space-y-4">
                <Field label="Cycle Interval (seconds)">
                  <input
                    type="number"
                    value={form.scheduler_interval_seconds}
                    min={60}
                    max={86400}
                    step={60}
                    onChange={(e) => setForm((f) => ({ ...f, scheduler_interval_seconds: parseInt(e.target.value) }))}
                    className="w-full rounded-md border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                </Field>
                <Field label="Trading Mode">
                  <select
                    value={form.trading_mode}
                    onChange={(e) => setForm((f) => ({ ...f, trading_mode: e.target.value as TradingMode }))}
                    className="w-full rounded-md border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
                  >
                    <option value="SIGNAL_ONLY">SIGNAL_ONLY (Safe default)</option>
                    <option value="DEMO">DEMO</option>
                    <option value="LIVE">LIVE (Requires ALLOW_LIVE_TRADING=true)</option>
                  </select>
                </Field>
              </CardContent>
            </Card>

            <Card>
              <CardHeader><CardTitle className="text-base text-gray-200">RSS News Sources</CardTitle></CardHeader>
              <CardContent className="space-y-3">
                <div className="flex gap-2">
                  <TextInput
                    value={rssInput}
                    onChange={setRssInput}
                    placeholder="https://feeds.example.com/rss"
                  />
                  <Button size="sm" onClick={addRss}>Add</Button>
                </div>
                <div className="space-y-1">
                  {form.rss_sources.length === 0 && (
                    <p className="text-sm text-gray-500">Using default RSS feeds</p>
                  )}
                  {form.rss_sources.map((url) => (
                    <div key={url} className="flex items-center justify-between rounded bg-gray-800 px-3 py-1">
                      <span className="text-xs text-gray-300 truncate">{url}</span>
                      <button
                        onClick={() => removeRss(url)}
                        className="ml-2 text-xs text-red-400 hover:text-red-300"
                      >
                        Remove
                      </button>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>
      </Tabs>

      <div className="flex items-center gap-3">
        <Button onClick={() => save(form)} disabled={isPending}>
          {isPending ? "Saving…" : "Save Settings"}
        </Button>
        {isSuccess && <span className="text-sm text-green-400">Saved!</span>}
      </div>
    </div>
  );
}
