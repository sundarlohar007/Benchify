export class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

const REFRESH_TOKEN_KEY = 'pb_refresh_token';

let refreshTokenMemory: string | null =
  typeof localStorage !== 'undefined' ? localStorage.getItem(REFRESH_TOKEN_KEY) : null;

/** Store or clear the refresh token (memory + localStorage). B-162 */
export function setRefreshToken(token: string | null): void {
  refreshTokenMemory = token;
  if (typeof localStorage === 'undefined') return;
  if (token) localStorage.setItem(REFRESH_TOKEN_KEY, token);
  else localStorage.removeItem(REFRESH_TOKEN_KEY);
}

export function getRefreshToken(): string | null {
  return refreshTokenMemory ?? (typeof localStorage !== 'undefined' ? localStorage.getItem(REFRESH_TOKEN_KEY) : null);
}

let refreshInFlight: Promise<boolean> | null = null;

async function tryRefreshOnce(): Promise<boolean> {
  const rt = getRefreshToken();
  if (!rt) return false;
  try {
    const res = await fetch('/auth/refresh', {
      method: 'POST',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken: rt }),
    });
    if (!res.ok) {
      setRefreshToken(null);
      return false;
    }
    const data = (await res.json().catch(() => ({}))) as { refreshToken?: string };
    if (data.refreshToken) setRefreshToken(data.refreshToken);
    return true;
  } catch {
    return false;
  }
}

async function apiFetch<T>(
  path: string,
  options: RequestInit = {},
  retried = false,
): Promise<T> {
  const res = await fetch(path, {
    ...options,
    credentials: 'include',
    headers: {
      'Content-Type': 'application/json',
      ...options.headers,
    },
  });

  // B-162: on 401, try refresh once then retry the original request.
  if (
    res.status === 401 &&
    !retried &&
    path !== '/auth/refresh' &&
    path !== '/auth/login' &&
    path !== '/auth/logout'
  ) {
    refreshInFlight ??= tryRefreshOnce().finally(() => {
      refreshInFlight = null;
    });
    const ok = await refreshInFlight;
    if (ok) return apiFetch<T>(path, options, true);
  }

  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new ApiError(
      res.status,
      body.code || 'UNKNOWN',
      body.message || res.statusText,
    );
  }
  // Handle 204 No Content and empty bodies (e.g., DELETE responses)
  const contentLength = res.headers.get('content-length');
  if (res.status === 204 || contentLength === '0') {
    return undefined as unknown as T;
  }
  return res.json();
}

export const api = {
  get: <T>(path: string) => apiFetch<T>(path),
  post: <T>(path: string, body: unknown) =>
    apiFetch<T>(path, { method: 'POST', body: JSON.stringify(body) }),
  put: <T>(path: string, body: unknown) =>
    apiFetch<T>(path, { method: 'PUT', body: JSON.stringify(body) }),
  delete: <T>(path: string) =>
    apiFetch<T>(path, { method: 'DELETE' }),

  /**
   * Download a file from the API (e.g., audit export CSV/JSON).
   * Triggers a browser download via a hidden anchor element.
   */
  download: async (path: string, filename: string): Promise<void> => {
    const res = await fetch(path, { credentials: 'include' });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      throw new ApiError(
        res.status,
        body.code || 'UNKNOWN',
        body.message || res.statusText,
      );
    }
    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
  },

  /**
   * POST with FormData for multipart uploads (e.g., SAML metadata XML).
   */
  postForm: async <T>(path: string, formData: FormData): Promise<T> => {
    const res = await fetch(path, {
      method: 'POST',
      credentials: 'include',
      body: formData,
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      throw new ApiError(
        res.status,
        body.code || 'UNKNOWN',
        body.message || res.statusText,
      );
    }
    return res.json();
  },
};
