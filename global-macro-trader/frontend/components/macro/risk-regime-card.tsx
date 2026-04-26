import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import type { RiskRegime } from "@/types";

const regimeConfig: Record<RiskRegime, { variant: "success" | "destructive" | "warning"; label: string }> = {
  RISK_ON: { variant: "success", label: "Risk On" },
  RISK_OFF: { variant: "destructive", label: "Risk Off" },
  NEUTRAL: { variant: "warning", label: "Neutral" },
};

interface RiskRegimeCardProps {
  regime: RiskRegime;
  driver: string | null;
  summary: string | null;
}

export function RiskRegimeCard({ regime, driver, summary }: RiskRegimeCardProps) {
  const config = regimeConfig[regime];
  return (
    <Card>
      <CardHeader>
        <CardTitle>Risk Regime</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        <Badge variant={config.variant} className="text-base px-4 py-1">
          {config.label}
        </Badge>
        {driver && (
          <div>
            <p className="text-xs text-gray-400 mb-1">Main Driver</p>
            <p className="text-sm text-gray-200 font-medium">{driver}</p>
          </div>
        )}
        {summary && (
          <div>
            <p className="text-xs text-gray-400 mb-1">Summary</p>
            <p className="text-sm text-gray-300">{summary}</p>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
