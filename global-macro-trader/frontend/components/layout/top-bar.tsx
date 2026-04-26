"use client";

import { Play, Pause, RotateCw } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useHealth, useRunCycle, usePauseScheduler, useResumeScheduler, useStatus } from "@/hooks/use-api";
import { cn } from "@/lib/utils";

export function TopBar() {
  const { data: health, isError } = useHealth();
  const { data: status } = useStatus();
  const runCycle = useRunCycle();
  const pause = usePauseScheduler();
  const resume = useResumeScheduler();

  const isConnected = !isError && !!health;

  return (
    <header className="flex h-14 items-center justify-between border-b border-gray-800 bg-gray-950 px-4">
      <div className="flex items-center gap-2">
        <span
          className={cn(
            "h-2.5 w-2.5 rounded-full",
            isConnected ? "bg-green-500" : "bg-red-500"
          )}
        />
        <span className="text-xs text-gray-400">
          {isConnected ? "API connected" : "API offline"}
        </span>
      </div>

      <div className="flex items-center gap-2">
        {status?.scheduler_paused ? (
          <Button
            size="sm"
            variant="outline"
            onClick={() => resume.mutate()}
            disabled={resume.isPending}
          >
            <Play className="h-3 w-3" />
            Resume
          </Button>
        ) : (
          <Button
            size="sm"
            variant="outline"
            onClick={() => pause.mutate()}
            disabled={pause.isPending}
          >
            <Pause className="h-3 w-3" />
            Pause
          </Button>
        )}
        <Button
          size="sm"
          variant="secondary"
          onClick={() => runCycle.mutate()}
          disabled={runCycle.isPending}
        >
          <RotateCw className={cn("h-3 w-3", runCycle.isPending && "animate-spin")} />
          Run Cycle
        </Button>
      </div>
    </header>
  );
}
