---
phase: web-dashboard-review
fixed_at: 2026-05-07T14:10:00+05:30
review_path: .planning/REVIEW-web.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase web-dashboard: Code Review Fix Report

**Fixed at:** 2026-05-07T14:10:00+05:30
**Source review:** .planning/REVIEW-web.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4 (HIGH severity only)
- Fixed: 4
- Skipped: 0

## Fixed Issues

### H-01: Admin routes lack role-based authorization

**Files modified:** `performancebench-web/src/routes/admin/users.tsx`, `performancebench-web/src/routes/admin/audit.tsx`
**Commit:** `6eff5fc`
**Applied fix:** Added `beforeLoad` route guards to both `/admin/users` and `/admin/audit` routes. Each guard queries the TanStack Query cache for `['auth', 'me']` and redirects non-admin users to `/sessions` when cached auth data is available. When data is not yet in cache (first page load), the component-level `ProtectedRoute` still handles authentication. Imported `User` type and `redirect` from respective modules.

---

### H-02: Race condition, memory leak, and duplicate listeners in live.tsx

**Files modified:** `performancebench-web/src/routes/live.tsx`
**Commit:** `c43b816`
**Applied fix:** Replaced four interconnected bugs with a single correct `useEffect` pattern:
- **Bug A (dead useState):** Removed unused `useState(() => {})` call (lines 77-79).
- **Bug B (setState-in-render):** Removed `listenerActive` state and the `setListenerActive(true)` call during render.
- **Bug C (plain-object ref):** Replaced `const sampleListenerRef = { current: null }` with `const cleanupRef = useRef<...>(null)`.
- **Bug D (inline subscription):** Moved the `onSample` subscription into a `useEffect` that properly cleans up on unmount and when `wsSessionId` changes.
- Added `useEffect` and `useRef` to React imports.

---

### H-03: CSV injection vulnerability in downloadExport

**Files modified:** `performancebench-web/src/routes/sessions/$sessionId.tsx`
**Commit:** `07c85fd`
**Applied fix:** Added `escapeCsvValue()` helper function above `downloadExport()` with three protections:
1. **Formula injection (OWASP):** Cells starting with `=`, `+`, `-`, `@` are prefixed with a tab character to prevent formula execution in Excel/LibreOffice.
2. **RFC 4180 quoting:** Values containing commas, newlines, or double-quotes are wrapped in quotes with internal quotes escaped (`""`).
3. **Null handling:** `null`/`undefined` values become empty strings.
Replaced the naive `String(val)` mapping in the CSV row builder with `escapeCsvValue()`.

---

### H-04: WebSocket auto-reconnect infinite retry with no backoff

**Files modified:** `performancebench-web/src/hooks/useWebSocket.ts`
**Commit:** `07c85fd`
**Applied fix:** Replaced the fixed 2-second reconnect delay with exponential backoff:
- Added `retryCountRef` to track consecutive failures.
- Added `ws.onopen` handler to reset the retry counter on successful connection.
- Added `ws.onclose` handler that calculates delay as `min(1000 * 2^n, 30000)` with a max of 30 retries.
- Added `retryCountRef.current >= MAX_RETRIES` guard in `connect()` to stop reconnecting after 30 failures.
- Reset `retryCountRef` in the `useEffect` cleanup when `sessionId` changes.
- Constants: `MAX_RETRIES = 30`, `BASE_DELAY_MS = 1000`, `MAX_DELAY_MS = 30000`.

---

_Fixed: 2026-05-07T14:10:00+05:30_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
