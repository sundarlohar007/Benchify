import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api';

// ─── Types ──────────────────────────────────────────────────────────────────

export interface AlertRule {
  id: string;
  user_id: string;
  name: string;
  metric_name: string;
  condition: string;
  threshold: number;
  duration_seconds: number;
  channels: NotificationChannel[];
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface AlertEvent {
  id: string;
  rule_id: string;
  session_id: string | null;
  metric_value: number;
  threshold: number;
  acknowledged_at: string | null;
  acknowledged_by: string | null;
  fired_at: string;
}

export interface NotificationChannel {
  type: 'email' | 'slack' | 'webhook';
  to?: string;
  webhook_url?: string;
  url?: string;
  secret?: string;
}

export interface CreateAlertRuleBody {
  name: string;
  metric_name: string;
  condition: string;
  threshold: number;
  duration_seconds: number;
  channels: NotificationChannel[];
}

export interface UpdateAlertRuleBody {
  name?: string;
  metric_name?: string;
  condition?: string;
  threshold?: number;
  duration_seconds?: number;
  channels?: NotificationChannel[];
  is_active?: boolean;
}

export interface AlertEventFilters {
  rule_id?: string;
  session_id?: string;
  limit?: number;
  offset?: number;
}

// ─── Hooks ──────────────────────────────────────────────────────────────────

/** List all alert rules for the current user. */
export function useAlertRules() {
  return useQuery({
    queryKey: ['alerts', 'rules'],
    queryFn: () =>
      api.get<{ data: AlertRule[] }>('/api/v1/alerts/rules'),
  });
}

/** Create a new alert rule. */
export function useCreateAlertRule() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (body: CreateAlertRuleBody) =>
      api.post<AlertRule>('/api/v1/alerts/rules', body),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ['alerts', 'rules'] }),
  });
}

/** Update an alert rule. */
export function useUpdateAlertRule() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, body }: { id: string; body: UpdateAlertRuleBody }) =>
      api.put<AlertRule>(`/api/v1/alerts/rules/${id}`, body),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ['alerts', 'rules'] }),
  });
}

/** Delete (deactivate) an alert rule. */
export function useDeleteAlertRule() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) =>
      api.delete(`/api/v1/alerts/rules/${id}`),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ['alerts', 'rules'] }),
  });
}

/** List alert events with filters. */
export function useAlertEvents(filters: AlertEventFilters = {}) {
  const params = new URLSearchParams();
  if (filters.rule_id) params.set('rule_id', filters.rule_id);
  if (filters.session_id) params.set('session_id', filters.session_id);
  if (filters.limit != null) params.set('limit', String(filters.limit));
  if (filters.offset != null) params.set('offset', String(filters.offset));

  return useQuery({
    queryKey: ['alerts', 'events', filters],
    queryFn: () =>
      api.get<{ data: AlertEvent[] }>(
        `/api/v1/alerts/events?${params.toString()}`,
      ),
  });
}

// ─── Constants ──────────────────────────────────────────────────────────────

export const METRIC_OPTIONS = [
  { value: 'fps_median', label: 'FPS Median' },
  { value: 'fps_stability', label: 'FPS Stability' },
  { value: 'fps_min', label: 'FPS Min' },
  { value: 'cpu_avg_pct', label: 'CPU Avg %' },
  { value: 'cpu_peak_pct', label: 'CPU Peak %' },
  { value: 'memory_avg_kb', label: 'Memory Avg KB' },
  { value: 'memory_peak_kb', label: 'Memory Peak KB' },
  { value: 'gpu_avg_pct', label: 'GPU Avg %' },
  { value: 'battery_drain_pct', label: 'Battery Drain %' },
  { value: 'battery_temp_max_c', label: 'Battery Temp Max' },
  { value: 'jank_per_min', label: 'Jank Per Min' },
  { value: 'thermal_peak', label: 'Thermal Peak' },
] as const;

export const CONDITION_OPTIONS = [
  { value: 'lt', label: 'less than (<)' },
  { value: 'gt', label: 'greater than (>)' },
  { value: 'lte', label: 'less than or equal (<=)' },
  { value: 'gte', label: 'greater than or equal (>=)' },
] as const;
