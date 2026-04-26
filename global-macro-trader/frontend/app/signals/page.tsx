"use client";

import { useSignals } from "@/hooks/use-api";
import { SignalsTable } from "@/components/signals/signals-table";

export default function SignalsPage() {
  const { data: signals, isLoading, isError } = useSignals();

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-white">Signals</h1>
      <p className="text-sm text-gray-400">
        Approve signals before sending to demo. Signal sending requires DEMO or LIVE mode.
      </p>

      {isLoading && <div className="text-gray-400">Loading signals…</div>}
      {isError && <div className="text-red-400">Failed to load signals</div>}

      {signals && <SignalsTable signals={signals} />}
    </div>
  );
}
