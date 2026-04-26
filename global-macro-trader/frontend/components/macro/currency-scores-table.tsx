import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { cn } from "@/lib/utils";
import { TrendingDown, TrendingUp, Minus } from "lucide-react";

interface CurrencyScoresTableProps {
  scores: Record<string, number>;
}

export function CurrencyScoresTable({ scores }: CurrencyScoresTableProps) {
  const sorted = Object.entries(scores).sort(([, a], [, b]) => b - a);

  return (
    <Card>
      <CardHeader>
        <CardTitle>Currency Scores</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="space-y-2">
          {sorted.map(([currency, score]) => {
            const pct = Math.round(Math.abs(score) * 100);
            const isPositive = score > 0.05;
            const isNegative = score < -0.05;
            return (
              <div key={currency} className="flex items-center gap-3">
                <span className="w-10 text-sm font-mono font-bold text-gray-300">
                  {currency}
                </span>
                <div className="flex-1 h-2 bg-gray-800 rounded-full overflow-hidden">
                  <div
                    className={cn(
                      "h-full rounded-full transition-all",
                      isPositive ? "bg-green-500" : isNegative ? "bg-red-500" : "bg-gray-600"
                    )}
                    style={{ width: `${pct}%` }}
                  />
                </div>
                <div className="flex items-center gap-1 w-16 justify-end">
                  {isPositive ? (
                    <TrendingUp className="h-3 w-3 text-green-400" />
                  ) : isNegative ? (
                    <TrendingDown className="h-3 w-3 text-red-400" />
                  ) : (
                    <Minus className="h-3 w-3 text-gray-500" />
                  )}
                  <span
                    className={cn(
                      "text-xs font-mono",
                      isPositive ? "text-green-400" : isNegative ? "text-red-400" : "text-gray-500"
                    )}
                  >
                    {score >= 0 ? "+" : ""}{score.toFixed(2)}
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      </CardContent>
    </Card>
  );
}
