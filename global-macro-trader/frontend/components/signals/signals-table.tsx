"use client";

import { Check, X, SendHorizonal } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { useSignalActions } from "@/hooks/use-api";
import { formatDate, formatPrice } from "@/lib/utils";
import type { Signal, SignalStatus } from "@/types";

const statusVariants: Record<SignalStatus, "default" | "success" | "destructive" | "info" | "secondary" | "warning"> = {
  PENDING: "warning",
  APPROVED: "success",
  REJECTED: "destructive",
  SENT_DEMO: "info",
  SENT_LIVE: "success",
  EXPIRED: "secondary",
};

interface SignalsTableProps {
  signals: Signal[];
}

export function SignalsTable({ signals }: SignalsTableProps) {
  const { approve, reject, sendDemo } = useSignalActions();

  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>Symbol</TableHead>
          <TableHead>Dir</TableHead>
          <TableHead>Entry</TableHead>
          <TableHead>SL</TableHead>
          <TableHead>TP</TableHead>
          <TableHead>RR</TableHead>
          <TableHead>Conf</TableHead>
          <TableHead>Status</TableHead>
          <TableHead>Created</TableHead>
          <TableHead>Actions</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {signals.length === 0 && (
          <TableRow>
            <TableCell colSpan={10} className="text-center text-gray-500">
              No signals yet. Run a cycle to generate signals.
            </TableCell>
          </TableRow>
        )}
        {signals.map((signal) => (
          <TableRow key={signal.id}>
            <TableCell className="font-mono font-bold">{signal.symbol}</TableCell>
            <TableCell>
              <span className={signal.direction === "BUY" ? "text-green-400" : "text-red-400"}>
                {signal.direction}
              </span>
            </TableCell>
            <TableCell className="font-mono text-xs">{formatPrice(signal.entry_price)}</TableCell>
            <TableCell className="font-mono text-xs text-red-400">{formatPrice(signal.stop_loss)}</TableCell>
            <TableCell className="font-mono text-xs text-green-400">{formatPrice(signal.take_profit)}</TableCell>
            <TableCell className="text-xs">{signal.risk_reward.toFixed(1)}</TableCell>
            <TableCell className="text-xs">{(signal.confidence * 100).toFixed(0)}%</TableCell>
            <TableCell>
              <Badge variant={statusVariants[signal.status as SignalStatus] ?? "secondary"}>
                {signal.status}
              </Badge>
            </TableCell>
            <TableCell className="text-xs text-gray-400">{formatDate(signal.created_at)}</TableCell>
            <TableCell>
              <div className="flex gap-1">
                {signal.status === "PENDING" && (
                  <>
                    <Button
                      size="sm"
                      variant="success"
                      onClick={() => approve.mutate(signal.id)}
                      disabled={approve.isPending}
                      title="Approve"
                    >
                      <Check className="h-3 w-3" />
                    </Button>
                    <Button
                      size="sm"
                      variant="destructive"
                      onClick={() => reject.mutate(signal.id)}
                      disabled={reject.isPending}
                      title="Reject"
                    >
                      <X className="h-3 w-3" />
                    </Button>
                  </>
                )}
                {signal.status === "APPROVED" && (
                  <Button
                    size="sm"
                    variant="default"
                    onClick={() => sendDemo.mutate(signal.id)}
                    disabled={sendDemo.isPending}
                    title="Send to Demo"
                  >
                    <SendHorizonal className="h-3 w-3 mr-1" />
                    Demo
                  </Button>
                )}
              </div>
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );
}
