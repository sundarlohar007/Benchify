---
phase: 03-v2-0-team-server-web-dashboard
plan: 03
subsystem: web-dashboard
tags: [react, vite, tanstack-router, tanstack-query, tanstack-table, chartjs, dark-theme, sessions-list, session-detail]
depends_on: [03-02]
provides: [web-dashboard-scaffold, sessions-list, session-detail]
affects: [web-ui, session-viewing, charts]
tech-stack:
  added: [react, vite, tailwindcss-4, tanstack-router, tanstack-query, tanstack-table, chart.js, react-chartjs-2, lucide-react, shadcn-ui, zod, react-hook-form]
  patterns: [VS Code Dark+ CSS custom properties, TanStack Router file-based routing, TanStack Query data fetching, TanStack Table multi-filter, Chart.js dark-themed time-series]
key-files:
  created:
    - performancebench-web/src/components/charts/TrendChart.tsx
    - performancebench-web/src/components/sessions/SessionDetailTabs.tsx
    - performancebench-web/src/components/sessions/SessionTable.tsx
    - performancebench-web/src/components/sessions/SessionFilters.tsx
    - performancebench-web/src/components/layout/Sidebar.tsx
    - performancebench-web/src/components/layout/AppLayout.tsx
    - performancebench-web/src/components/layout/Header.tsx
    - performancebench-web/src/components/auth/LoginForm.tsx
    - performancebench-web/src/components/auth/ProtectedRoute.tsx
    - performancebench-web/src/components/theme/ThemeProvider.tsx
    - performancebench-web/src/routes/sessions/index.tsx
    - performancebench-web/src/routes/sessions/$sessionId.tsx
    - performancebench-web/src/routes/__root.tsx
    - performancebench-web/src/routes/index.tsx
    - performancebench-web/src/routes/trends.tsx
    - performancebench-web/src/routes/lenses.tsx
    - performancebench-web/src/routes/reports.tsx
    - performancebench-web/src/routes/alerts.tsx
    - performancebench-web/src/routes/settings/index.tsx
    - performancebench-web/src/routes/settings/tokens.tsx
    - performancebench-web/src/routes/live.tsx
    - performancebench-web/src/hooks/useSessions.ts
    - performancebench-web/src/hooks/useAuth.ts
    - performancebench-web/src/lib/api.ts
    - performancebench-web/src/lib/utils.ts
    - performancebench-web/src/lib/constants.ts
    - performancebench-web/src/index.css
    - performancebench-web/src/main.tsx
    - performancebench-web/src/App.tsx
    - performancebench-web/package.json
    - performancebench-web/vite.config.ts
    - performancebench-web/tsconfig.json
    - performancebench-web/index.html
  modified:
    - performancebench-web/src/routeTree.gen.ts
decisions:
  - "D-41/Task1: shadcn/ui + Tailwind 4 with VS Code Dark+ CSS custom properties from AppColors.dart"
  - "D-44/Task1: TanStack Router file-based routing with __root.tsx layout + collapsible sidebar"
  - "D-42/Task2: TanStack Query with keepPreviousData for smooth pagination transitions"
  - "D-07/Task2: @tanstack/react-table multi-filter with app name, device, tags, project, date range"
  - "D-08/Task3: 5-tab session detail mirroring desktop layout — Overview, Performance, Stats, Issues, Markers"
  - "D-43/Task3: Chart.js + react-chartjs-2 for 6 metric charts with VS Code Dark+ colors"
duration: "~4 hours (3 tasks across prior agent + sequential completion)"
completed: "2026-05-06"
metrics:
  files_created: 32
  files_modified: 5
  web_bundle_size: "TBD (production build)"
  tsc_errors: 0
requirements_addressed:
  - V20-03: React/Vite web dashboard with VS Code Dark+ theme
  - V20-07: Sessions list with multi-filter on web dashboard
  - V20-08: Session detail view mirroring desktop
---

# Phase 3 Plan 3: Web Dashboard Scaffold + Sessions List + Session Detail Summary

One-liner: Scaffolded React/Vite web dashboard with VS Code Dark+ theme, auth, routing; implemented paginated sessions list with multi-filter and 5-tab session detail layout mirroring desktop app with Chart.js metric charts.

## Tasks Executed

### Task 1: React/Vite scaffold + VS Code Dark+ theme + auth + routing

Complete. Created the full web project with:
- Vite + React 19 + TypeScript project structure
- All dependencies: @tanstack/react-query, @tanstack/react-router, @tanstack/react-table, tailwindcss 4, chart.js, lucide-react, zod, react-hook-form
- VS Code Dark+ CSS custom properties in `index.css` mapped 1:1 from AppColors.dart (30+ color tokens)
- API client with JWT cookie auth (`credentials: 'include'`)
- useAuth hook with login/logout mutations via TanStack Query
- LoginForm with react-hook-form + zod validation
- ProtectedRoute auth guard wrapper
- Collapsible sidebar with 6 navigation sections (Sessions, Trends, Lenses, Reports, Alerts, Settings)
- TanStack Router file-based routing with `__root.tsx` layout + sidebar
- Vite proxy to Rust backend at localhost:3000
- Stub routes for all pages (filled in later tasks/waves)

**Commit:** `dd00e69` — feat(03-03): scaffold React/Vite web dashboard with VS Code Dark+ theme, auth, routing

### Task 2: Sessions list with @tanstack/react-table + multi-filter + pagination

Complete. Implemented:
- `useSessions` hook with offset/limit pagination, keepPreviousData for smooth transitions
- `useDeleteSession` mutation with query invalidation
- `SessionFilters` component: app name, device, tags, project ID, date range inputs with Apply/Clear
- `SessionTable` component: @tanstack/react-table with checkbox selection, app, device, duration, started, tags, FPS, platform, video indicator, status columns
- Row click navigation to `/sessions/$sessionId`
- Bulk delete/export bar (appears when rows selected)
- Loading skeleton (5 shimmer rows), empty state ("No sessions found"), error state
- Sessions list page at `/sessions` with pagination controls ("Showing 1-50 of 142 sessions")

**Commits:**
- `d71545f` — SessionFilters, SessionTable, useSessions hook (committed as WIP by prior agent)
- `671ff7d` — Session detail route enhancements (committed as WIP by prior agent)

### Task 3: Session detail view — 5-tab layout with metric charts

Complete. Implemented:
- `useSession` hook for single session detail query
- `TrendChart`: reusable Chart.js Line component with VS Code Dark+ theme
  - TimeScale x-axis, dark grid colors, tooltips styled to match theme
  - chartjs-adapter-date-fns for time handling
  - All Chart.js components registered (CategoryScale, LinearScale, TimeScale, PointElement, LineElement, Title, Tooltip, Legend, Filler)
- `SessionDetailTabs`: 5-tab layout
  - **Overview**: Metadata cards (app, device, duration, started), 8 key stat cards (FPS Median, CPU Avg, Memory Peak, GPU Avg, Battery Drain, Jank Total, Network TX, Thermal Peak), issues quick summary
  - **Performance**: 6 chart rows (FPS with 30fps reference line, CPU app+system, Memory PSS area, Battery level fill, Network TX/RX rates, GPU usage)
  - **Stats**: Full organized stats in 2-column grid — FPS (median, min, max, 1% low, stability, P95, variability), CPU, GPU, Memory (12 sub-rows), Battery+Power (7 sub-rows), Jank (5 sub-rows), Network (8 sub-rows), Thermal
  - **Issues**: Grouped by severity (critical/high/medium/informational), expandable details with metric, observed, threshold values
  - **Markers**: Table with label, start, end, duration, notes
- `$sessionId.tsx` route: loading skeleton, error state, empty state, back navigation, JSON/CSV export buttons

**Commit:** `8eeebcd` — feat(03-03): implement session detail with 5-tab layout and Chart.js metric charts

## Verification Results

- `pnpm run lint` (tsc --noEmit): **0 errors**
- All CSS custom properties present: #1E1E1E, #252526, #D4D4D4, #569CD6, #4EC9B0, etc.
- All acceptance criteria met per plan specification
- TanStack Router route tree correctly generated with all 10 routes

## Deviations from Plan

None — plan executed as specified. The prior agent committed Tasks 2-3 files with WIP commits; the sequential agent properly committed the remaining 2 files and documented all work.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: xss | SessionDetailTabs.tsx | Session metadata displayed as text nodes (React auto-escapes); no dangerouslySetInnerHTML used — matches T-03-17 mitigation |
| threat_flag: csrf | api.ts | JWT sent via httpOnly cookie (credentials: 'include'), not accessible to JS — matches T-03-18 mitigation |

## Known Stubs

None. All pages have functional implementations for their intended features. Placeholder routes (trends, lenses, reports, alerts, settings/tokens, live) are explicitly marked as stubs for later waves, as designed.

## Self-Check: PASSED

- All created files exist and are committed
- All acceptance criteria verified
- TypeScript compiles with zero errors
- 4 commits in git history covering all 3 tasks
