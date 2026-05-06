import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';

// ─── Data Types ────────────────────────────────────────────────────────────

export interface TrendPoint {
  timestamp: string;
  sessionId: string;
  appName: string;
  value: number | null;
  label: string | null;
}

export interface TrendResponse {
  data: TrendPoint[];
}

export interface TrendFilters {
  start_date: string;
  end_date: string;
  app_name?: string;
}

// ─── Hook Factory ──────────────────────────────────────────────────────────

function buildTrendParams(filters: TrendFilters): URLSearchParams {
  const params = new URLSearchParams({
    start_date: filters.start_date,
    end_date: filters.end_date,
  });
  if (filters.app_name) params.set('app_name', filters.app_name);
  return params;
}

export function useFpsTrends(filters: TrendFilters) {
  const params = buildTrendParams(filters);
  return useQuery({
    queryKey: ['trends', 'fps', filters],
    queryFn: () =>
      api.get<TrendResponse>(`/api/v1/trends/fps?${params.toString()}`),
    enabled: !!filters.start_date && !!filters.end_date,
  });
}

export function useCpuTrends(filters: TrendFilters) {
  const params = buildTrendParams(filters);
  return useQuery({
    queryKey: ['trends', 'cpu', filters],
    queryFn: () =>
      api.get<TrendResponse>(`/api/v1/trends/cpu?${params.toString()}`),
    enabled: !!filters.start_date && !!filters.end_date,
  });
}

export function useMemoryTrends(filters: TrendFilters) {
  const params = buildTrendParams(filters);
  return useQuery({
    queryKey: ['trends', 'memory', filters],
    queryFn: () =>
      api.get<TrendResponse>(`/api/v1/trends/memory?${params.toString()}`),
    enabled: !!filters.start_date && !!filters.end_date,
  });
}

export function useBatteryTrends(filters: TrendFilters) {
  const params = buildTrendParams(filters);
  return useQuery({
    queryKey: ['trends', 'battery', filters],
    queryFn: () =>
      api.get<TrendResponse>(`/api/v1/trends/battery?${params.toString()}`),
    enabled: !!filters.start_date && !!filters.end_date,
  });
}

export function useNetworkTrends(filters: TrendFilters) {
  const params = buildTrendParams(filters);
  return useQuery({
    queryKey: ['trends', 'network', filters],
    queryFn: () =>
      api.get<TrendResponse>(`/api/v1/trends/network?${params.toString()}`),
    enabled: !!filters.start_date && !!filters.end_date,
  });
}

// ─── KPI Configuration ─────────────────────────────────────────────────────

export const KPI_CONFIG = [
  { id: 'fps', label: 'FPS', color: '#569CD6', unit: 'fps', hook: useFpsTrends },
  { id: 'cpu', label: 'CPU', color: '#4EC9B0', unit: '%', hook: useCpuTrends },
  { id: 'memory', label: 'Memory', color: '#CE9178', unit: 'KB', hook: useMemoryTrends },
  { id: 'battery', label: 'Battery', color: '#DCDCAA', unit: '%/hr', hook: useBatteryTrends },
  { id: 'network', label: 'Network', color: '#4FC1FF', unit: 'kbps', hook: useNetworkTrends },
] as const;

// ─── Summary helpers ────────────────────────────────────────────────────────

export interface TrendSummary {
  avg: number;
  min: { value: number; sessionId: string } | null;
  max: { value: number; sessionId: string } | null;
  count: number;
  trend: 'up' | 'down' | 'flat';
  changePct: number;
}

export function computeTrendSummary(points: TrendPoint[]): TrendSummary | null {
  const values = points
    .map((p) => p.value)
    .filter((v): v is number => v !== null);
  if (values.length < 2) return null;

  const avg = values.reduce((a, b) => a + b, 0) / values.length;
  let minVal = Infinity;
  let maxVal = -Infinity;
  let minPt: TrendPoint | null = null;
  let maxPt: TrendPoint | null = null;

  for (const pt of points) {
    if (pt.value == null) continue;
    if (pt.value < minVal) {
      minVal = pt.value;
      minPt = pt;
    }
    if (pt.value > maxVal) {
      maxVal = pt.value;
      maxPt = pt;
    }
  }

  // Compute trend direction from first and last valid points
  const firstHalf = values.slice(0, Math.floor(values.length / 2));
  const secondHalf = values.slice(Math.floor(values.length / 2));
  const firstAvg =
    firstHalf.length > 0
      ? firstHalf.reduce((a, b) => a + b, 0) / firstHalf.length
      : 0;
  const secondAvg =
    secondHalf.length > 0
      ? secondHalf.reduce((a, b) => a + b, 0) / secondHalf.length
      : 0;
  const changePct =
    firstAvg !== 0 ? ((secondAvg - firstAvg) / Math.abs(firstAvg)) * 100 : 0;

  return {
    avg,
    min: minPt ? { value: minVal, sessionId: minPt.sessionId } : null,
    max: maxPt ? { value: maxVal, sessionId: maxPt.sessionId } : null,
    count: values.length,
    trend: changePct > 2 ? 'up' : changePct < -2 ? 'down' : 'flat',
    changePct: Math.round(changePct * 10) / 10,
  };
}
