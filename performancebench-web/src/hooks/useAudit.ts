import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api';

// ─── Types ──────────────────────────────────────────────────────────────────

export interface AuditEventResponse {
  id: string;
  event_type: string;
  event_category: string;
  actor_id: string | null;
  actor_email: string | null;
  target_type: string | null;
  target_id: string | null;
  details: Record<string, unknown>;
  ip_address: string | null;
  user_agent: string | null;
  created_at: string;
}

export interface AuditListResponse {
  events: AuditEventResponse[];
  total: number;
  offset: number;
  limit: number;
}

export interface AuditListParams {
  category?: string;
  eventType?: string;
  from?: string;
  to?: string;
  offset?: number;
  limit?: number;
}

export interface AuditPurgeResponse {
  deleted_count: number;
  purged_before: string;
}

// ─── Audit Hooks ───────────────────────────────────────────────────────────

export function useAuditEvents(params: AuditListParams = {}) {
  const search = new URLSearchParams();
  if (params.category) search.set('category', params.category);
  if (params.eventType) search.set('eventType', params.eventType);
  if (params.from) search.set('from', params.from);
  if (params.to) search.set('to', params.to);
  if (params.offset != null) search.set('offset', String(params.offset));
  if (params.limit != null) search.set('limit', String(params.limit));

  return useQuery({
    queryKey: ['audit', 'events', params],
    queryFn: () =>
      api.get<AuditListResponse>(
        `/api/v1/audit/events?${search.toString()}`,
      ),
  });
}

/**
 * Export audit events as CSV or JSON file download.
 * Uses the api.download method which triggers a browser download.
 */
export function useAuditExport() {
  return useMutation({
    mutationFn: async (params: {
      format: 'csv' | 'json';
      from?: string;
      to?: string;
      category?: string;
    }) => {
      const search = new URLSearchParams({ format: params.format });
      if (params.from) search.set('from', params.from);
      if (params.to) search.set('to', params.to);
      if (params.category) search.set('category', params.category);

      const dateStr = new Date().toISOString().slice(0, 10);
      const ext = params.format === 'csv' ? 'csv' : 'json';
      await api.download(
        `/api/v1/audit/export?${search.toString()}`,
        `audit-export-${dateStr}.${ext}`,
      );
    },
  });
}

/**
 * Purge audit events older than a given date.
 * Admin-only operation — requires minimum 30-day retention.
 */
export function usePurgeAuditEvents() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (before: string) =>
      api.delete<AuditPurgeResponse>(
        `/api/v1/audit/events?before=${encodeURIComponent(before)}`,
      ),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ['audit', 'events'] }),
  });
}
