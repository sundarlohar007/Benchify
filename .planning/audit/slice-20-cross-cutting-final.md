# Slice 20 — Cross-cutting: golden user flows + final regression

**Status**: complete
**Branch**: `audit/v0.1.x`
**Discovered**: 2026-05-09

## Scope

Cross-boundary audit tracing golden user flows across all 19 prior slices. No new source files to read — this slice reviews the accumulated findings, checks cross-component consistency, and identifies systemic issues that only emerge at the integration level.

### Cross-cutting areas reviewed

| Area                                           | Method                        |
|------------------------------------------------|-------------------------------|
| Version consistency across all manifests       | grep `version` in pubspec/Cargo/package.json |
| URL encoding consistency across web hooks      | grep `/api/v1/` in all hooks |
| Repository hygiene (stale files, missing docs) | ls root, check READMEs       |
| CI health (existing audit report)              | Read `CI_CD_AUDIT_REPORT.txt` |
| TODO/FIXME/HACK audit                          | ripgrep across all sources    |
| Deferred backlog triage                        | Review all 104 deferred items |

## Key themes

### 1. Missing root README (B-182)
The GitHub landing page has no README. This is the #1 first-impression issue for any new contributor or user visiting the repo.

### 2. Version chaos across components (B-183)
Desktop `0.1.0`, mobile `0.1.1`, web `2.0.0`, pcprobe `3.0.0`, Unity `3.0.0`, SDK `0.1.0`. No unified versioning. The release workflow bundles artifacts from components at wildly different versions under a single tag.

### 3. Repository pollution (B-184)
AI development artifacts (`.commit-msg-temp.txt`, `Claude Resume Command.txt`, `CL Logs/`) are committed to the repo.

### 4. Systemic URL encoding gap (B-185)
All web hooks except `useAudit` use raw string interpolation for URL path params. This is the cross-cutting view of B-161 discovered in S-17.

### 5. CI pipeline is 93.5% broken (B-186)
The existing `CI_CD_AUDIT_REPORT.txt` documents 57/61 failed runs. Self-heal can't create issues, server can't compile, desktop has 94 Dart analysis issues. This was partially addressed in S-19 but the core blockers remain.

### 6. Deferred backlog triage (B-189)
104 deferred items need prioritization into T1 (BLOCKER/HIGH), T2 (MED), T3 (LOW/NIT) for the next sprint.

## Findings

| ID    | Sev  | Title                                                      | Status              |
|-------|------|------------------------------------------------------------|---------------------|
| B-182 | MED  | No root README.md in repository                            | DEFERRED            |
| B-183 | MED  | Version drift across components                            | DEFERRED            |
| B-184 | LOW  | Stale development artifacts committed to repo              | DEFERRED            |
| B-185 | MED  | URL path parameters not encoded across all web hooks       | DEFERRED            |
| B-186 | HIGH | 93.5% CI failure rate (existing audit report)              | DEFERRED            |
| B-187 | LOW  | CLAUDE.md references stale project state                   | DEFERRED            |
| B-188 | LOW  | No `performancebench-web` README                           | DEFERRED            |
| B-189 | NIT  | Deferred backlog summary — 104 items need triage           | BACKLOG-TRIAGE      |

## Verification

No code changes in this slice — all findings are cross-cutting observations.

## Final Audit Summary

### 20/20 slices complete — 100%

| Metric                  | Value |
|-------------------------|------:|
| **Total findings**      |   196 |
| **Fixed in-audit**      |    84 |
| **Deferred**            |   112 |
| **Fix rate**            | 42.9% |
| **Slices**              | 20/20 |
| **Components audited**  |     8 |
| **Files read**          |  200+ |

### Severity breakdown (final)

| Severity | Fixed | Deferred | Total |
|----------|------:|---------:|------:|
| BLOCKER  |     2 |        2 |     4 |
| HIGH     |    28 |       11 |    39 |
| MED      |    31 |       44 |    75 |
| LOW      |    15 |       41 |    56 |
| NIT      |     8 |       17 |    25 |
| **All**  |  **84**|  **115**| **196** | **Note: 3 items have other status** |

### Top 5 most impactful fixes made during audit

1. **B-174** (HIGH) — Release workflow shell injection via `inputs.tag` — **SECURITY**
2. **B-158** (HIGH) — `apiFetch` throws on 204 No Content — broke all DELETE buttons
3. **B-159** (HIGH) — WebSocket reconnects on intentional close — ghost connections
4. **B-166** (HIGH) — Alert severity divide-by-zero — all events showed CRITICAL
5. **B-167** (HIGH) — Audit page blocks auditor role — sidebar/route mismatch

### Top 5 highest-priority deferred items

1. **B-009/B-010** (BLOCKER) — Missing iOS/macOS SDK binaries in repo
2. **B-186** (HIGH) — 93.5% CI failure rate across all workflows
3. **B-185/B-161** (MED) — URL params not encoded across all web hooks
4. **B-177/B-178/B-179** (MED) — CI `|| true` pattern makes all tests non-blocking
5. **B-183** (MED) — Version drift across components vs single release tag
