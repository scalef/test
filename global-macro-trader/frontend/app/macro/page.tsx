"use client";

import { useAnalysis } from "@/hooks/use-api";
import { RiskRegimeCard } from "@/components/macro/risk-regime-card";
import { CurrencyScoresTable } from "@/components/macro/currency-scores-table";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { formatDate } from "@/lib/utils";
import type { RiskRegime } from "@/types";

export default function MacroPage() {
  const { data: analysis, isLoading, isError } = useAnalysis();

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-white">Macro Analysis</h1>

      {isLoading && <div className="text-gray-400">Loading…</div>}
      {isError && <div className="text-red-400">Failed to load analysis</div>}

      {!analysis && !isLoading && (
        <div className="text-gray-400">No analysis available yet. Run a cycle to generate one.</div>
      )}

      {analysis && (
        <>
          <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
            <RiskRegimeCard
              regime={analysis.risk_regime as RiskRegime}
              driver={analysis.llm_driver}
              summary={analysis.llm_summary}
            />
            <CurrencyScoresTable scores={analysis.currency_scores} />
          </div>

          <Card>
            <CardHeader>
              <CardTitle>
                News Sources ({analysis.news_items_count} items)
                <span className="ml-2 text-xs text-gray-500 font-normal">
                  — Analysed {formatDate(analysis.created_at)}
                  {analysis.cycle_duration_seconds && ` in ${analysis.cycle_duration_seconds.toFixed(1)}s`}
                </span>
              </CardTitle>
            </CardHeader>
            <CardContent>
              {analysis.raw_news && analysis.raw_news.length > 0 ? (
                <ul className="space-y-2">
                  {analysis.raw_news.slice(0, 10).map((item, i) => (
                    <li key={i} className="flex items-start gap-2">
                      <span className="mt-1 h-1.5 w-1.5 rounded-full bg-gray-500 shrink-0" />
                      <div>
                        <p className="text-sm text-gray-200">{item.title}</p>
                        <p className="text-xs text-gray-500">{item.source}</p>
                      </div>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="text-sm text-gray-500">No news items in this cycle.</p>
              )}
            </CardContent>
          </Card>
        </>
      )}
    </div>
  );
}
