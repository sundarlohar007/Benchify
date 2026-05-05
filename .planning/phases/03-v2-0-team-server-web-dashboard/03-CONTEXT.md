# Phase 3: v2.0 Team Server + Web Dashboard + CI/CD — Context

**Gathered:** 2026-05-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Standalone Rust/Axum server with PostgreSQL, React/Vite web dashboard, session upload from desktop, full REST API for CI/CD automation, team features (trends, lenses, alerts, reports), WebSocket live overlay, and optional mobile profiler app. 18 requirements (V20-01 through V20-18). 5 days. 6 waves.
</domain>

<decisions>
## Implementation Decisions

### Server Architecture (Rust/Axum)

- **D-01:** Monorepo — server lives in `performancebench-server/` alongside `performancebench/` in same repo. Shared `.planning/`, single PR workflow.
- **D-02:** Multi-crate Cargo workspace: `server` (axum API), `db` (Diesel migrations + queries), `models` (shared structs). Standard Rust separation.
- **D-03:** Diesel ORM + `diesel_migrations` for schema management. Type-safe, compile-time checked queries. Migration CLI integrated into build.
- **D-04:** Docker + docker-compose deployment. `Dockerfile` for server, `docker-compose.yml` with PostgreSQL service. CI builds image.
- **D-05:** Tower middleware stack — `tower_http::cors` + `tower_http::trace` + custom auth extractor + custom error layer. Standard Axum pattern.
- **D-06:** `tracing` crate + JSON-formatted logs to stdout. `tracing-subscriber` with `json` feature. Structured, machine-readable.
- **D-07:** Structured JSON errors with error codes. Unified `AppError` enum via `thiserror`, Axum `IntoResponse` impl. Response body: `{"code": "...", "message": "...", "details": null}`.
- **D-08:** CI: `cargo test` + `cargo clippy` + `cargo fmt --check`. PostgreSQL service container for integration tests. GitHub Actions.
- **D-09:** URL path versioning — `/api/v1/` prefix. Breaking changes get new `/api/v2/` prefix.
- **D-10:** Background processing via `tokio::spawn` in Axum handlers. No dedicated job queue. Analytics computed inline after session upload.
- **D-11:** Configuration via `config` crate — `.env` for dev, environment variables for prod (12-factor). Hierarchical overrides.
- **D-12:** Simple health check — `GET /health` returns `{"status": "ok"}` with 200. No DB ping.
- **D-13:** `deadpool` for PostgreSQL connection pooling. Async-native, works with Axum shared state via `deadpool-diesel` or `deadpool-postgres`.
- **D-14:** Session data stored as PostgreSQL JSONB column for `metric_samples`. Sessions metadata in normalized columns. Screenshots stored as separate files referenced by path.
- **D-15:** CORS: allow localhost + local network IPs (`192.168.*`, `10.*`, `172.16-31.*`). Configurable origin list.
- **D-16:** TLS via `rustls` built into Axum. User provides cert + key paths in config. HTTP→HTTPS redirect.
- **D-17:** API docs via `utoipa` crate with derive macros. OpenAPI 3.0 JSON at `/api/v1/openapi.json`.
- **D-18:** Server re-computes `session_stats` from uploaded `metric_samples`. Single source of truth, consistent across clients. Requires porting Dart analytics logic to Rust.
- **D-19:** Offset-based pagination — `?offset=0&limit=50`. Standard, simple, good for moderate result sets.

### Session Upload Protocol

- **D-20:** Single JSON POST body for session upload (`POST /api/v1/sessions`). Contains session metadata + stats + samples + markers + issues. Streaming body reader — no hard size limit.
- **D-21:** Screenshots uploaded as separate multipart files alongside JSON metadata part. No base64 encoding bloat. Screenshot count + timestamps in metadata.
- **D-22:** API token authentication via `Authorization: Bearer <token>` header for uploads. Token created in web dashboard, stored in desktop SharedPreferences.
- **D-23:** gzip `Content-Encoding` compression on uploads. `tower-http::compression` decompresses server-side. Desktop gzips before sending.
- **D-24:** Auto-retry with exponential backoff — 3 retries at 1s/4s/16s. Fail permanently after 3 attempts. Desktop shows error state.
- **D-25:** Duplicate session UUID → 409 Conflict response with existing session URL. Desktop shows "Already uploaded" badge.
- **D-26:** Per-session progress bar in session history row. Shows percentage + speed during upload. Uses streaming HTTP client with progress callback.
- **D-27:** Sequential upload queue — one session at a time, FIFO order. Progress shows queue position ("2 of 5").
- **D-28:** Video files optional — user can choose to upload video chunks. Server stores in filesystem. Video metadata always uploaded.
- **D-29:** Manual server URL in Settings → Server. User enters `https://<host>:<port>`. Explicit and simple.
- **D-30:** Upload payload includes: session metadata, session_stats, metric_samples[], markers[], detected_issues[], screenshots (as separate files), video metadata (paths, codec, duration). Video files optional.

### Auth & API Token Design

- **D-31:** Email + bcrypt password → JWT (HS256, 1h expiry) + refresh token (7d). JWT in httpOnly cookie for web dashboard. Refresh via `POST /auth/refresh`.
- **D-32:** API token scopes: `read` (view sessions/stats/trends), `write` (create/upload sessions), `admin` (manage users, create tokens). Tokens created in web dashboard.
- **D-33:** Admin-invite only registration. First user auto-admin on server start. Admin creates additional users via dashboard. No open registration.
- **D-34:** API tokens stored in desktop `SharedPreferences`. Same storage as other settings. AES-encrypted at rest on supported OS.
- **D-35:** API token management page in web dashboard. Table showing token prefix, scopes, created date, last used. Revoke button per token.
- **D-36:** Password policy: minimum 8 characters, at least 1 letter + 1 number. bcrypt cost factor 12.
- **D-37:** No rate limiting on auth endpoints. Internal team server behind firewall.
- **D-38:** Allow concurrent sessions — multiple browsers/devices can be logged in simultaneously. Each gets own JWT.
- **D-39:** Auth audit via structured JSON logs (tracing). Event type, user_id, IP, timestamp, success/failure. No dedicated audit table.
- **D-40:** Mobile profiler app uses same API token flow as desktop.

### Web Dashboard Component Strategy

- **D-41:** shadcn/ui + Tailwind CSS. Headless, accessible, easily customized to VS Code Dark+ tokens via CSS custom properties.
- **D-42:** TanStack Query (React Query) for server state. Declarative caching, automatic refetch, pagination support.
- **D-43:** Chart.js + `react-chartjs-2` for Trends Explorer charts. Canvas-based, excellent time-series support, zoom/pan/tooltips.
- **D-44:** TanStack Router for file-based, type-safe routing. Layout routes for sidebar+content pattern.
- **D-45:** Collapsible sidebar navigation — Sessions, Trends, Lenses, Reports, Alerts, Settings. Icons + labels. Matches VS Code sidebar pattern.
- **D-46:** CSS custom properties mapped from `AppColors` Dart tokens (e.g., `--color-bg-base: #1e1e1e`). `tailwind.config.js` references CSS vars. Dart and React share exact hex values.
- **D-47:** Dedicated `/live` route for WebSocket real-time overlay. Streaming charts using Chart.js update pattern. Mirrors desktop ActiveSession look.
- **D-48:** pnpm + Vite build tooling. Fast, disk-efficient, strict dependency resolution.
- **D-49:** Vitest + React Testing Library for tests. API mocking via MSW (Mock Service Worker). Standard Vite testing stack.
- **D-50:** Full responsive design — phone, tablet, desktop. All views adapt. Collapsed sidebar on mobile.
- **D-51:** Separate Flutter project `performancebench-mobile/` for mobile profiler app. Shares `core/models` and `core/database` Dart code. Separate UI layer. API token auth to server.

### Claude's Discretion

- Exact Cargo workspace crate boundaries and module structure
- Diesel schema DDL for PostgreSQL (from UNIFIED-SPEC.md — server schema mirrors desktop SQLite schema)
- Docker Compose service names and port mappings
- Tower middleware ordering and configuration
- Axum route mounting structure and handler organization
- JSON error code naming convention (e.g., `SESSION_NOT_FOUND`, `INVALID_TOKEN`)
- Tracing span names and event field conventions
- deadpool configuration (pool size, timeout)
- OpenAPI schema details beyond utoipa derive macros
- Exact multipart field naming and boundary format for screenshot upload
- gzip compression level for uploads
- Upload progress callback granularity
- JWT claims structure (sub, exp, iat, scope)
- bcrypt cost factor tuning
- SharedPreferences key naming for API token storage
- shadcn/ui component selection and theming
- Tailwind breakpoint values for responsive design
- Chart.js chart colors, tooltip styling, axis configuration (VS Code Dark+ tokens)
- TanStack Router route tree structure and file naming
- CSS custom property naming convention
- Mobile profiler app Flutter widget tree and navigation structure
- `tower_http` CompressionLayer configuration for gzip
- PostgreSQL JSONB query patterns for metric_samples
- Analytics port — Dart→Rust translation scope and exact formula matching

### Folded Todos

None — no pending todos matched Phase 3 scope.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Spec & Requirements
- `UNIFIED-SPEC.md` — Single source of truth. §18-20 (Server spec), §21 (Web dashboard), §22 (REST API endpoints), §23 (Data models for server), §32.5 (Server schema DDL)
- `implementation_plan.md` — Phase-level goals for v2.0-v3.5

### Planning Documents
- `.planning/PROJECT.md` — Project context, core value (no cloud, no paid deps), constraints (May 31 deadline), key decisions
- `.planning/REQUIREMENTS.md` — 18 v2.0 requirements (V20-01 through V20-18) for Phase 3
- `.planning/ROADMAP.md` — Phase 3 wave structure, dependency graph, risk register
- `.planning/config.json` — YOLO mode, coarse granularity, parallel execution, verifier enabled, auto_advance enabled

### Prior Phase Context
- `.planning/phases/01-v1-0-external-profiling-mvp/01-CONTEXT.md` — D-01 through D-20 from Phase 1 (VS Code Dark+, Riverpod, GoRouter, TDD, DAO pattern, schema v1)
- `.planning/phases/02-v1-5-analysis-platform-expansion/02-CONTEXT.md` — D-01 through D-13 from Phase 2 (drag-region, alerts, video, Mac proxy, logcat)

### Codebase Integration Points
- `performancebench/lib/core/analytics/analytics_service.dart` — Metrics computation to port to Rust (FPS, CPU, Memory, Battery, Network, Thermal, GPU)
- `performancebench/lib/core/database/` — DAO patterns and schema to mirror in Diesel
- `performancebench/lib/core/models/` — Data model structs to replicate in Rust `models` crate
- `performancebench/lib/shared/theme.dart` — `AppColors` tokens to convert to CSS custom properties for web dashboard
- `performancebench/lib/core/services/export_service.dart` — JSON export format reference for upload payload structure

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Desktop analytics engine** — `lib/core/analytics/analytics_service.dart` (~430 lines). Identical logic to port to Rust for server-side recomputation (D-18). FPS, CPU, Memory, Battery, Network, Thermal, GPU stats. Trapezoidal integration for mAh.
- **SQLite schema v2** — `lib/core/database/database.dart` `_migrateV2()`. All table DDL to be translated to Diesel migrations for PostgreSQL. 13+ tables with indexes and foreign keys.
- **Data models** — `lib/core/models/` — `Session`, `MetricSample`, `SessionStats`, `MarkerStats`, `RegionStats`, `DetectedIssue`, `Collection`, `Video`. All have `fromMap`/`toMap` — same structure replicated in Rust `models` crate with serde `Serialize`/`Deserialize`.
- **JSON export format** — `lib/core/services/export_service.dart` — Export format becomes the upload payload schema for `POST /api/v1/sessions`.
- **VS Code Dark+ theme** — `lib/shared/theme.dart` `AppColors` class. ~30 color tokens to convert 1:1 to CSS custom properties for web dashboard `:root` (D-46).
- **ADB subprocess pattern** — `lib/core/services/adb_service.dart` — Subprocess lifecycle pattern (start → stdout stream → SIGTERM → SIGKILL) applicable to server process management.

### Established Patterns
- TDD (RED→GREEN→REFACTOR) — Phase 1-2 standard. Applies to Rust server tests, React component tests.
- DAO pattern — one class per table, parameterized queries, `ConflictAlgorithm` for upsert. Translated to Diesel's query builder pattern.
- Stream-based metrics — `MetricCollector Stream<MetricSample>` on desktop. WebSocket streaming on server for live overlay (V20-17).
- Schema migration — Database version tracking, additive migrations (CREATE TABLE IF NOT EXISTS). Same approach with Diesel migrations.

### Integration Points
- **Desktop → Server:** Upload endpoint `POST /api/v1/sessions`. Desktop sends session JSON + screenshot files. Auth via API token Bearer header.
- **Server → Web Dashboard:** REST API endpoints consumed by TanStack Query. Sessions CRUD, trends, lenses, alerts.
- **Server → Web Dashboard (live):** WebSocket at `/ws/live/:session_id`. Metric samples streamed as JSON frames at 1Hz.
- **Server → CI/CD:** REST API for session start/stop/status/export. API token auth from CI scripts.
- **Desktop ↔ Server (config):** Server URL in Settings → Server. SharedPreferences for API token storage.

</code_context>

<specifics>
## Specific Ideas

- User expects web dashboard to feel like VS Code — collapsible sidebar, dark theme, monospace font for data, hover/selection states matching desktop app
- Upload should "just work" — user sees progress bar, retries are automatic, conflicts are clearly communicated
- Auth should be minimal friction — admin creates accounts, users never see registration. First-run auto-admin removes setup friction
- Trends Explorer is the killer feature — drag-selectable time ranges (like Phase 2 D-01), KPI overlay, session comparison
- Mobile profiler app is read-only companion — no profiling, just viewing sessions/trends/alerts on phone
- Server should be "set and forget" — docker-compose up, done. No complex configuration for v2.0

</specifics>

<deferred>
## Deferred Ideas

None from this discussion — all user suggestions stayed within Phase 3 scope.

Ideas noted from prior phases that may apply:
- iOS video recording (Phase 4 — V25-11)
- Per-connection network stats (Phase 4 — V25-09)
- tvOS support (Phase 5 — V30-05)
- SSO/RBAC/audit (Phase 6 — Enterprise)
</deferred>

---
*Phase: 3-v2.0 Team Server + Web Dashboard + CI/CD*
*Context gathered: 2026-05-05*
