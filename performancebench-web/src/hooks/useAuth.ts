import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api, getRefreshToken, setRefreshToken } from '@/lib/api';

export interface User {
  id: string;
  email: string;
  name: string;
  role: string;
  created_at: string;
  is_active?: boolean;
  auth_source?: string;
  sso_provider?: string | null;
  display_name?: string | null;
}

interface LoginResponse {
  user: User;
  refreshToken: string;
}

/**
 * Fetch current user from /auth/me.
 * Returns null when unauthenticated (401).
 */
export function useAuth() {
  const { data: user, isLoading, error } = useQuery({
    queryKey: ['auth', 'me'],
    queryFn: () => api.get<User>('/auth/me'),
    retry: false,
    staleTime: 5 * 60 * 1000,
  });

  const isAdmin = user?.role === 'admin';
  const isAuditor = user?.role === 'auditor';
  const canAccessAdmin = isAdmin || isAuditor;

  return {
    user: user ?? null,
    isLoading,
    isAuthenticated: !!user,
    isAdmin,
    isAuditor,
    canAccessAdmin,
    error,
  };
}

/**
 * Login mutation — POST /auth/login.
 * On success, store refreshToken (B-162) and invalidate auth query.
 */
export function useLogin() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (credentials: { email: string; password: string }) =>
      api.post<LoginResponse>('/auth/login', credentials),
    onSuccess: (data) => {
      if (data.refreshToken) setRefreshToken(data.refreshToken);
      queryClient.invalidateQueries({ queryKey: ['auth', 'me'] });
    },
  });
}

/**
 * Logout mutation — POST /auth/logout.
 * Sends stored refreshToken so the server can revoke it.
 */
export function useLogout() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: () => {
      const refreshToken = getRefreshToken() ?? '';
      return api.post<{ ok: boolean }>('/auth/logout', { refreshToken });
    },
    onSuccess: () => {
      setRefreshToken(null);
      queryClient.clear();
    },
    onError: () => {
      setRefreshToken(null);
      queryClient.clear();
    },
  });
}
