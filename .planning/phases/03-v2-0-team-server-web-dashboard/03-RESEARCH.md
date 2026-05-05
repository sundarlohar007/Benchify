# Phase 3: v2.0 Team Server + Web Dashboard + CI/CD — Research

**Researched:** 2026-05-05
**Domain:** Multi-tier web application — Rust/Axum backend, React/Vite frontend, PostgreSQL, Docker deployment
**Confidence:** HIGH

## Summary

Phase 3 builds a standalone Rust/Axum team server with a React/Vite web dashboard, session upload from the desktop app, and a full REST API for CI/CD automation. This is a multi-tier application: the browser tier hosts the React dashboard consuming server APIs, the API tier runs Axum with JWT auth and business logic, and the database tier stores sessions, users, tokens, and alerts in PostgreSQL.

The server recomputes session statistics from uploaded metric samples (porting 476-line Dart analytics engine to Rust), streams live overlay data via WebSocket, and exposes OpenAPI 3.0 documentation via utoipa. The web dashboard uses shadcn/ui components themed to VS Code Dark+ design tokens shared with the desktop app via CSS custom properties. Everything deploys via docker-compose with a multi-stage Rust Dockerfile producing images under 15MB.

**Primary recommendation:** Use the Cargo workspace structure (server/db/models crates), Diesel CLI with embedded migrations, axum `from_fn_with_state` for JWT auth middleware, TanStack Router + Query for the React dashboard, and docker-compose with GitHub Actions CI matrix for Rust + React.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| V20-01 | Separate repo `performancebench-server` — Rust + Axum REST API | Section: Cargo Workspace Structure, Axum Route Mounting |
| V20-02 | PostgreSQL schema + migrations | Section: Diesel Migration Workflow, PostgreSQL Schema (JSONB pattern) |
| V20-03 | React + Vite web dashboard (VS-Code-style design) | Section: React/Vite/shadcn/ui Setup, AppColors→CSS Custom Properties |
| V20-04 | Session upload from desktop app (opt-in, manual trigger) | Section: Upload Protocol Implementation |
| V20-05 | Auth — email + bcrypt, JWT (HS256, 1h expiry), API tokens | Section: JWT Implementation, Auth Middleware Pattern |
| V20-06 | TLS via user-provided cert (local network default) | Section: TLS Configuration, rustls + axum_server |
| V20-07 | Sessions list with multi-filter on web dashboard | Section: TanStack Query Pagination, URL search params |
| V20-08 | Session detail view mirroring desktop | Section: React Component Patterns |
| V20-09 | Trends Explorer — KPI trends across sessions | Section: Chart.js Time Series, TanStack Query patterns |
| V20-10 | Lenses — saved filters/views | Section: PostgreSQL JSONB for lens configs |
| V20-11 | Detected Issues dashboard tile | Section: React Component Patterns |
| V20-12 | Analysis Reports — multi-session analytical reports | Section: Analytics Port — Dart→Rust |
| V20-13 | Notifications — Email / Slack / Webhook channels | Section: Background Processing (tokio::spawn) |
| V20-14 | Threshold alert rules + alert_events table | Section: Diesel Schema Patterns |
| V20-15 | Full REST API for CI/CD — sessions CRUD, stats, export, trends, lenses, alerts, devices | Section: Axum Route Mounting, utoipa OpenAPI |
| V20-16 | Webhook callbacks on session-end / alert-fired | Section: Background Processing (tokio::spawn) |
| V20-17 | Web live overlay — WebSocket push from desktop | Section: WebSocket Implementation |
| V20-18 | Optional mobile profiler app (Flutter, iOS + Android, read-only) | Section: Flutter Code Sharing Strategy |
</phase_requirements>

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

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
- **D-16:** TLS via `rustls` built into Axum. User provides cert + key paths in config. HTTP to HTTPS redirect.
- **D-17:** API docs via `utoipa` crate with derive macros. OpenAPI 3.0 JSON at `/api/v1/openapi.json`.
- **D-18:** Server re-computes `session_stats` from uploaded `metric_samples`. Single source of truth, consistent across clients. Requires porting Dart analytics logic to Rust.
- **D-19:** Offset-based pagination — `?offset=0&limit=50`. Standard, simple, good for moderate result sets.

### Session Upload Protocol

- **D-20:** Single JSON POST body for session upload (`POST /api/v1/sessions`). Contains session metadata + stats + samples + markers + issues. Streaming body reader — no hard size limit.
- **D-21:** Screenshots uploaded as separate multipart files alongside JSON metadata part. No base64 encoding bloat. Screenshot count + timestamps in metadata.
- **D-22:** API token authentication via `Authorization: Bearer <token>` header for uploads. Token created in web dashboard, stored in desktop SharedPreferences.
- **D-23:** gzip `Content-Encoding` compression on uploads. `tower-http::compression` decompresses server-side. Desktop gzips before sending.
- **D-24:** Auto-retry with exponential backoff — 3 retries at 1s/4s/16s. Fail permanently after 3 attempts. Desktop shows error state.
- **D-25:** Duplicate session UUID to 409 Conflict response with existing session URL. Desktop shows "Already uploaded" badge.
- **D-26:** Per-session progress bar in session history row. Shows percentage + speed during upload. Uses streaming HTTP client with progress callback.
- **D-27:** Sequential upload queue — one session at a time, FIFO order. Progress shows queue position ("2 of 5").
- **D-28:** Video files optional — user can choose to upload video chunks. Server stores in filesystem. Video metadata always uploaded.
- **D-29:** Manual server URL in Settings to Server. User enters `https://<host>:<port>`. Explicit and simple.
- **D-30:** Upload payload includes: session metadata, session_stats, metric_samples[], markers[], detected_issues[], screenshots (as separate files), video metadata (paths, codec, duration). Video files optional.

### Auth and API Token Design

- **D-31:** Email + bcrypt password to JWT (HS256, 1h expiry) + refresh token (7d). JWT in httpOnly cookie for web dashboard. Refresh via `POST /auth/refresh`.
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
- Analytics port — Dart to Rust translation scope and exact formula matching

### Deferred Ideas (OUT OF SCOPE)

- iOS video recording (Phase 4 — V25-11)
- Per-connection network stats (Phase 4 — V25-09)
- tvOS support (Phase 5 — V30-05)
- SSO/RBAC/audit (Phase 6 — Enterprise)
</user_constraints>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Session upload (POST /api/v1/sessions) | API (Axum) | — | Server receives, validates, stores; desktop is an HTTP client |
| JWT authentication + refresh | API (Axum) | Browser (cookie) | Server issues/validates tokens; browser stores httpOnly cookie |
| API token validation | API (Axum) | — | Server validates Bearer token on each request |
| Session CRUD (list, get, delete) | API (Axum) | — | Database queries, authorization logic on server |
| Analytics recomputation | API (Axum) | — | Server is single source of truth (D-18), runs inline after upload |
| Web dashboard rendering | Browser (React) | — | All UI logic client-side, data fetched via TanStack Query |
| Session detail charts | Browser (Chart.js) | — | Canvas rendering in browser from API data |
| Trends Explorer | Browser (Chart.js) | API (Axum) | API provides aggregated data; browser renders time-series |
| Lenses (saved views) | API (Axum) | Browser (React) | Config stored in PostgreSQL, UI sends/receives filter configs |
| Alerts + notifications | API (Axum) | — | Server evaluates rules, triggers webhook/email |
| WebSocket live overlay | API (Axum WS) | Browser (WebSocket client) | Server receives desktop stream, forwards to browser clients |
| Screenshot storage | API (Axum filesystem) | — | Server writes to disk, serves via file path |
| PostgreSQL schema/migrations | Database (PostgreSQL) | — | Diesel manages schema; all data in PostgreSQL |
| TLS termination | API (rustls) | — | User-provided cert, server handles TLS |
| OpenAPI documentation | API (utoipa) | — | Generated from route handler annotations |
| Mobile profiler app | Browser (Flutter) | API (Axum) | Read-only; uses same REST API + API tokens as desktop |

## Standard Stack

### Backend (Rust) — Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| axum | 0.8.9 | HTTP framework | Standard Rust web framework; Tower ecosystem, extractor-based handlers [VERIFIED: cargo registry] |
| tokio | 1.52.2 | Async runtime | Required by Axum; multi-threaded, work-stealing runtime [VERIFIED: cargo registry] |
| tower-http | 0.6.8 | HTTP middleware (CORS, trace, compression) | Official Tower HTTP utilities; CORS, Tracing, Compression layers [VERIFIED: cargo registry] |
| serde | 1.0.228 | Serialization | Compile-time derive macros; JSON for API I/O [VERIFIED: cargo registry] |
| serde_json | 1.0.x | JSON handling | Required for JSONB serialization, request/response bodies [ASSUMED] |
| diesel | 2.3.9 | ORM + query builder | Type-safe, compile-time checked PostgreSQL queries [VERIFIED: cargo registry] |
| diesel_migrations | 2.3.2 | Schema migrations | Embedded or CLI migration management [VERIFIED: cargo registry] |
| diesel-async | 0.9.0 | Async Diesel | Enables async pooled Diesel connections with deadpool [VERIFIED: cargo registry] |
| deadpool-postgres | 0.14.1 | Connection pool | Standard async connection pool; integrates with diesel-async [VERIFIED: cargo registry] |
| jsonwebtoken | 10.3.0 | JWT encode/decode | Standard Rust JWT library; HS256 support, validation, leeway [VERIFIED: cargo registry] |
| bcrypt | 0.19.0 | Password hashing | Cost factor 12; standard Rust bcrypt implementation [VERIFIED: cargo registry] |
| uuid | 1.23.1 | UUID generation | v4 UUID for sessions, tokens, users [VERIFIED: cargo registry] |
| thiserror | 2.0.18 | Error derive macro | Standard for typed error enums with IntoResponse impl [VERIFIED: cargo registry] |
| tracing | 0.1.44 | Structured logging | Instrumentation for spans/events [VERIFIED: cargo registry] |
| tracing-subscriber | 0.3.23 | Log subscriber | JSON-formatted output to stdout [VERIFIED: cargo registry] |
| config | 0.15.22 | Configuration management | .env + env var hierarchical overrides (12-factor) [VERIFIED: cargo registry] |
| utoipa | 5.5.0 | OpenAPI docs | Derive macros on handlers; generates OpenAPI 3.0 JSON [VERIFIED: cargo registry] |
| rustls | 0.23.x | TLS | User-provided cert; built into Axum via rustls [VERIFIED: cargo registry; version note: 0.23.x stable] |
| rustls-pemfile | 2.2.0 | PEM parsing | Parses user-provided cert + key files [VERIFIED: cargo registry] |
| tokio-tungstenite | 0.29.0 | WebSocket | Required by Axum ws feature for WebSocket upgrade [VERIFIED: cargo registry] |

### Frontend (React) — Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| react | 19.2.5 | UI library | Latest stable React [VERIFIED: npm registry] |
| react-dom | 19.2.5 | DOM renderer | Matches React version [VERIFIED: npm registry] |
| vite | 8.0.10 | Build tool | Fast ESM-based bundler; standard for React projects [VERIFIED: npm registry] |
| @tanstack/react-query | 5.100.9 | Server state management | Caching, refetch, pagination, mutation invalidation [VERIFIED: npm registry] |
| @tanstack/react-router | 1.169.1 | Type-safe routing | File-based routing, layout routes, search params [VERIFIED: npm registry] |
| tailwindcss | 4.2.4 | Utility CSS | Rapid styling; @theme inline for CSS custom properties [VERIFIED: npm registry] |
| @tailwindcss/vite | 4.2.4 | Tailwind Vite plugin | Integrates Tailwind 4 with Vite build pipeline [VERIFIED: npm registry] |
| shadcn (CLI) | 4.6.0 | Component library CLI | Copies source components; fully customizable [VERIFIED: npm registry] |
| chart.js | 4.5.1 | Charting library | Canvas-based, time-series, zoom/pan/tooltips [VERIFIED: npm registry] |
| react-chartjs-2 | 5.3.1 | React Chart.js wrapper | React component API for Chart.js [VERIFIED: npm registry] |

### Frontend (React) — Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| vitest | 4.1.5 | Test runner | Unit + component tests for React (replaces Jest) [VERIFIED: npm registry] |
| msw | 2.14.3 | API mocking | Intercept fetch in tests; mock REST API responses [VERIFIED: npm registry] |
| zod | 4.4.3 | Schema validation | Form validation, API response validation [VERIFIED: npm registry] |
| react-hook-form | 7.75.0 | Form library | Auth forms, settings, token creation forms [VERIFIED: npm registry] |
| @hookform/resolvers | 5.2.2 | Form validation resolvers | Integrates zod with react-hook-form [VERIFIED: npm registry] |
| @tanstack/react-table | 8.21.3 | Table component | Session list table, token management table [VERIFIED: npm registry] |
| lucide-react | — | Icons | VS Code-style icons for sidebar navigation [ASSUMED] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| deadpool-postgres | sqlx | sqlx is compile-time checked SQL; but Diesel already chosen (D-03). diesel-async + deadpool-postgres is the async pattern for Diesel. |
| diesel-async 0.9.0 | diesel (sync) with `spawn_blocking` | diesel-async provides native async pool integration; cleaner than spawn_blocking wrappers for every query. |
| jsonwebtoken 10.3.0 | biscuit | biscuit is more general-purpose (JWT, JWS, JWE); jsonwebtoken is simpler, focuses on encode/decode, and is more widely used in Axum projects. |
| shadcn CLI 4.x | Manual component copy or Radix UI directly | shadcn CLI automates copy+paste and keeps components in your repo; Radix UI is the underlying headless library. |
| Tailwind 4 | Tailwind 3 | Tailwind 4 uses CSS-first config (no tailwind.config.js); @theme inline replaces the old config format; better performance. shadcn 4.x requires Tailwind 4. |

**Installation (Rust workspace):**
```bash
# performancebench-server/ directory
cargo init --lib performancebench-server
cd performancebench-server
cargo new --lib models
cargo new --lib db
cargo new server
```

**Installation (React dashboard):**
```bash
pnpm create vite performancebench-web --template react-ts
cd performancebench-web
pnpm add @tanstack/react-query @tanstack/react-router tailwindcss @tailwindcss/vite
pnpm add chart.js react-chartjs-2
pnpm add zod react-hook-form @hookform/resolvers @tanstack/react-table lucide-react
pnpm add -D vitest msw @testing-library/react @testing-library/jest-dom
npx shadcn@latest init
```

**Version verification:** All crate versions confirmed via `cargo search` on 2026-05-05. All npm versions confirmed via `npm view` on 2026-05-05.

## Architecture Patterns

### System Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                        BROWSER (React/Vite)                         │
│                                                                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │
│  │ Sessions │  │  Trends  │  │  Alerts  │  │  Live Overlay    │   │
│  │ List     │  │ Explorer │  │ Config   │  │  (WebSocket)     │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────────┬─────────┘   │
│       │              │              │                 │              │
│  ┌────┴──────────────┴──────────────┴─────────────────┴─────────┐  │
│  │              TanStack Query (cache + fetch layer)            │  │
│  │              TanStack Router (file-based routing)            │  │
│  └────────────────────────────┬─────────────────────────────────┘  │
│                               │ HTTPS (TLS) + WebSocket            │
└───────────────────────────────┼──────────────────────────────────────┘
                                │
┌───────────────────────────────┼──────────────────────────────────────┐
│                        API SERVER (Rust/Axum)                        │
│                               │                                      │
│  ┌────────────────────────────┴──────────────────────────────────┐  │
│  │                    Tower Middleware Stack                      │  │
│  │  CORS → Trace → Compression → Auth Extractors → Error Layer   │  │
│  └────────────────────────────┬──────────────────────────────────┘  │
│                               │                                      │
│  ┌────────────┐  ┌────────────┴───────────┐  ┌─────────────────┐   │
│  │ Auth Routes│  │   Session CRUD Routes   │  │ WebSocket Route │   │
│  │ /auth/*    │  │   /api/v1/sessions/*    │  │ /ws/live/:id    │   │
│  │ JWT issue  │  │   /api/v1/trends/*      │  │                 │   │
│  │ Token mgmt │  │   /api/v1/lenses/*      │  │                 │   │
│  └─────┬──────┘  │   /api/v1/alerts/*      │  └────────┬────────┘   │
│        │         │   /api/v1/devices/*     │           │            │
│        │         │   /api/v1/webhooks/*    │           │            │
│        │         └───────────┬─────────────┘           │            │
│  ┌─────┴─────────────────────┴─────────────────────────┴─────────┐  │
│  │                      Shared State (Arc)                       │  │
│  │  deadpool (pg pool)  │  Config  │  AppState                    │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                               │                                      │
└───────────────────────────────┼──────────────────────────────────────┘
                                │
┌───────────────────────────────┼──────────────────────────────────────┐
│                    DATABASE (PostgreSQL)                             │
│                                                                      │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐  ┌──────────────────┐   │
│  │ sessions │  │  users   │  │api_tokens │  │  alert_rules     │   │
│  │ (JSONB)  │  │ (bcrypt) │  │ (scopes)  │  │  alert_events    │   │
│  └──────────┘  └──────────┘  └───────────┘  └──────────────────┘   │
│                                                                      │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐  ┌──────────────────┐   │
│  │ lenses   │  │devices   │  │ markers   │  │  detected_issues │   │
│  └──────────┘  └──────────┘  └───────────┘  └──────────────────┘   │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │            File Storage (screenshots/, videos/)               │   │
│  └──────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                      EXTERNAL CLIENTS                                 │
│                                                                      │
│  ┌──────────────────┐   ┌──────────────────┐   ┌────────────────┐   │
│  │ Desktop App      │   │ Mobile App       │   │ CI/CD Pipeline │   │
│  │ (Flutter)        │   │ (Flutter)        │   │ (REST API)     │   │
│  │ Upload sessions  │   │ Read-only viewer │   │ Start/stop/    │   │
│  │ API token auth   │   │ API token auth   │   │ export sessions│   │
│  └──────────────────┘   └──────────────────┘   └────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure

```
performancebench-server/                    # Cargo workspace root
├── Cargo.toml                             # [workspace] members = ["models", "db", "server"]
├── Cargo.lock
├── Dockerfile                             # Multi-stage build (rust → alpine)
├── docker-compose.yml                     # server + postgres services
├── .env.example
├── migrations/                            # Diesel migrations (shared)
│   ├── 00000000000000_initial/
│   │   ├── up.sql
│   │   └── down.sql
│   └── ...
├── models/                                # Crate: models
│   ├── Cargo.toml                         # serde, uuid, diesel (for sql_types)
│   └── src/
│       ├── lib.rs
│       ├── session.rs                     # Session, SessionStats structs
│       ├── metric_sample.rs               # MetricSample struct (serde)
│       ├── user.rs                        # User, ApiToken structs
│       ├── alert.rs                       # AlertRule, AlertEvent structs
│       ├── lens.rs                        # Lens (saved filter) struct
│       ├── device.rs                      # DeviceInfo struct
│       ├── marker.rs                      # Marker struct
│       ├── detected_issue.rs              # DetectedIssue struct
│       └── video.rs                       # VideoMetadata struct
├── db/                                    # Crate: db
│   ├── Cargo.toml                         # diesel, diesel-async, models
│   └── src/
│       ├── lib.rs
│       ├── schema.rs                      # diesel::table! macros (generated or manual)
│       ├── connection.rs                  # deadpool config, establish pool
│       ├── migrations.rs                  # embed_migrations! + run fn
│       ├── session_queries.rs             # Session CRUD queries
│       ├── user_queries.rs                # User CRUD, auth queries
│       ├── token_queries.rs               # API token CRUD
│       ├── alert_queries.rs               # Alert rule + event queries
│       ├── lens_queries.rs                # Lens CRUD
│       ├── device_queries.rs              # Device queries
│       └── trend_queries.rs               # Aggregation queries for Trends Explorer
└── server/                                # Crate: server (binary)
    ├── Cargo.toml                         # axum, tower-http, jsonwebtoken, bcrypt, etc.
    └── src/
        ├── main.rs                        # Entry point, tracing init, serve
        ├── config.rs                      # config crate setup
        ├── state.rs                       # AppState (pool, config, jwt_secret)
        ├── error.rs                       # AppError enum, IntoResponse impl
        ├── middleware/
        │   ├── mod.rs
        │   ├── auth.rs                    # JWT cookie + Bearer extractor
        │   └── api_token.rs              # API token validation extractor
        ├── routes/
        │   ├── mod.rs                     # Router composition, mount all routes
        │   ├── health.rs                  # GET /health
        │   ├── auth.rs                    # POST /auth/login, /auth/register, /auth/refresh
        │   ├── sessions.rs               # CRUD /api/v1/sessions/*
        │   ├── upload.rs                 # POST /api/v1/sessions (multipart upload)
        │   ├── trends.rs                 # GET /api/v1/trends/*
        │   ├── lenses.rs                 # CRUD /api/v1/lenses/*
        │   ├── alerts.rs                 # CRUD /api/v1/alerts/*
        │   ├── devices.rs                # GET /api/v1/devices/*
        │   ├── tokens.rs                 # CRUD /api/v1/tokens/*
        │   ├── webhooks.rs               # POST /api/v1/webhooks/*
        │   └── ws.rs                     # WebSocket /ws/live/:session_id
        ├── services/
        │   ├── mod.rs
        │   ├── analytics.rs             # Port of Dart analytics_service.dart to Rust
        │   └── notifications.rs          # Email/Slack/Webhook dispatch
        └── utils/
            ├── mod.rs
            └── password.rs               # bcrypt hash/verify helpers

performancebench-web/                      # React/Vite web dashboard
├── package.json
├── pnpm-lock.yaml
├── vite.config.ts
├── tsconfig.json
├── index.html
├── public/
└── src/
    ├── main.tsx                           # Entry point, providers
    ├── App.tsx                            # Router + ThemeProvider + QueryClientProvider
    ├── index.css                          # Tailwind imports + CSS custom properties
    ├── routeTree.gen.ts                   # Auto-generated by TanStack Router
    ├── routes/
    │   ├── __root.tsx                     # Root layout (sidebar + content area)
    │   ├── index.tsx                      # Redirect to /sessions
    │   ├── sessions/
    │   │   ├── index.tsx                  # Session list with filters
    │   │   └── $sessionId.tsx             # Session detail (5-tab layout)
    │   ├── trends.tsx                     # Trends Explorer
    │   ├── lenses.tsx                     # Lenses management
    │   ├── reports.tsx                    # Analysis reports
    │   ├── alerts.tsx                     # Alert rules management
    │   ├── settings/
    │   │   ├── index.tsx                  # Server settings
    │   │   └── tokens.tsx                 # API token management
    │   └── live.tsx                       # WebSocket live overlay
    ├── components/
    │   ├── ui/                            # shadcn/ui components (Button, Card, Table, etc.)
    │   ├── layout/
    │   │   ├── Sidebar.tsx                # Collapsible sidebar navigation
    │   │   ├── AppLayout.tsx              # Sidebar + content layout
    │   │   └── Header.tsx                 # Top header bar
    │   ├── sessions/
    │   │   ├── SessionTable.tsx           # @tanstack/react-table sessions list
    │   │   ├── SessionFilters.tsx         # Multi-filter bar
    │   │   └── SessionDetailTabs.tsx      # 5-tab detail view
    │   ├── charts/
    │   │   ├── TrendChart.tsx             # Chart.js time-series wrapper
    │   │   └── LiveChart.tsx              # WebSocket-fed streaming chart
    │   ├── auth/
    │   │   ├── LoginForm.tsx              # Email + password form
    │   │   └── ProtectedRoute.tsx         # Auth guard wrapper
    │   └── theme/
    │       └── ThemeProvider.tsx          # Dark-only theme provider
    ├── hooks/
    │   ├── useAuth.ts                     # Auth state hook
    │   ├── useSessions.ts                 # Session query + mutation hooks
    │   ├── useTrends.ts                   # Trends query hook
    │   ├── useAlerts.ts                   # Alerts query + mutation hooks
    │   └── useWebSocket.ts               # WebSocket connection hook
    ├── lib/
    │   ├── api.ts                         # Axios/fetch wrapper with auth
    │   ├── constants.ts                   # API base URL, app constants
    │   └── utils.ts                       # Formatters, helpers
    └── mocks/
        ├── handlers.ts                    # MSW request handlers
        └── server.ts                      # MSW server setup

performancebench-mobile/                   # Separate Flutter project (V20-18)
├── pubspec.yaml
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── routes/
│   ├── screens/
│   │   ├── sessions/                      # Session list, detail (read-only)
│   │   ├── trends/                        # Trends viewer
│   │   └── settings/                      # Server URL + API token
│   ├── services/
│   │   └── api_service.dart              # REST API client
│   └── widgets/
└── shared/                                # Symlink or git submodule to performancebench/lib/core/
    ├── models/                            # Shared data models
    └── database/                          # Shared DAO patterns (or just models)
```

### Pattern 1: Cargo Workspace Structure

**What:** Three crates in a workspace: `models` (pure data structs, no deps beyond serde/uuid), `db` (Diesel queries, migrations, connection pool), `server` (Axum binary, routes, middleware, services).

**When to use:** Multi-crate Rust projects where data structures are shared between database and API layers but should not depend on web framework types.

**Key insight:** The `models` crate should depend on `serde`, `uuid`, and `diesel` (for `sql_types` if using custom Postgres types), but NOT on `axum` or HTTP types. The `db` crate depends on `models`. The `server` crate depends on both.

**Example (Cargo.toml workspace root):**
```toml
# Source: standard Cargo workspace convention [CITED: docs.rs/cargo]
[workspace]
members = ["models", "db", "server"]
resolver = "2"

[workspace.dependencies]
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
uuid = { version = "1.23", features = ["v4", "serde"] }
diesel = { version = "2.3", features = ["postgres", "uuid", "serde_json"] }
```

### Pattern 2: Axum State + Middleware Stack

**What:** Cloneable `AppState` struct shared via `Router::with_state()`. Middleware applied in order: CORS first, then tracing, then compression, then route-specific auth extractors.

**When to use:** Any Axum application with shared database pool, config, and auth secrets.

**Tower layer ordering (critical):**
```rust
// Source: Axum docs [VERIFIED: Context7 /websites/rs_axum]
// Order matters: outer layers wrap inner layers
let app = Router::new()
    // ... routes ...
    .layer(TraceLayer::new_for_http())      // 1. Outermost: log all requests
    .layer(CompressionLayer::new().gzip(true)) // 2. Compress responses
    .layer(CorsLayer::permissive())         // 3. CORS headers
    .with_state(app_state);                  // 4. Shared state (innermost)
// CORS → Trace → Compression → Handler
```

[ASSUMED: exact layer ordering should be validated against tower-http docs for this specific combination]

### Pattern 3: JWT Auth Middleware (from_fn_with_state)

**What:** Custom middleware using `axum::middleware::from_fn_with_state` that extracts JWT from httpOnly cookie (web dashboard) or Bearer header (API), validates it, and injects `AuthUser` into request extensions.

**When to use:** Routes that require authenticated user context.

**Example:**
```rust
// Source: Axum docs [VERIFIED: Context7 /websites/rs_axum]
#[derive(Clone)]
struct AuthUser {
    user_id: Uuid,
    email: String,
    scopes: Vec<String>,
}

async fn auth_middleware(
    State(state): State<AppState>,
    cookies: CookieJar,          // from axum-extra or tower-cookies
    headers: HeaderMap,
    mut request: Request,
    next: Next,
) -> Result<Response, AppError> {
    // Try cookie first (web dashboard), then Bearer header (API)
    let token = extract_token_from_cookie(&cookies)
        .or_else(|| extract_bearer_token(&headers));

    let token = token.ok_or(AppError::Unauthorized)?;
    let claims = validate_jwt(&token, &state.jwt_secret)?;
    let user = AuthUser {
        user_id: claims.sub,
        email: claims.email,
        scopes: claims.scopes,
    };

    request.extensions_mut().insert(user);
    Ok(next.run(request).await)
}
```

### Pattern 4: Diesel Migration Workflow

**What:** Migrations live in `migrations/` at workspace root. Use `diesel_cli` for generation, `embed_migrations!()` for compile-time inclusion. Run migrations programmatically at server startup.

**When to use:** Any Diesel project with PostgreSQL.

**Example:**
```rust
// Source: Diesel docs [VERIFIED: Context7 /diesel-rs/diesel]
use diesel_migrations::{embed_migrations, EmbeddedMigrations, MigrationHarness};

pub const MIGRATIONS: EmbeddedMigrations = embed_migrations!("../migrations");

pub fn run_migrations(conn: &mut impl MigrationHarness<diesel::pg::Pg>) -> Result<(), Box<dyn Error>> {
    conn.run_pending_migrations(MIGRATIONS)?;
    Ok(())
}
```

**CLI workflow:**
```bash
diesel setup --database-url="postgres://user:pass@localhost/benchify"
diesel migration generate create_sessions
diesel migration run
diesel migration redo  # Revert + re-apply last migration (dev loop)
```

### Pattern 5: TanStack Router File-Based Routing

**What:** Routes defined as files in `src/routes/`. Root layout (`__root.tsx`) provides sidebar + content area. Layout routes group related pages. Dynamic segments via `$paramName.tsx`.

**When to use:** React apps with multiple pages and consistent layout structure.

**File structure to URL mapping:**
```
src/routes/
├── __root.tsx                 # Layout wrapper (sidebar + outlet)
├── index.tsx                  # "/" → redirect to /sessions
├── sessions/
│   ├── index.tsx              # "/sessions"
│   └── $sessionId.tsx         # "/sessions/:sessionId"
├── trends.tsx                 # "/trends"
├── lenses.tsx                 # "/lenses"
├── reports.tsx                # "/reports"
├── alerts.tsx                 # "/alerts"
├── settings/
│   ├── index.tsx              # "/settings"
│   └── tokens.tsx             # "/settings/tokens"
└── live.tsx                   # "/live"
```

[VERIFIED: Context7 /tanstack/router]

### Pattern 6: TanStack Query with Pagination

**What:** `useQuery` with `queryKey` that includes pagination parameters. Offset-based pagination with `keepPreviousData` for smooth transitions.

**When to use:** List endpoints with offset/limit pagination (D-19).

**Example:**
```tsx
// Source: TanStack Query docs [VERIFIED: Context7 /tanstack/query]
function useSessions(offset: number, limit: number = 50) {
  return useQuery({
    queryKey: ['sessions', { offset, limit }],
    queryFn: () => fetchSessions(offset, limit),
    placeholderData: keepPreviousData, // smooth pagination
  });
}
```

### Pattern 7: WebSocket Live Overlay

**What:** Axum `WebSocketUpgrade` extractor handles upgrade. Server receives metric samples from desktop (via REST), stores in ring buffer, pushes to all connected WebSocket clients at 1Hz. Browser clients render with Chart.js streaming update.

**When to use:** Real-time data streaming from desktop to browser (V20-17).

**Axum WebSocket handler:**
```rust
// Source: Axum docs [VERIFIED: Context7 /websites/rs_axum]
use axum::extract::ws::{WebSocketUpgrade, WebSocket, Message};

async fn ws_handler(ws: WebSocketUpgrade, Path(session_id): Path<Uuid>) -> impl IntoResponse {
    ws.on_upgrade(move |socket| handle_socket(socket, session_id))
}

async fn handle_socket(mut socket: WebSocket, session_id: Uuid) {
    // Subscribe to session broadcast channel
    let mut rx = BROADCAST.subscribe();
    while let Ok(msg) = rx.recv().await {
        if socket.send(Message::Text(serde_json::to_string(&msg).unwrap())).await.is_err() {
            break; // client disconnected
        }
    }
}
```

**Key design:** The server uses `tokio::sync::broadcast` to fan out metric samples to all connected WebSocket clients. The desktop app sends samples via REST `POST /api/v1/sessions/:id/live` (not WebSocket — desktop is HTTP client only). The server broadcasts to browser WebSocket clients.

### Pattern 8: Docker Multi-Stage Build

**What:** Two-stage Dockerfile: (1) `rust:latest` builds MUSL-static binary with cached dependencies, (2) `alpine:latest` runs only the binary.

**When to use:** Production deployment of Rust servers (D-04).

**Key optimization (Cargo dependency caching):**
```dockerfile
# Source: verified multi-stage pattern [CITED: shaneutt.com]
FROM rust:latest AS builder
RUN rustup target add x86_64-unknown-linux-musl
WORKDIR /app
COPY Cargo.toml Cargo.lock ./
COPY models/Cargo.toml models/
COPY db/Cargo.toml db/
COPY server/Cargo.toml server/
RUN mkdir -p models/src db/src server/src
RUN echo "fn main() {}" > server/src/main.rs
RUN echo "" > models/src/lib.rs
RUN echo "" > db/src/lib.rs
RUN cargo build --release --target x86_64-unknown-linux-musl
RUN rm -f target/x86_64-unknown-linux-musl/release/deps/server*
COPY . .
RUN cargo build --release --target x86_64-unknown-linux-musl

FROM alpine:latest
RUN addgroup -S benchify && adduser -S benchify -G benchify
COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/server /usr/local/bin/
USER benchify
EXPOSE 3000
CMD ["server"]
```

**Final image size:** ~8-15MB (MUSL-static binary + Alpine base).

### Anti-Patterns to Avoid

- **Blocking database calls in async handlers:** Never call synchronous Diesel operations directly in Axum handlers. Use `diesel-async` + `deadpool-postgres` or wrap sync Diesel in `tokio::task::spawn_blocking`. Blocking the async runtime causes all concurrent requests to stall.
- **Embedding secrets in Docker images:** JWT secret, database password, etc. must come from environment variables or config files mounted at runtime, never baked into the Docker image.
- **Using Axum state for request-scoped data:** `AppState` (via `with_state`) is shared across all requests. Use `Extension` or middleware-extracted types for request-scoped data like AuthUser.
- **Loading `metric_samples` JSONB eagerly on list queries:** Session list queries should NOT include the full JSONB `metric_samples` column. Use `SELECT` without the JSONB column, and only deserialize it on the detail endpoint.
- **Running `diesel migration run` at server startup without idempotency check:** `run_pending_migrations` is safe (skips already-run migrations). `diesel migration run` without checking pending status can cause issues.
- **Using bcrypt cost factor > 12 in async context:** bcrypt is CPU-bound; cost factor 12 takes ~250-350ms. Hash verification runs in the request path. This is acceptable per D-36 (cost factor 12), but do not increase without discussion.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Password hashing | Custom hash/salt | `bcrypt` crate (cost 12) | bcrypt is memory-hard, time-tested; custom hashing introduces vulnerabilities |
| JWT signing/verification | Custom token format | `jsonwebtoken` 10.3.0 | Handles algorithm selection, claim validation, expiry, leeway; custom tokens are fragile |
| TLS/HTTPS | Custom TLS wrapper | `rustls` + `axum_server` | TLS is cryptographically complex; rustls is audited, pure-Rust, standard for Axum |
| Connection pooling | Manual connection management | `deadpool-postgres` | Handles connection lifecycle, timeouts, retries; manual pooling leaks connections |
| Structured logging | `println!` or custom log format | `tracing` + `tracing-subscriber` (JSON) | Tracing provides spans, events, structured fields; prints are unstructured and slow |
| Error serialization | Manual JSON string building | `thiserror` + `serde_json` + Axum `IntoResponse` | Type-safe errors with automatic JSON serialization; manual strings are error-prone |
| CORS headers | Manual header manipulation | `tower-http::cors::CorsLayer` | Handles preflight, allowed origins, methods; manual CORS has edge cases |
| HTTP compression | Manual gzip in handlers | `tower-http::compression::CompressionLayer` | Automatic gzip/brotli based on Accept-Encoding; manual compression is tedious |
| Migration management | Manual SQL scripts | `diesel_migrations` + `embed_migrations!()` | Version tracking, idempotency, rollback support; manual scripts get out of sync |
| OpenAPI docs | Manual YAML/JSON | `utoipa` 5.5.0 with derive macros | Generated from code; stays in sync automatically; manual docs drift from implementation |
| File upload streaming | Read entire body to memory | `axum::extract::Multipart` + streaming | Handles large files without OOM; buffering entire upload is dangerous for large sessions |
| UUID generation | Custom ID format | `uuid` crate v4 | Standard, collision-resistant; custom IDs risk collisions |
| Password validation | Custom regex | `bcrypt` crate (hash) + manual length/char check | bcrypt handles the hash; password policy is a simple length+char check, not complex enough for a library |

**Key insight (Rust):** The Rust ecosystem has mature, audited crates for every security-sensitive operation in this phase. The risk is not in choosing the wrong crate but in incorrect integration (wrong Tower layer ordering, misconfigured JWT validation, blocking in async). The standard crates listed here have hundreds of thousands of downloads and active maintenance.

**Key insight (React):** shadcn/ui components are copied into your codebase (not a dependency). This means you own the component source and can modify it directly. Tailwind CSS handles the styling. There is no need for a separate CSS-in-JS library or component library dependency beyond what shadcn provides.

## Common Pitfalls

### Pitfall 1: Tower Layer Ordering Causing Silent Auth Bypass

**What goes wrong:** Putting CompressionLayer or TraceLayer after (inside) the auth middleware means unauthenticated requests pass through compression/tracing before auth check. In some configurations, CORS preflight requests can also reach handlers without auth.

**Why it happens:** Tower layers wrap from outer to inner. The auth layer must be the outermost functional layer (inside CORS) to intercept all requests.

**How to avoid:** Use the ordering: CORS (outermost) -> Trace -> Compression -> Auth (route_layer) -> Routes. Apply auth via `route_layer` on the authenticated route group, not globally.

**Warning signs:** Unauthenticated requests returning 200 with empty response body; CORS preflight (OPTIONS) reaching handlers; compression headers on 401 responses.

### Pitfall 2: Diesel async + deadpool Connection Exhaustion

**What goes wrong:** deadpool connections are not returned to the pool if a query panic occurs or a handler holds the connection across an await point that never resolves. Pool size defaults are small (usually 8-16). Under load, all connections get tied up and requests queue indefinitely.

**Why it happens:** Async connection pools require explicit drop of the connection object. If a handler `.await`s on a long operation while holding a connection, that connection is unavailable for other requests.

**How to avoid:** Acquire connection right before the query, drop immediately after. Never hold a connection across an `await` point. Set pool timeout (`deadpool::Runtime::Tokio1` with `wait_timeout`). Configure `max_size` based on expected concurrent users (start with 20 for team server).

**Warning signs:** Requests hanging with no response; pool timeout errors in logs; increasing response latency under load.

### Pitfall 3: JSONB Column Schema Mismatch

**What goes wrong:** `metric_samples` is stored as JSONB but the Rust struct (`MetricSample`) serialized into it may drift from the Dart struct that generated the data. Fields added to Dart `MetricSample` but not to Rust `MetricSample` get silently discarded on insert (no deserialization error for unknown fields if using `#[serde(deny_unknown_fields)]`).

**Why it happens:** Dart and Rust codebases evolve independently. The JSONB column is a contract between them, but no compile-time check enforces it.

**How to avoid:** Use `#[serde(deny_unknown_fields)]` on the Rust `MetricSample` struct to catch unknown fields immediately. Add a `version` field to the upload payload so the server can reject unknown versions. Write an integration test that round-trips a full Dart-exported session through the Rust server.

**Warning signs:** Missing data in server-computed stats vs desktop-computed stats; deserialization succeeding but fields being default values; silent metric data loss.

### Pitfall 4: JWT Secret Rotation Breaking All Active Sessions

**What goes wrong:** The JWT signing secret is generated at first server start or configured in .env. If the server restarts and regenerates the secret, all existing JWTs become invalid. Users get logged out.

**Why it happens:** HS256 uses a symmetric secret. If the secret changes, all previously-signed tokens fail verification.

**How to avoid:** Generate the secret once (first run) and persist it in the database or a config file. Never auto-generate on every startup. Document the secret rotation procedure. For now (v2.0), the secret lives in config/env — rotation invalidates all sessions, which is acceptable for a team server.

**Warning signs:** All users getting 401 after server restart; `InvalidSignature` errors in logs after deployment.

### Pitfall 5: Streaming Upload Body Timeout

**What goes wrong:** Large session uploads (with video files) take longer than the default Axum/tokio timeout. The server returns 408 or drops the connection mid-upload. Desktop retry also fails because no timeout is sufficient.

**Why it happens:** Axum's underlying hyper server has default timeouts (header read, body read, keep-alive). Large uploads exceed body read timeout.

**How to avoid:** Configure `axum::serve` with relaxed timeouts for the upload route, or use `Serve::with_graceful_shutdown` patterns. Set body read timeout to at least 5 minutes for upload endpoints. Consider streaming the upload body incrementally.

**Warning signs:** Uploads failing only for large sessions; 408 or connection reset errors; retries all failing at same point.

### Pitfall 6: Chart.js Re-render Loop with TanStack Query

**What goes wrong:** Chart.js destroys and recreates the canvas on every React re-render, causing flicker and performance issues. This happens when the component re-renders due to query data changes.

**Why it happens:** Chart.js instances must be managed carefully. Creating a new `Chart` instance on every render creates canvas elements that are never garbage collected.

**How to avoid:** Use `useRef` for the Chart.js instance. Update data via `chart.data = newData; chart.update()` instead of recreating. Use `useMemo` for chart options/config to avoid unnecessary re-renders. The `react-chartjs-2` wrapper handles some of this, but avoid passing new object references as options on every render.

**Warning signs:** Charts flickering on data update; memory growth over time; multiple canvas elements accumulating in DOM.

## Code Examples

Verified patterns from official sources:

### Axum Route Mounting with Versioned API

```rust
// Source: Axum docs [VERIFIED: Context7 /websites/rs_axum]
use axum::{Router, routing::get, extract::State};

pub fn create_router(state: AppState) -> Router {
    let public_routes = Router::new()
        .route("/health", get(health_check));

    let api_routes = Router::new()
        .route("/sessions", get(list_sessions).post(upload_session))
        .route("/sessions/:id", get(get_session).delete(delete_session))
        .route("/trends", get(get_trends))
        // ... more routes
        .route_layer(axum::middleware::from_fn_with_state(
            state.clone(), auth_middleware
        ));

    Router::new()
        .merge(public_routes)
        .nest("/api/v1", api_routes)
        .with_state(state)
}
```

### JWT Encode (Login Handler)

```rust
// Source: jsonwebtoken docs [VERIFIED: Context7 /keats/jsonwebtoken]
use jsonwebtoken::{encode, Header, EncodingKey};
use serde::{Serialize, Deserialize};

#[derive(Debug, Serialize, Deserialize)]
struct Claims {
    sub: String,        // user_id as string
    email: String,
    scope: String,      // "read write" or "admin"
    exp: usize,         // now + 3600 (1 hour)
    iat: usize,
}

fn create_access_token(user_id: Uuid, email: &str, secret: &[u8]) -> Result<String> {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)?.as_secs() as usize;
    let claims = Claims {
        sub: user_id.to_string(),
        email: email.to_string(),
        scope: "read write".to_string(),
        exp: now + 3600,    // 1 hour
        iat: now,
    };
    encode(&Header::default(), &claims, &EncodingKey::from_secret(secret))
        .map_err(|e| e.into())
}
```

### JWT Decode (Validation)

```rust
// Source: jsonwebtoken docs [VERIFIED: Context7 /keats/jsonwebtoken]
use jsonwebtoken::{decode, DecodingKey, Validation, Algorithm};

fn validate_token(token: &str, secret: &[u8]) -> Result<Claims, AppError> {
    let mut validation = Validation::new(Algorithm::HS256);
    validation.leeway = 60; // 60-second clock skew tolerance
    validation.validate_exp = true;

    let token_data = decode::<Claims>(
        token,
        &DecodingKey::from_secret(secret),
        &validation,
    ).map_err(|e| {
        match e.kind() {
            jsonwebtoken::errors::ErrorKind::ExpiredSignature => AppError::TokenExpired,
            jsonwebtoken::errors::ErrorKind::InvalidToken => AppError::InvalidToken,
            _ => AppError::InvalidToken,
        }
    })?;

    Ok(token_data.claims)
}
```

### shadcn/ui + CSS Custom Properties for VS Code Dark+

```css
/* Source: shadcn/ui theming docs [VERIFIED: Context7 /shadcn-ui/ui] */
/* src/index.css — matches AppColors.dart dark theme exactly */

@import "tailwindcss";

@theme inline {
  --color-bg-base: var(--color-bg-base-raw);
  --color-bg-sidebar: var(--color-bg-sidebar-raw);
  --color-bg-elevated: var(--color-bg-elevated-raw);
  --color-text-primary: var(--color-text-primary-raw);
  --color-text-secondary: var(--color-text-secondary-raw);
  --color-accent-blue: var(--color-accent-blue-raw);
  --color-accent-recording: var(--color-accent-recording-raw);
  --color-accent-success: var(--color-accent-success-raw);
  --color-accent-warning: var(--color-accent-warning-raw);
  --color-accent-danger: var(--color-accent-danger-raw);
  --color-border-subtle: var(--color-border-subtle-raw);
  --color-border-focus: var(--color-border-focus-raw);
}

:root {
  /* VS Code Dark+ tokens (same hex values as AppColors.dart dark) */
  --color-bg-base-raw: #1E1E1E;
  --color-bg-sidebar-raw: #252526;
  --color-bg-elevated-raw: #2D2D30;
  --color-text-primary-raw: #D4D4D4;
  --color-text-secondary-raw: #858585;
  --color-accent-blue-raw: #007ACC;
  --color-accent-recording-raw: #F44747;
  --color-accent-success-raw: #4EC9B0;
  --color-accent-warning-raw: #CE9178;
  --color-accent-danger-raw: #F44747;
  --color-border-subtle-raw: #3C3C3C;
  --color-border-focus-raw: #007ACC;
  /* Chart colors (from ChartColors.dart) */
  --color-chart-fps: #569CD6;
  --color-chart-cpu: #4EC9B0;
  --color-chart-memory: #CE9178;
  --color-chart-battery: #DCDCAA;
  --color-chart-network: #4FC1FF;
  --color-chart-gpu: #C586C0;
}
```

### TanStack Router Root Layout with Sidebar

```tsx
// Source: TanStack Router docs [VERIFIED: Context7 /tanstack/router]
// src/routes/__root.tsx
import { Outlet, createRootRoute } from '@tanstack/react-router'
import { Sidebar } from '@/components/layout/Sidebar'

export const Route = createRootRoute({
  component: () => (
    <div className="flex h-screen bg-bg-base text-text-primary">
      <Sidebar />
      <main className="flex-1 overflow-auto">
        <Outlet />
      </main>
    </div>
  ),
})
```

### Chart.js Time-Series with Dark Theme

```tsx
// Source: Chart.js docs [VERIFIED: Context7 /chartjs/chart.js]
// Components: Trends Explorer chart with VS Code Dark+ colors
import { Line } from 'react-chartjs-2'
import {
  Chart as ChartJS,
  TimeScale, LinearScale, PointElement, LineElement,
  Title, Tooltip, Legend, Filler
} from 'chart.js'
import 'chartjs-adapter-date-fns'

ChartJS.register(TimeScale, LinearScale, PointElement, LineElement, Title, Tooltip, Legend, Filler)

const options = {
  responsive: true,
  maintainAspectRatio: false,
  scales: {
    x: {
      type: 'time' as const,
      time: { tooltipFormat: 'HH:mm:ss' },
      ticks: { color: '#858585' },
      grid: { color: 'rgba(60, 60, 60, 0.3)' },
    },
    y: {
      ticks: { color: '#858585' },
      grid: { color: 'rgba(60, 60, 60, 0.3)' },
    },
  },
  plugins: {
    legend: { labels: { color: '#D4D4D4' } },
  },
}
```

### Diesel Schema: Sessions Table with JSONB

```sql
-- Source: Diesel migration pattern [VERIFIED: Context7 /diesel-rs/diesel]
-- migrations/XXXXXX_create_sessions/up.sql
CREATE TABLE sessions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id UUID REFERENCES devices(id),
    app_name VARCHAR(255) NOT NULL,
    app_package VARCHAR(255),
    app_version VARCHAR(100),
    device_model VARCHAR(255),
    device_os_version VARCHAR(50),
    chipset VARCHAR(100),
    tags TEXT[] DEFAULT '{}',
    project_id VARCHAR(255),
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    duration_seconds INTEGER,
    session_stats JSONB NOT NULL DEFAULT '{}',
    metric_samples JSONB NOT NULL DEFAULT '[]',
    markers JSONB NOT NULL DEFAULT '[]',
    detected_issues JSONB NOT NULL DEFAULT '[]',
    screenshots TEXT[] DEFAULT '{}',
    video_metadata JSONB,
    is_uploaded BOOLEAN DEFAULT TRUE,
    uploaded_by UUID REFERENCES users(id),
    uploaded_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sessions_user_id ON sessions(user_id);
CREATE INDEX idx_sessions_device_id ON sessions(device_id);
CREATE INDEX idx_sessions_started_at ON sessions(started_at DESC);
CREATE INDEX idx_sessions_app_name ON sessions(app_name);
CREATE INDEX idx_sessions_project_id ON sessions(project_id);
CREATE INDEX idx_sessions_tags ON sessions USING GIN(tags);
```

[ASSUMED: exact column names and types should be verified against UNIFIED-SPEC.md Appendix C server schema DDL]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Diesel 1.x (synchronous only) | Diesel 2.3 + diesel-async 0.9 | Diesel 2.0 (2022) | Async query execution without spawn_blocking; native deadpool integration |
| jsonwebtoken 8.x | jsonwebtoken 10.3.0 | 2024-2025 | Updated crypto backends (aws_lc_rs), JWS support, improved error types |
| shadcn/ui via manual copy | shadcn CLI 4.x | 2025 | Automated init, add, update; Tailwind 4 native; CSS-first theming |
| TanStack Router < 1.0 | TanStack Router 1.169.1 | 2024-2025 | Stable API, file-based routing with type safety, search param APIs |
| Tailwind CSS 3 (JS config) | Tailwind CSS 4.2.4 | 2025 | CSS-first config (`@theme inline`), Vite-native, no tailwind.config.js needed |
| Axum 0.7 | Axum 0.8.9 | 2025 | Refined extractor API, improved WebSocket, middleware ergonomics |
| Tower middleware manual impl | tower-http 0.6.x | Ongoing | Pre-built CORS, Compression, Trace, Auth layers; less boilerplate |
| React 18 | React 19.2.5 | 2024-2025 | Server Components stable (not used here — client-only dashboard), improved hooks |

**Deprecated/outdated:**
- Diesel 1.x (sync-only): Use Diesel 2.3+ with diesel-async.
- jsonwebtoken 8.x (ring crypto backend): ring is unmaintained; prefer aws_lc_rs backend in 9.x+.
- Tailwind CSS 3 `tailwind.config.js`: Tailwind 4 uses CSS-first configuration. shadcn CLI 4.x expects Tailwind 4.
- React 18 `createRoot` API: React 19 uses the same API but adds new hooks; no migration needed but use React 19 for latest.
- Manual CORS header handling: Use `tower-http::cors::CorsLayer`.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | diesel-async 0.9.0 is compatible with Diesel 2.3.9 and deadpool-postgres 0.14.1 without version conflicts | Standard Stack | Build failure due to transitive dependency conflicts between diesel-async and deadpool |
| A2 | shadcn CLI 4.x can use CSS custom properties with `@theme inline` exactly as shown for VS Code Dark+ tokens | Architecture Patterns | Theme not applying correctly; need fallback to Tailwind 3 config approach |
| A3 | The Cargo workspace dependency caching trick (dummy main.rs before full copy) works with the 3-crate structure as described | Docker Multi-Stage | Cargo recompiles all dependencies on every build, making CI painfully slow |
| A4 | `rustls` 0.23.x (stable) is compatible with Axum 0.8.9 and axum-server; the 0.24.0-dev version found in cargo search should not be used | Standard Stack | TLS setup fails; need to use native-tls or a different TLS backend |
| A5 | TanStack Router 1.169.1 file-based routing generation works with Vite 8.0.10 via `@tanstack/router-plugin` | Architecture Patterns | Route generation fails; need to manually write route tree or use virtual routes |
| A6 | The PostgreSQL JSONB `metric_samples` format matches the desktop Dart JSON export format exactly; no transformation needed on either side | Architecture Patterns | Data mismatch on upload; server fails to parse samples or silently drops fields |
| A7 | lucide-react is the icon library used by shadcn/ui 4.x and provides the VS Code-style icons needed for sidebar navigation | Standard Stack | Icons look wrong or are missing; need to switch to a different icon library |
| A8 | `tower-http` CompressionLayer `gzip(true)` decompresses incoming gzip bodies, not just compresses outgoing responses | Upload Protocol | Upload decompression doesn't work; desktop must send uncompressed or server needs manual decompression layer |

## Open Questions

1. **Diesel-async + deadpool-diesel vs deadpool-postgres integration**
   - What we know: D-13 says "deadpool for PostgreSQL connection pooling. Async-native, works with Axum shared state via deadpool-diesel or deadpool-postgres." diesel-async 0.9.0 provides `AsyncPgConnection` and `DeadpoolPool`.
   - What's unclear: Whether to use `deadpool-diesel` (wrapper) or `deadpool-postgres` directly with `diesel-async`. The `deadpool-diesel` crate provides `deadpool::managed::Pool<diesel_async::AsyncPgConnection>` directly.
   - Recommendation: Use `diesel-async` 0.9.0's built-in deadpool support. Check `deadpool-diesel` crate compatibility at implementation time. Fall back to manual pool wrapper if needed.

2. **Axum TLS: axum-server vs manual rustls setup**
   - What we know: D-16 says "TLS via rustls built into Axum." Axum 0.8 uses `axum::serve` with `tokio::net::TcpListener`. For TLS, you need `axum_server` crate or manual `rustls` + `tokio-rustls`.
   - What's unclear: Whether `axum_server` 0.7+ supports Axum 0.8's `Router` type directly or needs adaptation.
   - Recommendation: Use `axum_server` crate with `rustls` feature. If incompatible with Axum 0.8, use manual `tokio-rustls` + `TcpListener` pattern. This is well-documented in the axum-server repo.

3. **Flutter monorepo code sharing approach for mobile app**
   - What we know: D-51 says "Shares core/models and core/database Dart code. Separate UI layer."
   - What's unclear: Whether to use a Dart package path dependency, a git submodule, or a Melos monorepo approach. The mobile project needs the `core/models/` and `core/database/` directories from the desktop app.
   - Recommendation: Use a Dart path dependency in `performancebench-mobile/pubspec.yaml` pointing to `../performancebench/lib/core/models` and `../performancebench/lib/core/database`. Alternative: create a `performancebench_core` Dart package in the workspace. Melos adds complexity for a single shared package.

4. **Chart.js zoom/pan plugin for Trends Explorer**
   - What we know: D-43 says "excellent time-series support, zoom/pan/tooltips." Chart.js has a separate `chartjs-plugin-zoom` plugin.
   - What's unclear: Whether the plugin is compatible with react-chartjs-2 5.3.1 and Chart.js 4.5.1, and whether it supports the drag-select time range feature that matches Phase 2 D-01.
   - Recommendation: Verify `chartjs-plugin-zoom` 2.x compatibility at implementation time. If not compatible, implement manual zoom via Chart.js scale min/max controls. The drag-select pattern from the desktop app may need custom implementation.

5. **Notification dispatch library for Email/Slack/Webhook**
   - What we know: D-10 says "Background processing via tokio::spawn." D-13 requirement covers Email/Slack/Webhook channels.
   - What's unclear: What Rust crate to use for email (lettre?), Slack webhook (simple reqwest POST), or generic webhook dispatch.
   - Recommendation: Use `reqwest` for Slack/webhook HTTP calls (already likely a dependency). Use `lettre` crate for SMTP email. All dispatched via `tokio::spawn` — fire and forget, log failures.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Rust (rustc + cargo) | Server build | Yes | 1.93.1 | — |
| Node.js | Web dashboard build | Yes | 24.14.0 | — |
| pnpm | Web package manager (D-48) | Yes | 10.33.0 | npm 11.11.0 |
| Docker | Containerization (D-04) | Yes | 29.2.1 | — |
| Docker Compose | Multi-service orchestration | Yes | v5.0.2 | — |
| PostgreSQL | Database (D-02) | No (not running) | — | Docker Compose provides PostgreSQL service |
| pg_isready | DB health check | No (not installed) | — | Use docker exec pg_isready or skip |
| Flutter | Mobile profiler app (V20-18) | Unknown | Not checked | Not needed for server/dashboard core; only for mobile app wave |
| diesel_cli | Migration management | No (not installed) | — | Install via `cargo install diesel_cli --features postgres` |

**Missing dependencies with no fallback:**
- `diesel_cli` — must be installed before Wave 1 schema work. Install command: `cargo install diesel_cli --no-default-features --features postgres`

**Missing dependencies with fallback:**
- PostgreSQL (local) — Docker Compose provides it. No local install needed.
- Flutter — only needed for Wave 6 mobile app. Can be installed when needed.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Yes | bcrypt 0.19.0 (cost 12), JWT HS256 via jsonwebtoken 10.3.0 |
| V3 Session Management | Yes | httpOnly JWT cookie (1h) + refresh token (7d); API token Bearer auth |
| V4 Access Control | Yes | Token scope validation (read/write/admin); route-level auth middleware |
| V5 Input Validation | Yes | serde deserialization + validation; zod on frontend for forms |
| V6 Cryptography | Yes | bcrypt for passwords; HS256 for JWT; TLS via rustls; never hand-roll |
| V7 Error Handling | Yes | Structured JSON errors via AppError enum; no stack traces in production |
| V8 Data Protection | Yes | AES-encrypted API tokens at rest on desktop (D-34); TLS in transit |
| V9 Communication | Yes | TLS (rustls) for all HTTP; WebSocket over wss:// |
| V11 Business Logic | Yes | Server recomputes stats (D-18); single source of truth |

### Known Threat Patterns for Rust/Axum + React

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| JWT none algorithm attack | Spoofing | `Validation::new(Algorithm::HS256)` — jsonwebtoken rejects 'none' by default |
| SQL injection via raw queries | Tampering | Diesel query builder is parameterized by default; never use `sql_query` with string interpolation |
| XSS via session metadata display | Information Disclosure | React auto-escapes JSX; sanitize any dangerouslySetInnerHTML usage |
| CSRF on auth endpoints | Spoofing | SameSite=Strict cookie; JWT in httpOnly cookie (not accessible to JS); Bearer token for API is CSRF-immune |
| Path traversal in screenshot serving | Information Disclosure | Validate file paths; serve from configured directory only; use UUID filenames |
| Timing attack on bcrypt comparison | Information Disclosure | bcrypt crate uses constant-time comparison internally |
| WebSocket cross-origin | Spoofing | Validate Origin header on WebSocket upgrade; CORS pre-screening |
| Brute force on login | Denial of Service | Per D-37 no rate limiting; internal team server behind firewall; document this as accepted risk |
| Token replay attack | Spoofing | JWT short expiry (1h) limits window; HTTPS prevents interception |

## Sources

### Primary (HIGH confidence)

- **Context7 /websites/rs_axum** — Axum project structure, middleware, state management, WebSocket, routing patterns
- **Context7 /diesel-rs/diesel** — Diesel migrations, PostgreSQL schema, JSONB types, diesel_cli commands
- **Context7 /keats/jsonwebtoken** — JWT encode/decode, Validation, claims, error handling
- **Context7 /shadcn-ui/ui** — Installation, theming, CSS custom properties, Tailwind 4 integration
- **Context7 /tanstack/router** — File-based routing, route tree structure, layout routes
- **Context7 /tanstack/query** — useQuery, useMutation, pagination, query invalidation
- **Context7 /chartjs/chart.js** — Time series charts, configuration, streaming updates
- **Context7 /websites/rs_tower** — Tower middleware, Layer trait, instrumentation
- **cargo registry (cargo search)** — All Rust crate versions verified on 2026-05-05
- **npm registry (npm view)** — All npm package versions verified on 2026-05-05

### Secondary (MEDIUM confidence)

- **docs.rs/axum** (via WebFetch) — Module structure, extractors, feature flags, dependencies
- **github.com/keats/jsonwebtoken README** (via WebFetch) — Complete API, algorithms, JWK support
- **shaneutt.com/blog/rust-fast-small-docker-image-builds** (via WebFetch) — Docker multi-stage Rust build pattern, MUSL compilation, 8MB final image
- **Dart source files** (local codebase read) — `AppColors` tokens (theme.dart), analytics_service.dart porting scope (476 lines), parser/model structure (8 parsers, 9 models)

### Tertiary (LOW confidence)

- None — all claims either verified via Context7/cargo/npm or explicitly tagged as `[ASSUMED]`

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all library versions verified against cargo registry and npm registry on 2026-05-05
- Architecture: HIGH — patterns drawn from Context7 documentation and verified against official docs
- Pitfalls: MEDIUM — based on training knowledge of common Rust/React pitfalls combined with documentation; specific Axum 0.8 edge cases may differ
- Docker: MEDIUM — multi-stage pattern verified; exact Axum 0.8 + rustls + MUSL compatibility not tested

**Research date:** 2026-05-05
**Valid until:** 2026-06-04 (30 days; stable stack, minor version bumps expected)

**Note on axum 0.8 vs 0.7:** Axum 0.8 introduced several API changes from 0.7 (serve API, extractor refinements). All code examples in this research target Axum 0.8.9. If the version regressed for compatibility reasons, `axum::serve` became the standard serve pattern in 0.8.

**Note on Tailwind 4:** Tailwind 4 uses CSS-first configuration. There is no `tailwind.config.js`. The `@theme inline` directive in CSS replaces the old `theme.extend` config. shadcn CLI 4.x requires Tailwind 4. The theming documentation in this research uses the Tailwind 4 API.

**Note on shadcn CLI versions:** `shadcn` 4.6.0 is the latest CLI. There is also `shadcn-ui` 0.9.5 which is an older package. Use `shadcn` (not `shadcn-ui`) for new projects.
