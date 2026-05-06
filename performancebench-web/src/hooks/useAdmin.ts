import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api';

// ─── Types ──────────────────────────────────────────────────────────────────

export interface SsoConfig {
  id: string;
  provider_type: string;
  name: string;
  config: Record<string, unknown>;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface UserDetail {
  id: string;
  email: string;
  display_name: string | null;
  role: string;
  is_active: boolean;
  auth_source: string;
  sso_provider: string | null;
  created_at: string;
  updated_at: string;
}

export interface UserListResponse {
  users: UserDetail[];
  total: number;
}

export interface CreateSsoConfigBody {
  provider_type: string;
  name: string;
  config: Record<string, unknown>;
  is_active?: boolean;
}

export interface UpdateSsoConfigBody {
  name?: string;
  config?: Record<string, unknown>;
  is_active?: boolean;
}

// ─── SSO Config Hooks ──────────────────────────────────────────────────────

export function useSsoConfigs() {
  return useQuery({
    queryKey: ['admin', 'sso-configs'],
    queryFn: () => api.get<SsoConfig[]>('/api/v1/admin/sso-configs'),
  });
}

export function useCreateSsoConfig() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (body: CreateSsoConfigBody) =>
      api.post<SsoConfig>('/api/v1/admin/sso-configs', body),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ['admin', 'sso-configs'] }),
  });
}

export function useUpdateSsoConfig() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, body }: { id: string; body: UpdateSsoConfigBody }) =>
      api.put<SsoConfig>(`/api/v1/admin/sso-configs/${id}`, body),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ['admin', 'sso-configs'] }),
  });
}

export function useDeleteSsoConfig() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) =>
      api.delete(`/api/v1/admin/sso-configs/${id}`),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ['admin', 'sso-configs'] }),
  });
}

// ─── User Management Hooks ─────────────────────────────────────────────────

export interface UserListParams {
  role?: string;
  offset?: number;
  limit?: number;
}

export function useUsers(params: UserListParams = {}) {
  const search = new URLSearchParams();
  if (params.role) search.set('role', params.role);
  if (params.offset != null) search.set('offset', String(params.offset));
  if (params.limit != null) search.set('limit', String(params.limit));

  return useQuery({
    queryKey: ['admin', 'users', params],
    queryFn: () =>
      api.get<UserListResponse>(`/api/v1/admin/users?${search.toString()}`),
  });
}

export function useUpdateUserRole() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, role }: { id: string; role: string }) =>
      api.put<UserDetail>(`/api/v1/admin/users/${id}/role`, { role }),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ['admin', 'users'] }),
  });
}

export function useUpdateUserStatus() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, isActive }: { id: string; isActive: boolean }) =>
      api.put<UserDetail>(`/api/v1/admin/users/${id}/status`, {
        is_active: isActive,
      }),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ['admin', 'users'] }),
  });
}
