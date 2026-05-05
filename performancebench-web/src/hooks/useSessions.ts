import { useQuery, useMutation, useQueryClient, keepPreviousData } from '@tanstack/react-query';
import { api } from '@/lib/api';

// ─── Data Types (snake_case matching server JSON response) ────────────────

export interface Session {
  id: string;
  device_id: string;
  platform: string;
  target_kind: string;
  app_package: string;
  app_name: string | null;
  app_version: string | null;
  app_version_code: number | null;
  started_at: number;
  ended_at: number | null;
  duration_ms: number | null;
  title: string | null;
  notes: string | null;
  tags: string | null; // JSON array string
  tags_kv_json: string | null;
  target_fps: number;
  production_mode: number;
  strict_mode: number;
  injected: number;
  has_video: number;
  collection_id: string | null;
  project_id: string | null;
  user_id: string | null;
  is_uploaded: number;
}

export interface SessionStats {
  session_id: string;
  fps_median: number | null;
  fps_min: number | null;
  fps_max: number | null;
  fps_1pct_low: number | null;
  fps_stability: number | null;
  frame_time_p95: number | null;
  fps_histogram: string | null;
  variability_index: number | null;
  frame_ratio_jank_total: number | null;
  cpu_avg_pct: number | null;
  cpu_peak_pct: number | null;
  cpu_avg_pct_freq_norm: number | null;
  cpu_peak_pct_freq_norm: number | null;
  memory_avg_kb: number | null;
  memory_peak_kb: number | null;
  mem_java_avg_kb: number | null;
  mem_java_peak_kb: number | null;
  mem_native_avg_kb: number | null;
  mem_native_peak_kb: number | null;
  mem_graphics_avg_kb: number | null;
  mem_graphics_peak_kb: number | null;
  mem_stack_avg_kb: number | null;
  mem_code_avg_kb: number | null;
  mem_system_avg_kb: number | null;
  mem_webview_avg_kb: number | null;
  mem_growth_kb: number | null;
  mem_trend_slope_kb_per_min: number | null;
  gpu_avg_pct: number | null;
  gpu_peak_pct: number | null;
  battery_drain_pct: number | null;
  battery_drain_per_hour: number | null;
  battery_temp_max_c: number | null;
  mah_consumed: number | null;
  avg_power_mw: number | null;
  total_power_mwh: number | null;
  estimated_playtime_h: number | null;
  has_charging_period: number;
  jank_total: number | null;
  jank_small_total: number | null;
  jank_big_total: number | null;
  jank_ratio_total: number | null;
  jank_per_min: number | null;
  net_total_tx_kb: number | null;
  net_total_rx_kb: number | null;
  net_wifi_total_tx_kb: number | null;
  net_wifi_total_rx_kb: number | null;
  net_cellular_total_tx_kb: number | null;
  net_cellular_total_rx_kb: number | null;
  net_other_total_tx_kb: number | null;
  net_other_total_rx_kb: number | null;
  net_wifi_avg_kbps: number | null;
  net_cellular_avg_kbps: number | null;
  thermal_peak: number | null;
  launch_complete_ms: number | null;
  duration_ms: number | null;
}

export interface MetricSample {
  id: number | null;
  session_id: string;
  timestamp: number;
  fps: number | null;
  jank_count: number | null;
  jank_small_count: number | null;
  jank_big_count: number | null;
  jank_ratio_count: number | null;
  frametimes_json: string | null;
  cpu_system_pct: number | null;
  cpu_app_pct: number | null;
  cpu_app_pct_freq_norm: number | null;
  cpu_cores: string | null;
  memory_pss_kb: number | null;
  memory_java_kb: number | null;
  memory_native_kb: number | null;
  memory_graphics_kb: number | null;
  memory_stack_kb: number | null;
  memory_code_kb: number | null;
  memory_system_kb: number | null;
  memory_webview_kb: number | null;
  battery_pct: number | null;
  battery_ma: number | null;
  battery_mv: number | null;
  battery_temp_c: number | null;
  charging: number;
  charging_source: string | null;
  wifi_active: number | null;
  net_tx_bytes: number | null;
  net_rx_bytes: number | null;
  net_wifi_tx_bytes: number | null;
  net_wifi_rx_bytes: number | null;
  net_cellular_tx_bytes: number | null;
  net_cellular_rx_bytes: number | null;
  net_other_tx_bytes: number | null;
  net_other_rx_bytes: number | null;
  thermal_status: number | null;
  gpu_pct: number | null;
  gpu_freq_mhz: number | null;
  gpu_mem_kb: number | null;
  disk_read_kb: number | null;
  disk_write_kb: number | null;
  screen_brightness: number | null;
  volume_pct: number | null;
}

export interface Marker {
  id: number | null;
  session_id: string;
  group_id: number | null;
  label: string;
  started_at: number;
  ended_at: number | null;
  auto_screenshot: number;
  notes: string | null;
}

export interface DetectedIssue {
  id: number | null;
  session_id: string;
  rule_id: string;
  severity: string;
  metric: string | null;
  observed_value: number | null;
  threshold_value: number | null;
  message: string;
  created_at: number;
}

/** Full session detail returned by GET /api/v1/sessions/:id */
export interface SessionDetail extends Session {
  session_stats: SessionStats | null;
  metric_samples: MetricSample[];
  markers: Marker[];
  detected_issues: DetectedIssue[];
}

export interface SessionListResponse {
  data: Session[];
  total: number;
  offset: number;
  limit: number;
}

export interface SessionFilters {
  appName?: string;
  deviceModel?: string;
  tags?: string;
  projectId?: string;
  dateFrom?: string;
  dateTo?: string;
}

// ─── Hooks ────────────────────────────────────────────────────────────────

export function useSessions(
  offset: number = 0,
  limit: number = 25,
  filters: SessionFilters = {},
) {
  const params = new URLSearchParams({
    offset: String(offset),
    limit: String(limit),
  });
  if (filters.appName) params.set('app_name', filters.appName);
  if (filters.deviceModel) params.set('device_model', filters.deviceModel);
  if (filters.tags) params.set('tags', filters.tags);
  if (filters.projectId) params.set('project_id', filters.projectId);
  if (filters.dateFrom) params.set('date_from', filters.dateFrom);
  if (filters.dateTo) params.set('date_to', filters.dateTo);

  return useQuery({
    queryKey: ['sessions', { offset, limit, ...filters }],
    queryFn: () =>
      api.get<SessionListResponse>(`/api/v1/sessions?${params.toString()}`),
    placeholderData: keepPreviousData,
  });
}

export function useDeleteSession() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (sessionId: string) =>
      api.delete(`/api/v1/sessions/${sessionId}`),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ['sessions'] }),
  });
}

export function useSession(sessionId: string) {
  return useQuery({
    queryKey: ['sessions', sessionId],
    queryFn: () =>
      api.get<SessionDetail>(`/api/v1/sessions/${sessionId}`),
    enabled: !!sessionId,
  });
}
