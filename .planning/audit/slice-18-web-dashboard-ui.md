# Slice 18 — Web dashboard: UI

**Status**: complete
**Branch**: `audit/v0.1.x`
**Discovered**: 2026-05-09

## Scope

All UI components, route pages, and visual layer in `performancebench-web/src/`.

| Path                                              | LOC | Read |
|---------------------------------------------------|----:|:----:|
| `routes/__root.tsx`                               |   7 | full |
| `routes/index.tsx`                                |   5 | full |
| `routes/live.tsx`                                 | 222 | full |
| `routes/alerts.tsx`                               | 528 | full |
| `routes/sessions/$sessionId.tsx`                  | 419 | full |
| `routes/admin/audit.tsx`                          | 313 | full |
| `components/layout/Sidebar.tsx`                   | 174 | full |
| `components/layout/AppLayout.tsx`                 |  15 | full |
| `components/layout/Header.tsx`                    |  30 | full |
| `components/charts/LiveChart.tsx`                 | 144 | full |
| `components/charts/TrendChart.tsx`                | 150 | full |
| `components/sessions/SessionDetailTabs.tsx`       | 794 | full |
| `components/auth/ProtectedRoute.tsx`              |  26 | full |
| `components/auth/LoginForm.tsx`                   | 114 | full |

## Key themes

### 1. Alert severity calculation (alerts.tsx)

Division by zero when threshold is 0. All alert events showed as "CRITICAL" regardless. Also, negative thresholds (used with "less than" conditions) produced incorrect negative ratios. Fixed with `!== 0` guard and `Math.abs()`.

### 2. Role mismatch: sidebar vs route guard (audit.tsx)

Sidebar showed "Audit" link to auditor role, but the route's `beforeLoad` only allowed `admin`. Auditors were teased with a link that redirected them away. Fixed to allow both roles.

### 3. Missing severity in issues tab (SessionDetailTabs.tsx)

The severity grouping array omitted `'warning'`, causing warning-severity issues to disappear from the Issues tab while still being counted in the Overview tab. Data integrity issue between tabs.

### 4. Export safety (session detail)

Export callbacks use `session!` before null guards, CSV header not escaped.

### 5. Performance (LiveChart)

Ring buffer uses O(n) `shift()` per sample across 6 charts simultaneously.

## Findings

| ID    | Sev  | Title                                                      | Status              |
|-------|------|------------------------------------------------------------|---------------------|
| B-166 | HIGH | Alert event severity divides by zero threshold             | FIXED in this slice |
| B-167 | HIGH | Audit page `beforeLoad` blocks auditor role                | FIXED in this slice |
| B-168 | MED  | Issues tab drops 'warning' severity issues                 | FIXED in this slice |
| B-169 | MED  | Export callbacks use non-null assertion on nullable session | DEFERRED-TO-S20     |
| B-170 | LOW  | LiveChart ring buffer uses O(n) array shift                | DEFERRED-TO-S20     |
| B-171 | LOW  | CSV header row not escaped                                 | DEFERRED-TO-S20     |
| B-172 | LOW  | Jira modal has no Escape key handler                       | DEFERRED-TO-S20     |
| B-173 | NIT  | Chart.js registered twice in separate components           | DEFERRED-TO-S20     |

## Verification

```
$ npx tsc --noEmit
No errors — clean compilation
```
