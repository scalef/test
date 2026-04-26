import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { cn, formatDate, formatPrice } from "@/lib/utils";
import type { Trade } from "@/types";

interface TradesTableProps {
  trades: Trade[];
  showStatus?: boolean;
}

export function TradesTable({ trades, showStatus = false }: TradesTableProps) {
  if (trades.length === 0) {
    return <p className="text-gray-500 text-sm py-4">No trades found.</p>;
  }

  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>Symbol</TableHead>
          <TableHead>Dir</TableHead>
          <TableHead>Entry</TableHead>
          <TableHead>SL</TableHead>
          <TableHead>TP</TableHead>
          <TableHead>Close</TableHead>
          <TableHead>Lot</TableHead>
          <TableHead>PnL</TableHead>
          <TableHead>Mode</TableHead>
          {showStatus && <TableHead>Status</TableHead>}
          <TableHead>Opened</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {trades.map((trade) => {
          const pnlColor =
            trade.pnl === null
              ? "text-gray-400"
              : trade.pnl >= 0
              ? "text-green-400"
              : "text-red-400";

          return (
            <TableRow key={trade.id}>
              <TableCell className="font-mono font-bold">{trade.symbol}</TableCell>
              <TableCell>
                <span className={trade.direction === "BUY" ? "text-green-400" : "text-red-400"}>
                  {trade.direction}
                </span>
              </TableCell>
              <TableCell className="font-mono text-xs">{formatPrice(trade.entry_price)}</TableCell>
              <TableCell className="font-mono text-xs text-red-400">{formatPrice(trade.stop_loss)}</TableCell>
              <TableCell className="font-mono text-xs text-green-400">{formatPrice(trade.take_profit)}</TableCell>
              <TableCell className="font-mono text-xs">
                {trade.close_price ? formatPrice(trade.close_price) : "—"}
              </TableCell>
              <TableCell className="text-xs">{trade.lot_size.toFixed(2)}</TableCell>
              <TableCell className={cn("font-mono text-sm font-medium", pnlColor)}>
                {trade.pnl !== null ? `${trade.pnl >= 0 ? "+" : ""}${trade.pnl.toFixed(2)}` : "—"}
              </TableCell>
              <TableCell>
                <Badge variant={trade.is_demo ? "secondary" : "success"}>
                  {trade.is_demo ? "DEMO" : "LIVE"}
                </Badge>
              </TableCell>
              {showStatus && (
                <TableCell>
                  <Badge variant={trade.status === "OPEN" ? "default" : "secondary"}>
                    {trade.status}
                  </Badge>
                </TableCell>
              )}
              <TableCell className="text-xs text-gray-400">{formatDate(trade.opened_at)}</TableCell>
            </TableRow>
          );
        })}
      </TableBody>
    </Table>
  );
}
