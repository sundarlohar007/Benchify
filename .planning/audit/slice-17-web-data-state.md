# Slice 17 — Web dashboard: data + state

**Status**: complete
**Branch**: `audit/v0.1.x`
**Discovered**: 2026-05-09

## Scope

All data layer, state management, and utility files in `performancebench-web/src/`.

| Path                          | LOC | Read |
|-------------------------------|----:|:----:|
| `lib/api.ts`                  |  84 | full |
| `lib/constants.ts`            |   4 | full |
| `lib/utils.ts`                | 102 | full |
| `hooks/useSessions.ts`        | 230 | full |
| `hooks/useWebSocket.ts`       |  75 | full |
| `hooks/useAuth.ts`            |  77 | full |
| `hooks/useTrends.ts`          | 153 | full |
| `hooks/useAlerts.ts`          | 149 | full |
| `hooks/useAdmin.ts`           | 127 | full |
| `hooks/useAudit.ts`           | 103 | full |
| `hooks/useTeams.ts`           | 174 | full |
| `main.tsx`                    |  39 | full |
| `package.json`                |  45 | full |

## Key themes

### 1. API client: empty response crash (api.ts)
`apiFetch` called `res.json()` unconditionally, crashing on 204 No Content (all DELETE endpoints). Fixed with content-length/status check.

### 2. WebSocket stale-reconnect leak (useWebSocket.ts)
The `onclose` handler always scheduled reconnection, even when the close was intentional (cleanup/navigation). This created ghost WebSocket connections to old sessions. Fixed with `intentionalCloseRef` flag.

### 3. Auth: refresh token discarded (useAuth.ts)
The server returns a `refreshToken` in the login response, but the hook ignores it. Users are forced to re-login when the access cookie expires.

### 4. Utility functions: edge cases (utils.ts, useTrends.ts)
- `formatKB(0.5)` shows "512.0 B" — confusing for a KB-input function
- `computeTrendSummary` returns null for single data points — new users see "No data"

## Findings

| ID    | Sev  | Title                                                      | Status              |
|-------|------|------------------------------------------------------------|---------------------|
| B-158 | HIGH | `apiFetch` throws on 204 No Content (DELETE)               | FIXED in this slice |
| B-159 | HIGH | WebSocket reconnects on intentional close (leak)           | FIXED in this slice |
| B-160 | MED  | `api.download` error path assumes JSON errors              | DEFERRED-TO-S20     |
| B-161 | LOW  | URL path interpolation doesn't encode IDs                  | DEFERRED-TO-S20     |
| B-162 | MED  | `LoginResponse.refreshToken` received but never stored     | DEFERRED-TO-S20     |
| B-163 | LOW  | `formatKB` confusing sub-KB display                        | DEFERRED-TO-S20     |
| B-164 | LOW  | `computeTrendSummary` null for 1 data point                | DEFERRED-TO-S20     |
| B-165 | NIT  | `document.getElementById('root')!` non-null assertion      | DEFERRED-TO-S20     |

## Verification

```
$ npx tsc --noEmit
No errors — clean compilation
```
