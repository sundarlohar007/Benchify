---
phase: 99-web-dashboard-review
reviewed: 2026-05-07T00:00:00Z
depth: deep
files_reviewed: 44
files_reviewed_list:
  - performancebench-web\src\main.tsx
  - performancebench-web\src\index.css
  - performancebench-web\src\vite-env.d.ts
  - performancebench-web\src\routeTree.gen.ts
  - performancebench-web\src\lib\api.ts
  - performancebench-web\src\lib\constants.ts
  - performancebench-web\src\lib\utils.ts
  - performancebench-web\src\components\auth\LoginForm.tsx
  - performancebench-web\src\components\auth\ProtectedRoute.tsx
  - performancebench-web\src\components\layout\AppLayout.tsx
  - performancebench-web\src\components\layout\Header.tsx
  - performancebench-web\src\components\layout\Sidebar.tsx
  - performancebench-web\src\components\theme\ThemeProvider.tsx
  - performancebench-web\src\components\sessions\SessionFilters.tsx
  - performancebench-web\src\components\sessions\SessionTable.tsx
  - performancebench-web\src\components\sessions\SessionDetailTabs.tsx
  - performancebench-web\src\components\charts\LiveChart.tsx
  - performancebench-web\src\components\charts\TrendChart.tsx
  - performancebench-web\src\components\admin\RoleBadge.tsx
  - performancebench-web\src\components\admin\UserTable.tsx
  - performancebench-web\src\components\admin\SsoConfigForm.tsx
  - performancebench-web\src\components\admin\AuditLogTable.tsx
  - performancebench-web\src\components\admin\AuditExportButton.tsx
  - performancebench-web\src\hooks\useAuth.ts
  - performancebench-web\src\hooks\useSessions.ts
  - performancebench-web\src\hooks\useWebSocket.ts
  - performancebench-web\src\hooks\useTrends.ts
  - performancebench-web\src\hooks\useAlerts.ts
  - performancebench-web\src\hooks\useAdmin.ts
  - performancebench-web\src\hooks\useAudit.ts
  - performancebench-web\src\hooks\useTeams.ts
  - performancebench-web\src\routes\__root.tsx
  - performancebench-web\src\routes\index.tsx
  - performancebench-web\src\routes\sessions\index.tsx
  - performancebench-web\src\routes\sessions\$sessionId.tsx
  - performancebench-web\src\routes\settings\index.tsx
  - performancebench-web\src\routes\settings\tokens.tsx
  - performancebench-web\src\routes\settings\sso.tsx
  - performancebench-web\src\routes\live.tsx
  - performancebench-web\src\routes\trends.tsx
  - performancebench-web\src\routes\reports.tsx
  - performancebench-web\src\routes\alerts.tsx
  - performancebench-web\src\routes\lenses.tsx
  - performancebench-web\src\routes\admin\users.tsx
  - performancebench-web\src\routes\admin\audit.tsx
findings:
  high: 4
  medium: 6
  total: 10
status: issues_found
---

# Code Review Report: Benchify Web Dashboard

**Reviewed:** 2026-05-07
**Depth:** deep (cross-file analysis, import tracing, call chain verification)
**Files Reviewed:** 44
**Status:** issues_found

## Summary

Review of the React/TypeScript web dashboard (TanStack Router + TanStack Query + Chart.js). The architecture is clean and follows modern React patterns. Auth is cookie-based with `credentials: 'include'`. No `eval()`, `dangerouslySetInnerHTML`, or hardcoded secrets were found. However, several HIGH-severity issues were identified: missing role-based authorization on admin routes, a race condition/leak in the live WebSocket page, CSV injection in exports, and unbounded WebSocket reconnection.

---

## HIGH Severity Issues

### H-01: Admin routes lack role-based authorization -- any authenticated user can access /admin 

**File:** `performancebench-web/src/components/auth/ProtectedRoute.tsx:9-25`
**Related:** `performancebench-web/src/routes/admin/users.tsx`, `performancebench-web/src/routes/admin/audit.tsx`

**Problem:** `ProtectedRoute` only checks `isAuthenticated` (line 20), not user role. Admin page components wrap in `<ProtectedRoute>`, meaning **any authenticated user** (viewer, operator, etc.) can navigate directly to `/admin/users` or `/admin/audit` and interact with admin controls. The sidebar conditionally hides the links, but there is no route-level guard -- direct URL navigation bypasses the sidebar entirely.

The `beforeLoad` hook in `/admin/users` is empty:
```typescript
// admin/users.tsx:10-12
beforeLoad: ({ context }) => {
    // Client-side role guard — server enforces authorization
},
```
And `/admin/audit` has no `beforeLoad` at all:
```typescript
// admin/audit.tsx:20-22
export const Route = createFileRoute('/admin/audit')({
    component: AuditLogPage,
});
```

**Fix:** Add route-level role guards using TanStack Router's `beforeLoad`:

```typescript
// admin/users.tsx
beforeLoad: ({ context }) => {
    const queryClient = context.queryClient;
    const user = queryClient.getQueryData<User>(['auth', 'me']);
    if (!user || user.role !== 'admin') {
        throw redirect({ to: '/sessions' });
    }
},
```

Alternatively, create an `AdminRoute` wrapper component:
```typescript
function AdminRoute({ children }: { children: ReactNode }) {
    const { isAdmin, isLoading, isAuthenticated } = useAuth();
    if (isLoading) return <LoadingSpinner />;
    if (!isAuthenticated) return <LoginForm />;
    if (!isAdmin) return <Navigate to="/sessions" />;
    return <>{children}</>;
}
```

**Severity:** HIGH -- Authorization bypass. A viewer can see and potentially modify user roles and audit data. While the server *should* enforce authorization, relying solely on server-side enforcement without a client-side gate is a defense-in-depth gap for a security-sensitive admin area.

---

### H-02: Race condition, memory leak, and duplicate listeners in Live monitoring page

**File:** `performancebench-web/src/routes/live.tsx:76-101`

**Problem:** Three interconnected bugs in the live monitoring WebSocket integration:

**Bug A (lines 88-90):** `sampleListenerRef` is a plain object, not `useRef`. A new object is created every render, so `sampleListenerRef.current` is always `null` at the start of each render. This means a new listener is added on every render when `wsSessionId` is truthy.
```typescript
// BUG: plain object, recreated every render
const sampleListenerRef = {
    current: null as (() => void) | null,
};
```

**Bug B (lines 92-101):** The `onSample` subscription happens during the render body (not in `useEffect`). The cleanup function returned by `onSample` is assigned to `sampleListenerRef.current` but never invoked when the component unmounts or `wsSessionId` changes -- listeners accumulate indefinitely:
```typescript
if (wsSessionId && !sampleListenerRef.current) {
    sampleListenerRef.current = onSample((sample) => {
        // ...
    });
}
```

**Bug C (lines 82-85):** `setListenerActive(true)` is called directly during render (not in an event handler or effect), which is a React anti-pattern that triggers an immediate re-render and can cause infinite loops in StrictMode:
```typescript
const [listenerActive, setListenerActive] = useState(false);
if (!listenerActive && wsSessionId) {
    setListenerActive(true);
}
```

**Bug D (lines 77-79):** Dead `useState` call whose return value is discarded:
```typescript
useState(() => {
    // This runs on mount, but we need it after connection
});
```

**Fix:** Replace the ad-hoc listener management with a proper `useEffect`:
```typescript
const cleanupRef = useRef<(() => void) | null>(null);

useEffect(() => {
    if (!wsSessionId) return;
    
    // Clean up previous listener
    cleanupRef.current?.();
    
    const cleanup = onSample((sample) => {
        const values: Record<string, number | null> = {};
        for (const m of METRICS) {
            values[m.key] = m.extract(sample);
        }
        setCurrentValues(values);
        setConnected(true);
    });
    cleanupRef.current = cleanup;
    
    return () => {
        cleanup();
        cleanupRef.current = null;
    };
}, [wsSessionId, onSample, METRICS]);
```

Also remove the dead `useState` call (lines 77-79) and the `listenerActive` state logic (lines 82-85).

**Severity:** HIGH -- Memory leak (accumulating listeners never cleaned up), incorrect behavior (stale state from duplicate listener invocations), and potential infinite render loops. The live monitoring page is functionally broken under these conditions.

---

### H-03: CSV injection / corruption in session export -- no value escaping

**File:** `performancebench-web/src/routes/sessions/$sessionId.tsx:386-395`

**Problem:** The CSV export in `downloadExport` builds rows by naive comma-joining without escaping:
```typescript
const rows = samples.map((s) =>
    keys
        .map((k) => {
            const val = (s as Record<string, unknown>)[k];
            if (val == null) return '';
            return String(val);
        })
        .join(','),
);
```

This produces corrupted CSV in the following cases:
1. **Comma in value** (e.g., app name "My Game, Inc.") -- shifts columns
2. **Newline in value** (e.g., notes field with line breaks) -- breaks row structure
3. **Quotes in value** -- unescaped double-quotes break CSV parsing
4. **CSV formula injection** -- a value starting with `=`, `+`, `-`, or `@` can trigger formula execution in Excel/LibreOffice when the CSV is opened. For example, a malicious session title of `=cmd|'/c calc'!A0` could execute commands in some spreadsheet applications.

**Fix:** Properly escape CSV values:
```typescript
function escapeCsvValue(val: unknown): string {
    if (val == null) return '';
    const str = String(val);
    // Prevent formula injection: prefix with tab if starts with =, +, -, @
    const safeStr = /^[=+\-@]/.test(str) ? '\t' + str : str;
    // Escape quotes and wrap if contains special chars
    if (/[",\n\r]/.test(safeStr)) {
        return '"' + safeStr.replace(/"/g, '""') + '"';
    }
    return safeStr;
}
```

Apply `escapeCsvValue` in the row mapping:
```typescript
const rows = samples.map((s) =>
    keys.map((k) => escapeCsvValue((s as Record<string, unknown>)[k])).join(',')
);
```

**Severity:** HIGH -- CSV formula injection is a known attack vector (OWASP: CSV Injection). Data corruption on export makes the feature unreliable for any real-world data containing commas or newlines.

---

### H-04: WebSocket auto-reconnect has no backoff, no max retries

**File:** `performancebench-web/src/hooks/useWebSocket.ts:26-28`

**Problem:** On WebSocket close, the hook unconditionally reconnects after a fixed 2-second delay:
```typescript
ws.onclose = () => {
    reconnectTimeoutRef.current = window.setTimeout(connect, 2000);
};
```

This has two issues:
1. **No exponential backoff** -- a constantly-failing server gets hammered every 2 seconds indefinitely
2. **No max retry limit** -- if the server is down, this loops forever, consuming resources

**Fix:** Add exponential backoff with a cap and max retries:
```typescript
export function useWebSocket(sessionId: string | null) {
    const wsRef = useRef<WebSocket | null>(null);
    const reconnectTimeoutRef = useRef<number>();
    const listenersRef = useRef<Set<SampleListener>>(new Set());
    const retryCountRef = useRef(0);
    const MAX_RETRIES = 30;
    const BASE_DELAY = 1000;
    const MAX_DELAY = 30000;

    const connect = useCallback(() => {
        if (!sessionId) return;
        if (retryCountRef.current >= MAX_RETRIES) return;

        // ... create WebSocket ...

        ws.onopen = () => {
            retryCountRef.current = 0; // Reset on success
        };

        ws.onclose = () => {
            if (retryCountRef.current < MAX_RETRIES) {
                const delay = Math.min(BASE_DELAY * Math.pow(2, retryCountRef.current), MAX_DELAY);
                retryCountRef.current++;
                reconnectTimeoutRef.current = window.setTimeout(connect, delay);
            }
        };
    }, [sessionId]);

    // ... rest of hook
}
```

**Severity:** HIGH -- Unbounded retry with no backoff can degrade server performance (DoS-like behavior from a buggy client) and causes unnecessary resource consumption on both client and server.

---

## MEDIUM Severity Issues

### M-01: 401 unauthenticated response treated as query error rather than expected state

**File:** `performancebench-web/src/hooks/useAuth.ts:26-31`

**Problem:** The `useAuth` query fetches `/auth/me` with `retry: false`. When the user is not authenticated, the server returns 401, which the `apiFetch` function throws as an `ApiError`. TanStack Query treats this as a query error, populating `error`. While `isAuthenticated` correctly returns `false` (because `!!user` is `!!undefined` = `false`), the `error` field is populated with an "Unauthorized" message. This causes downstream confusion -- an unauthenticated user should not see error states, especially on the login page itself.

The `LoginForm` component doesn't use `useAuth()`, so it's unaffected. But any component that renders `ProtectedRoute` while loading will briefly see the error if it's checking `useAuth().error`.

**Fix:** Wrap the query function to return `null` on 401 (not throw):
```typescript
export function useAuth() {
    const { data: user, isLoading, error } = useQuery({
        queryKey: ['auth', 'me'],
        queryFn: async () => {
            try {
                return await api.get<User>('/auth/me');
            } catch (e) {
                if (e instanceof ApiError && e.status === 401) {
                    return null; // Not authenticated -- expected state
                }
                throw e;
            }
        },
        retry: false,
        staleTime: 5 * 60 * 1000,
    });

    return {
        user: user ?? null,
        isLoading,
        isAuthenticated: !!user,
        // ...rest
    };
}
```

**Severity:** MEDIUM -- Functional correctness issue. Error states for unauthenticated users are misleading and could confuse debugging.

---

### M-02: Bulk delete fires N independent API calls with no partial failure handling

**File:** `performancebench-web/src/routes/sessions/index.tsx:31-38`

**Problem:** `handleDeleteSelected` fires `deleteSession.mutate(id)` for each selected session:
```typescript
const handleDeleteSelected = useCallback(
    (ids: string[]) => {
        if (!confirm(`Delete ${ids.length} session(s)?\nThis cannot be undone.`))
            return;
        ids.forEach((id) => deleteSession.mutate(id));
    },
    [deleteSession],
);
```

Each mutation independently invalidates `['sessions']` on success (`useSessions.ts:218`). For N deletes, this triggers N cache invalidations and N re-fetches. More critically, if some deletes succeed and others fail (e.g., network issues mid-batch), the UI has no mechanism to report partial failure -- the user only sees the last error.

**Fix:** Either:
1. Add a bulk delete endpoint to the API and use a single mutation
2. Or implement partial-failure tracking:
```typescript
const handleDeleteSelected = useCallback(
    async (ids: string[]) => {
        if (!confirm(`Delete ${ids.length} session(s)?\nThis cannot be undone.`))
            return;
        const results = await Promise.allSettled(
            ids.map((id) => deleteSession.mutateAsync(id))
        );
        const failed = results.filter((r) => r.status === 'rejected').length;
        if (failed > 0) {
            alert(`${failed} of ${ids.length} deletions failed.`);
        }
    },
    [deleteSession],
);
```

**Severity:** MEDIUM -- Data integrity risk. User may believe all sessions were deleted when only some were. Also causes N redundant re-fetches.

---

### M-03: `refreshToken` returned in JSON response body, unused by frontend

**File:** `performancebench-web/src/hooks/useAuth.ts:16-19`

**Problem:** The `LoginResponse` interface includes `refreshToken: string`, but the frontend never reads, stores, or uses it:
```typescript
interface LoginResponse {
    user: User;
    refreshToken: string;
}
```

The API client uses `credentials: 'include'` (line 15 of `api.ts`), which means auth is cookie-based. The refresh token in the response body serves no purpose on the frontend and exposes the token to any JavaScript running in the browser context (including browser extensions or XSS if one were to exist). If the server sends this token in an httpOnly cookie already, the JSON body token is redundant and increases the attack surface.

**Fix:** If the server sets the refresh token as an httpOnly cookie, remove `refreshToken` from `LoginResponse` and the server response body. If the server doesn't set a cookie, prefer moving to httpOnly cookies (more secure than JS-accessible storage).

**Severity:** MEDIUM -- Security hardening. Redundant token exposure in JavaScript context increases risk surface without any functional benefit.

---

### M-04: `setState` called during render phase in live.tsx 

**File:** `performancebench-web/src/routes/live.tsx:82-85`

**Problem:** State update triggered directly in the component render body, not in an event handler or `useEffect`:
```typescript
const [listenerActive, setListenerActive] = useState(false);
if (!listenerActive && wsSessionId) {
    setListenerActive(true);
}
```

React explicitly warns against calling `setState` during render because it triggers an immediate synchronous re-render. In React 18 StrictMode (which this app uses per `main.tsx:1`), effects run twice, and this pattern can cause infinite render loops.

**Fix:** Remove the `listenerActive` state entirely (it's not used for anything except its own setter). This is dead logic that only exists to trigger its own lifecycle. The sentinel value it tracks (`wsSessionId !== null`) is already available in component scope.

**Severity:** MEDIUM -- Causes unnecessary re-renders and risks infinite loops in StrictMode. Degrades performance and reliability of the live monitoring page.

---

### M-05: Missing CSRF token for state-changing requests

**File:** `performancebench-web/src/lib/api.ts:12-19`

**Problem:** The `apiFetch` function uses `credentials: 'include'` to send cookies, but does not include a CSRF token header. All POST/PUT/DELETE requests rely solely on session cookies for authentication. While the project is a local-only profiler (per `CLAUDE.md`), if the web dashboard is ever accessible beyond localhost (e.g., on a LAN during development), it becomes vulnerable to CSRF attacks where a malicious site could trigger state-changing operations.

The server should require a CSRF token (e.g., `X-CSRF-Token` header) for all mutating requests, and the client should read it from a cookie (not httpOnly) and include it.

**Fix:** Add CSRF token handling to the API client:
```typescript
function getCsrfToken(): string {
    const match = document.cookie.match(/(?:^|;\s*)csrf_token=([^;]*)/);
    return match ? match[1] : '';
}

async function apiFetch<T>(path: string, options: RequestInit = {}): Promise<T> {
    const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        'X-CSRF-Token': getCsrfToken(),
    };
    // ...rest
}
```

Note: This requires server-side support. Coordinate with the backend team.

**Severity:** MEDIUM -- CSRF is a well-known web vulnerability. While mitigated by `SameSite` cookie attributes on modern browsers, defense-in-depth requires explicit CSRF protection for a production dashboard.

---

### M-06: `useTeams.ts` -- entire hook module is dead code with no consumers

**File:** `performancebench-web/src/hooks/useTeams.ts` (entire file, 174 lines)

**Problem:** The file exports 10 hooks (`useOrgs`, `useCreateOrg`, `useDeleteOrg`, `useOrgProjects`, `useCreateProject`, `useDeleteProject`, `useOrgMembers`, `useAddMember`, `useRemoveMember`, `useUpdateMemberRole`) and 4 interfaces. None of these are imported or used anywhere else in the codebase. This was verified by grep across the entire `src/` directory -- only the exports themselves matched, zero imports.

Dead code adds maintenance burden, increases bundle size (if not tree-shaken), and can confuse developers who assume it's functional.

**Fix:** Either:
1. Remove `useTeams.ts` until team functionality is implemented
2. Or add a `// @todo Phase 2: Team management` comment and ensure it's excluded from the bundle via tree-shaking

**Severity:** MEDIUM -- Dead code is a maintainability issue. Unused API client code could also mask missing server endpoints if someone tries to use it.

---

_Reviewed: 2026-05-07_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
