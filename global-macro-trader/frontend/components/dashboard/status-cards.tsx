"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { formatDate, formatPct } from "@/lib/utils";
import type { SystemStatus } from "@/types";

interface StatusCardsProps {
  status: SystemStatus;
}

const modeVariant: Record<string, "default" | "warning" | "success"> = {
  SIGNAL_ONLY: "default",
  DEMO: "warning",
  LIVE: "success",
};

export function StatusCards({ status }: StatusCardsProps) {
  return (
    <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
      <Card className={status.emergency_stop ? "border-red-600" : ""}>
        <CardHeader>
          <CardTitle>System Status</CardTitle>
        </CardHeader>
        <CardContent>
          <Badge variant={status.emergency_stop ? "destructive" : "success"}>
            {status.emergency_stop ? "STOPPED" : "Running"}
          </Badge>
          {status.mt5_connected ? (
            <Badge variant="success" className="ml-2 text-xs">MT5 Connected</Badge>
          ) : (
            <Badge variant="secondary" className="ml-2 text-xs">MT5 Placeholder</Badge>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Trading Mode</CardTitle>
        </CardHeader>
        <CardContent>
          <Badge variant={modeVariant[status.trading_mode] ?? "default"}>
            {status.trading_mode}
          </Badge>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Last Cycle</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-gray-200">{formatDate(status.last_cycle)}</p>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Next Cycle</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-gray-200">{formatDate(status.next_cycle)}</p>
          {status.scheduler_paused && (
            <Badge variant="warning" className="mt-1">Paused</Badge>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

export function MetricsCards({ status }: StatusCardsProps) {
  const ddColor =
    status.daily_drawdown_pct < -3
      ? "text-red-400"
      : status.daily_drawdown_pct < -1
      ? "text-yellow-400"
      : "text-green-400";

  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
      <Card>
        <CardHeader>
          <CardTitle>Equity</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-2xl font-bold text-white">
            ${status.equity.toLocaleString("en-US", { minimumFractionDigits: 2 })}
          </p>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Daily Drawdown</CardTitle>
        </CardHeader>
        <CardContent>
          <p className={`text-2xl font-bold ${ddColor}`}>
            {formatPct(status.daily_drawdown_pct)}
          </p>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Open Trades</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-2xl font-bold text-white">{status.open_trades_count}</p>
        </CardContent>
      </Card>
    </div>
  );
}
