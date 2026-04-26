"use client";

import { useTrades } from "@/hooks/use-api";
import { TradesTable } from "@/components/trades/trades-table";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";

export default function TradesPage() {
  const { data: openTrades, isLoading: loadingOpen } = useTrades("OPEN");
  const { data: closedTrades, isLoading: loadingClosed } = useTrades("CLOSED");

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-white">Trades</h1>

      <Tabs defaultValue="open">
        <TabsList>
          <TabsTrigger value="open">
            Open Positions
            {openTrades && ` (${openTrades.length})`}
          </TabsTrigger>
          <TabsTrigger value="history">Trade History</TabsTrigger>
        </TabsList>

        <TabsContent value="open">
          {loadingOpen ? (
            <div className="text-gray-400">Loading…</div>
          ) : (
            <TradesTable trades={openTrades ?? []} />
          )}
        </TabsContent>

        <TabsContent value="history">
          {loadingClosed ? (
            <div className="text-gray-400">Loading…</div>
          ) : (
            <TradesTable trades={closedTrades ?? []} showStatus />
          )}
        </TabsContent>
      </Tabs>
    </div>
  );
}
