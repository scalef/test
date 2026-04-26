import type {
  AppSettings,
  MacroAnalysis,
  Signal,
  SystemStatus,
  Trade,
} from "@/types";

const BASE_URL =
  process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000";

async function request<T>(
  path: string,
  options?: RequestInit
): Promise<T> {
  const res = await fetch(`${BASE_URL}${path}`, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`${res.status} ${res.statusText}: ${body}`);
  }
  if (res.status === 204) return undefined as T;
  return res.json() as Promise<T>;
}

export const api = {
  getHealth: () => request<{ status: string; timestamp: string }>("/health"),
  getStatus: () => request<SystemStatus>("/status"),
  runCycle: () => request<{ ok: boolean }>("/cycle/run", { method: "POST" }),

  getAnalysis: () => request<MacroAnalysis | null>("/analysis/latest"),

  getSignals: () => request<Signal[]>("/signals"),
  approveSignal: (id: number) =>
    request<{ ok: boolean }>(`/signals/${id}/approve`, { method: "POST" }),
  rejectSignal: (id: number) =>
    request<{ ok: boolean }>(`/signals/${id}/reject`, { method: "POST" }),
  sendSignalToDemo: (id: number) =>
    request<{ ok: boolean; trade_id: number | null }>(
      `/signals/${id}/send-demo`,
      { method: "POST" }
    ),

  getTrades: (status?: string) =>
    request<Trade[]>(`/trades${status ? `?status=${status}` : ""}`),

  getSettings: () => request<AppSettings>("/settings"),
  updateSettings: (data: Partial<AppSettings>) =>
    request<AppSettings>("/settings", {
      method: "PUT",
      body: JSON.stringify(data),
    }),

  pauseScheduler: () =>
    request<{ ok: boolean }>("/scheduler/pause", { method: "POST" }),
  resumeScheduler: () =>
    request<{ ok: boolean }>("/scheduler/resume", { method: "POST" }),

  emergencyStop: () =>
    request<{ ok: boolean; emergency_stop: boolean }>("/emergency-stop", {
      method: "POST",
    }),
};
