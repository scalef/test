"use client";

import { useState } from "react";
import { AlertTriangle } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { useEmergencyStop } from "@/hooks/use-api";

interface EmergencyStopButtonProps {
  active?: boolean;
}

export function EmergencyStopButton({ active }: EmergencyStopButtonProps) {
  const [open, setOpen] = useState(false);
  const { mutate, isPending } = useEmergencyStop();

  if (active) {
    return (
      <div className="flex h-20 w-full items-center justify-center rounded-lg border-2 border-red-600 bg-red-950/40">
        <div className="flex items-center gap-2 text-red-400">
          <AlertTriangle className="h-5 w-5 animate-pulse" />
          <span className="font-bold text-lg">EMERGENCY STOP ACTIVE</span>
        </div>
      </div>
    );
  }

  return (
    <>
      <Button
        variant="destructive"
        className="h-20 w-full text-lg font-bold"
        onClick={() => setOpen(true)}
        disabled={isPending}
      >
        <AlertTriangle className="mr-2 h-5 w-5" />
        EMERGENCY STOP
      </Button>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle className="text-red-400">Confirm Emergency Stop</DialogTitle>
            <DialogDescription>
              This will immediately halt ALL trading activity. No orders will be
              sent until the system is manually restarted. This cannot be undone
              via the API.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button
              variant="destructive"
              onClick={() => {
                mutate();
                setOpen(false);
              }}
              disabled={isPending}
            >
              Confirm Emergency Stop
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
