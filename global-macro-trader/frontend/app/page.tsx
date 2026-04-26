"use client";

import { useStatus } from "@/hooks/use-api";
import { StatusCards, MetricsCards } from "@/components/dashboard/status-cards";
import { EmergencyStopButton } from "@/components/dashboard/emergency-stop-button";

export default function DashboardPage() {
  const { data: status, isLoading, isError } = useStatus();

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-white">Dashboard</h1>

      {isLoading && (
        <div className="text-gray-400">Loading system status…</div>
      )}

      {isError && (
        <div className="rounded-lg border border-red-700 bg-red-950/30 p-4 text-red-400">
          Cannot connect to backend API. Make sure the backend is running on port 8000.
        </div>
      )}

      {status && (
        <>
          <StatusCards status={status} />
          <MetricsCards status={status} />
          <EmergencyStopButton active={status.emergency_stop} />
        </>
      )}
    </div>
  );
}
