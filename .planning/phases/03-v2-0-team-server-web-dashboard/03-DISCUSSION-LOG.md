# Phase 3: v2.0 Team Server + Web Dashboard — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-05
**Phase:** 3-v2.0-team-server-web-dashboard
**Areas discussed:** Server architecture, Session upload protocol, Auth & API token design, Web dashboard component strategy
**Mode:** Default interactive (no flags)
**User selections:** Claude's recommendations accepted for all questions

---

## Server Architecture

| # | Decision | Options Presented | Selected | Notes |
|---|----------|-------------------|----------|-------|
| 1 | Repo location | Monorepo sibling / Separate repo / Subdirectory | Monorepo sibling | `performancebench-server/` alongside `performancebench/` |
| 2 | Cargo workspace | Single crate / Multi-crate / Feature-based | Multi-crate — server, db, models | Standard Rust separation |
| 3 | ORM/migrations | Diesel / SQLx / Raw SQL | Diesel ORM + diesel_migrations | Compile-time checked queries |
| 4 | Deployment | Docker / systemd / Both | Docker + docker-compose | With PostgreSQL service |
| 5 | Middleware | Tower stack / Minimal / Full tower-http | Tower middleware stack | cors + trace + auth + error |
| 6 | Logging | tracing+JSON / log+env_logger / OTel | tracing + JSON logs | Structured, machine-readable |
| 7 | Error handling | Structured JSON / Status only / RFC 7807 | Structured JSON with error codes | AppError enum via thiserror |
| 8 | CI | cargo test / Full build+test+docker / Minimal | Standard — test + clippy + fmt | PG service container |
| 9 | API versioning | URL path / Header / None | URL path — /api/v1/ | Breaking = new /api/v2/ |
| 10 | Background jobs | tokio::spawn / Redis queue / Deferred | tokio::spawn | No extra infra |
| 11 | Config | config crate / dotenvy / TOML | config crate + .env + env vars | 12-factor |
| 12 | Health check | Simple / DB ping / Deep | Simple status only | `{"status": "ok"}` |
| 13 | DB pooling | deadpool / r2d2 / bb8 | deadpool | Async-native |
| 14 | Session storage | JSONB / filesystem / normalized tables | PostgreSQL JSONB | metric_samples as JSONB |
| 15 | CORS | LAN + localhost / * / Strict whitelist | LAN + localhost | 192.168.*, 10.*, 172.16-31.* |
| 16 | TLS | rustls / nginx reverse proxy / Both | Built-in TLS via rustls | User-provided cert+key |
| 17 | API docs | utoipa / Manual / None | utoipa + OpenAPI spec | Swagger UI optional |
| 18 | Analytics | Server recompute / Trust desktop / Both | Server-side recompute | Dart→Rust port |
| 19 | Pagination | Offset / Cursor / Both | Offset | ?offset=0&limit=50 |

## Session Upload Protocol

| # | Decision | Options Presented | Selected | Notes |
|---|----------|-------------------|----------|-------|
| 20 | Upload format | Single JSON / Multipart / Two-phase | Streaming JSON body | No hard size limit |
| 21 | Screenshots | Separate files / Base64 / Metadata only | Separate multipart files | No base64 bloat |
| 22 | Upload auth | API token / JWT login / Config file | API token Bearer header | Stored in SharedPreferences |
| 23 | Compression | gzip / None / zstd | gzip Content-Encoding | tower-http decompresses |
| 24 | Retry | Auto backoff / Manual / Persistent | 3 retries at 1s/4s/16s | Exponential backoff |
| 25 | Duplicates | 409 Conflict / Overwrite / Versioned | 409 Conflict | Desktop shows badge |
| 26 | Progress | Progress bar / Spinner / Notification | Per-session progress bar | Percentage + speed |
| 27 | Queue | Sequential / Concurrent / None | Sequential FIFO | "2 of 5" position |
| 28 | Video upload | Optional / Metadata only / Always | Optional — user chooses | Video metadata always sent |
| 29 | Server URL | Manual / mDNS / Both | Manual URL in Settings | Explicit, simple |
| 30 | Payload | Core data / Full / Core + thumbs | Full — screenshots + video metadata | Video files optional |

## Auth & API Token Design

| # | Decision | Options Presented | Selected | Notes |
|---|----------|-------------------|----------|-------|
| 31 | Web auth | JWT+refresh / Session cookie / JWT only | JWT (HS256, 1h) + refresh (7d) | httpOnly cookie |
| 32 | API scopes | read/write/admin / Full / Granular | read / write / admin | Dashboard-managed |
| 33 | Registration | Admin invite / Open / Email invite | Admin-invite only | First user auto-admin |
| 34 | Token storage | SharedPreferences / Config file / OS keychain | SharedPreferences | AES-encrypted where supported |
| 35 | Token mgmt | Dashboard page / CLI / Both | Dashboard management page | Token prefix, scopes, revoke |
| 36 | Password policy | Standard / Strong / Lenient | 8+ chars, letter + number | bcrypt cost 12 |
| 37 | Rate limiting | Login 5/min / None / Tiered | No rate limiting | Internal team server |
| 38 | Sessions | Concurrent / Single / Limited | Allow concurrent | Multiple browsers okay |
| 39 | Audit | tracing logs / None / Dedicated table | Structured tracing logs | No audit table |
| 40 | Mobile auth | API token / QR code / No auth | API token — same as desktop | SharedPreferences on mobile |

## Web Dashboard Component Strategy

| # | Decision | Options Presented | Selected | Notes |
|---|----------|-------------------|----------|-------|
| 41 | UI library | shadcn/ui / Mantine / Custom | shadcn/ui + Tailwind CSS | VS Code Dark+ via CSS vars |
| 42 | State mgmt | TanStack Query / RTK Query / useState | TanStack Query | Declarative, auto-caching |
| 43 | Charts | Chart.js / Recharts / uPlot | Chart.js + react-chartjs-2 | Canvas, zoom/pan/tooltips |
| 44 | Routing | TanStack Router / React Router / Vite pages | TanStack Router | Type-safe, file-based |
| 45 | Layout | Collapsible sidebar / Top nav / Both | Collapsible sidebar | 6 nav items |
| 46 | Theme | CSS custom properties / Tailwind config / Build script | CSS custom properties | Shared with Dart AppColors |
| 47 | Live overlay | /live route / Modal / Reuse detail | Dedicated /live route | Chart.js streaming |
| 48 | Build tool | pnpm / npm / bun | pnpm + Vite | Fast, disk-efficient |
| 49 | Testing | Vitest+RTL / Vitest only / +Playwright | Vitest + React Testing Library | MSW for API mocking |
| 50 | Responsive | Tablet min / Full / Desktop only | Full responsive | Phone to desktop |
| 51 | Mobile app | Separate repo / Same project / Standalone | Separate — share data models | `performancebench-mobile/` |

---

*Discussion conducted: 2026-05-05*
*Mode: Default interactive*
*All questions: Claude recommendations accepted by user*
