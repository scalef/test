"use client";

import {
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import { api } from "@/lib/api";

export function useStatus() {
  return useQuery({
    queryKey: ["status"],
    queryFn: api.getStatus,
    refetchInterval: 10_000,
  });
}

export function useHealth() {
  return useQuery({
    queryKey: ["health"],
    queryFn: api.getHealth,
    refetchInterval: 30_000,
    retry: false,
  });
}

export function useAnalysis() {
  return useQuery({
    queryKey: ["analysis"],
    queryFn: api.getAnalysis,
    refetchInterval: 30_000,
  });
}

export function useSignals() {
  return useQuery({
    queryKey: ["signals"],
    queryFn: api.getSignals,
    refetchInterval: 15_000,
  });
}

export function useSignalActions() {
  const qc = useQueryClient();
  const invalidate = () => {
    qc.invalidateQueries({ queryKey: ["signals"] });
  };

  const approve = useMutation({
    mutationFn: api.approveSignal,
    onSuccess: invalidate,
  });

  const reject = useMutation({
    mutationFn: api.rejectSignal,
    onSuccess: invalidate,
  });

  const sendDemo = useMutation({
    mutationFn: api.sendSignalToDemo,
    onSuccess: () => {
      invalidate();
      qc.invalidateQueries({ queryKey: ["trades"] });
      qc.invalidateQueries({ queryKey: ["status"] });
    },
  });

  return { approve, reject, sendDemo };
}

export function useTrades(status?: string) {
  return useQuery({
    queryKey: ["trades", status],
    queryFn: () => api.getTrades(status),
    refetchInterval: 30_000,
  });
}

export function useSettings() {
  return useQuery({
    queryKey: ["settings"],
    queryFn: api.getSettings,
  });
}

export function useUpdateSettings() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: api.updateSettings,
    onSuccess: () => qc.invalidateQueries({ queryKey: ["settings"] }),
  });
}

export function useEmergencyStop() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: api.emergencyStop,
    onSuccess: () => qc.invalidateQueries({ queryKey: ["status"] }),
  });
}

export function useRunCycle() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: api.runCycle,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["status"] });
      qc.invalidateQueries({ queryKey: ["signals"] });
      qc.invalidateQueries({ queryKey: ["analysis"] });
    },
  });
}

export function usePauseScheduler() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: api.pauseScheduler,
    onSuccess: () => qc.invalidateQueries({ queryKey: ["status"] }),
  });
}

export function useResumeScheduler() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: api.resumeScheduler,
    onSuccess: () => qc.invalidateQueries({ queryKey: ["status"] }),
  });
}
