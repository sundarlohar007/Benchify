import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api';

export interface User {
  id: string;
  email: string;
  name: string;
  role: string;
  created_at: string;
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

  return {
    user: user ?? null,
    isLoading,
    isAuthenticated: !!user,
    error,
  };
}

/**
 * Login mutation — POST /auth/login.
 * On success, invalidate auth query so ProtectedRoute picks up the user.
 */
export function useLogin() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (credentials: { email: string; password: string }) =>
      api.post<LoginResponse>('/auth/login', credentials),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['auth', 'me'] });
    },
  });
}

/**
 * Logout mutation — POST /auth/logout.
 */
export function useLogout() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: () => api.post<{ ok: boolean }>('/auth/logout', {}),
    onSuccess: () => {
      queryClient.clear();
    },
  });
}
