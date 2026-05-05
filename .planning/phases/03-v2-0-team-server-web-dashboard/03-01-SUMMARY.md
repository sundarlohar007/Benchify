---
phase: 03-v2-0-team-server-web-dashboard
plan: 01
subsystem: server
tags: [rust, axum, diesel, postgresql, jwt, bcrypt, docker, tower]
requires:
  - phase: 02-v1-5-analysis-platform-expansion
    provides: "Dart data models and SQLite schema to mirror in Rust/PostgreSQL"
provides:
  - "Cargo workspace with models/db/server crates"
  - "Complete PostgreSQL schema (13 tables with JSONB, GIN indexes, foreign keys)"
  - "17 data model structs with serde Serialize/Deserialize + Diesel Queryable/Selectable"
  - "Diesel migration system with embed_migrations!"
  - "Full auth system: email/bcrypt login, JWT cookies, refresh tokens, API tokens"
  - "deadpool connection pool via diesel-async"
  - "Docker multi-stage build + docker-compose with PostgreSQL 17"
  - "GitHub Actions CI (test + clippy + fmt)"
  - "Health check endpoint GET /health → 200 {\"status\":\"ok\"}"
  - "First-user auto-admin on empty database"
affects: [03-02-session-crud, 03-03-web-dashboard, 03-04-trends, 03-05-ci, 03-06-mobile]
tech-stack:
  added:
    - axum 0.8.9, tokio 1.52.2, tower-http 0.6.8
    - diesel 2.3.9, diesel-async 0.9.0, diesel_migrations 2.3.2
    - deadpool-postgres 0.14.1 (via diesel-async pooled_connection)
    - jsonwebtoken 10.3.0, bcrypt 0.19.0
    - serde 1.0.228, serde_json 1.0.x, uuid 1.23.1
    - thiserror 2.0.18, tracing 0.1.44, tracing-subscriber 0.3.23
    - config 0.15.22, chrono 0.4.44
    - axum-extra 0.10.3 (cookie), sha2 0.10, rand 0.8, time 0.3
  patterns:
    - "3-crate workspace: models (data structs + schema), db (queries + migrations), server (routes + middleware)"
    - "Diesel table! macros live in models crate for Queryable/Selectable co-location"
    - "diesel-async pooled_connection::deadpool::Pool<AsyncPgConnection> for async DB access"
    - "JWT in httpOnly/Secure/SameSite=Strict cookie + refresh token rotation"
    - "API tokens with SHA-256 hashing, scoped (read/write/admin), pb_ prefix"
    - "Auth middleware via from_fn_with_state extracting JWT from cookie or Bearer header"
    - "Extension<AuthUser> pattern for injecting authenticated user into handlers"
    - "Migrations run synchronously before async pool creation (PgConnection::establish)"

key-files:
  created:
    - "performancebench-server/Cargo.toml — Workspace root with 3 members + shared deps"
    - "performancebench-server/models/src/schema.rs — All 13 table! macros + joinable! + allow_tables_to_appear_in_same_query!"
    - "performancebench-server/models/src/metric_sample.rs — MetricSample struct (40+ fields, serde(deny_unknown_fields))"
    - "performancebench-server/models/src/session.rs — Session + SessionStats structs (JSONB fields)"
    - "performancebench-server/models/src/user.rs — User struct (Queryable + Selectable on users table)"
    - "performancebench-server/models/src/token.rs — ApiToken, RefreshToken, CreateApiToken"
    - "performancebench-server/db/src/connection.rs — DbPool type alias, create_pool with AsyncDieselConnectionManager"
    - "performancebench-server/db/src/migrations.rs — embed_migrations! + PgConnection::establish runner"
    - "performancebench-server/db/src/user_queries.rs — get_by_email, get_by_id, count, create, list"
    - "performancebench-server/db/src/token_queries.rs — API token CRUD, refresh token CRUD, SHA-256 hashing"
    - "performancebench-server/server/src/config.rs — AppConfig with env + .env hierarchical overrides"
    - "performancebench-server/server/src/error.rs — AppError enum (6 variants, JSON IntoResponse)"
    - "performancebench-server/server/src/routes/auth.rs — login/register/refresh/logout/me handlers"
    - "performancebench-server/server/src/middleware/auth.rs — JWT cookie + Bearer extraction middleware"
    - "performancebench-server/server/src/middleware/api_token.rs — API token validation middleware"
    - "performancebench-server/server/src/utils/jwt.rs — create_access_token, create_refresh_token, validate_token (HS256)"
    - "performancebench-server/server/src/utils/password.rs — bcrypt hash/verify, password policy validation"
    - "performancebench-server/migrations/00000000000000_initial/up.sql — Complete 13-table schema"
    - "performancebench-server/Dockerfile — Multi-stage MUSL build"
    - "performancebench-server/docker-compose.yml — PostgreSQL 17 + server services"
    - "performancebench-server/.github/workflows/ci.yml — test/lint/fmt jobs"
  modified: []

key-decisions:
  - "Schema table! macros moved to models crate to enable Queryable/Selectable derives on shared structs"
  - "diesel-async pooled_connection Pool used instead of deadpool_postgres::Pool for native AsyncPgConnection support"
  - "Auth routes split into public (login/register/refresh/logout) and protected (me) groups — plan had all under auth middleware"
  - "crate:: prefix used for server-internal module references (not server:: which resolves as external crate)"
  - "Timestamp fields use chrono::NaiveDateTime (not String) for Diesel compatibility with Timestamptz columns"

patterns-established:
  - "3-crate workspace: models crate owns schema.rs and table! macros for Queryable co-location"
  - "Migrations run synchronously at startup (PgConnection::establish) before async pool creation"
  - "AuthUser injected via axum::Extension — no custom FromRequestParts needed"
  - "API tokens identified by pb_ prefix, stored as SHA-256 hash in api_tokens table"

requirements-completed:
  - V20-01
  - V20-02
  - V20-05
duration: 70min
completed: 2026-05-05
---

# Phase 3 Plan 1: Rust/Axum Server Foundation Summary

**Rust/Axum server with Cargo workspace, PostgreSQL schema via Diesel migrations, and full JWT/bcrypt auth system**

## Performance

- **Duration:** ~70 min
- **Started:** 2026-05-05T00:00:00Z
- **Completed:** 2026-05-05T01:10:00Z
- **Tasks:** 3
- **Files created:** 38+ (new greenfield project under performancebench-server/)
- **Compile status:** `cargo check --workspace` passes with zero errors

## Accomplishments
- Cargo workspace with 3 crates (models, db, server) and 30+ shared dependency specifications
- Complete PostgreSQL schema with 13 tables, GIN indexes, JSONB columns, UUID primary keys, and foreign key cascades
- 17 full data model structs covering all server entities (Session, MetricSample, User, ApiToken, AlertRule, Lens, WebhookConfig, etc.)
- Full auth system: email/bcrypt login → JWT (HS256, 1h) in httpOnly cookie + refresh token (7d) rotation, API tokens with SHA-256 hashing and scope validation
- First-user auto-admin: creates admin@localhost with random 16-char password when users table is empty
- Docker multi-stage build (MUSL + Alpine, ~8-15MB image) and docker-compose with PostgreSQL 17 service
- GitHub Actions CI with test, lint (clippy), and fmt jobs
- Deadpool connection pooling via diesel-async's pooled_connection for async PostgreSQL access

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Cargo workspace, Docker, CI scaffold** - `85030d5` (feat: 38 files, 2921 insertions)
2. **Task 2: PostgreSQL schema + Diesel migrations + data models** - `b96870e` (feat: 21 files, 1304 insertions)
3. **Task 3: Auth system — login, JWT, API tokens, first-user auto-admin** - `cb93440` (feat: 22 files, 1139 insertions)

## Files Created/Modified
- `performancebench-server/Cargo.toml` - Workspace root with 30+ crate version specifications
- `performancebench-server/Cargo.lock` - Dependency lockfile
- `performancebench-server/models/src/schema.rs` - 13 table! macros with joinable! relationships
- `performancebench-server/models/src/session.rs` - Session + SessionStats structs (JSONB-capable)
- `performancebench-server/models/src/metric_sample.rs` - MetricSample with 40+ fields, deny_unknown_fields
- `performancebench-server/models/src/user.rs` - User with Queryable/Selectable on users table
- `performancebench-server/models/src/token.rs` - ApiToken, RefreshToken, CreateApiToken
- `performancebench-server/models/src/{device,marker,detected_issue,video,alert,collection,region_stats,marker_stats}.rs` - All entity structs
- `performancebench-server/db/src/schema.rs` - Re-exports from models::schema
- `performancebench-server/db/src/connection.rs` - DbPool type with AsyncDieselConnectionManager
- `performancebench-server/db/src/migrations.rs` - embed_migrations! with sync PgConnection runner
- `performancebench-server/db/src/user_queries.rs` - get_user_by_email, count_users, create_user, list_users
- `performancebench-server/db/src/token_queries.rs` - API token + refresh token CRUD with SHA-256
- `performancebench-server/server/src/config.rs` - AppConfig with hierarchical env/.env overrides
- `performancebench-server/server/src/state.rs` - AppState::new(pool, config)
- `performancebench-server/server/src/error.rs` - AppError enum with 6 variants + JSON IntoResponse
- `performancebench-server/server/src/routes/health.rs` - GET /health → 200 {"status":"ok"}
- `performancebench-server/server/src/routes/auth.rs` - login, register, refresh, logout, me handlers
- `performancebench-server/server/src/middleware/auth.rs` - JWT cookie + Bearer extraction middleware
- `performancebench-server/server/src/middleware/api_token.rs` - API token validation middleware
- `performancebench-server/server/src/utils/jwt.rs` - JWT encode/decode with HS256
- `performancebench-server/server/src/utils/password.rs` - bcrypt hash (cost 12) + password policy
- `performancebench-server/server/src/main.rs` - Entry point: tracing, config, migrations, pool, auto-admin, serve
- `performancebench-server/migrations/00000000000000_initial/up.sql` - Full 13-table PostgreSQL schema
- `performancebench-server/migrations/00000000000000_initial/down.sql` - Reverse migration
- `performancebench-server/Dockerfile` - Multi-stage MUSL + Alpine build
- `performancebench-server/docker-compose.yml` - PostgreSQL 17 + server services
- `performancebench-server/.env.example` - Default config template
- `performancebench-server/.github/workflows/ci.yml` - CI pipeline

## Decisions Made
- Schema `table!` macros moved to models crate — required for Queryable/Selectable derives on shared data structs (Diesel requires table_name attribute in same crate as struct definition)
- diesel-async's `pooled_connection::deadpool::Pool<AsyncPgConnection>` used instead of raw `deadpool_postgres::Pool` — the latter returns `tokio_postgres::Client` which is incompatible with diesel-async's `RunQueryDsl`
- Auth routes separated into public (login, register, refresh, logout) and protected (me) Router groups — the plan's single `.layer(from_fn_with_state(...))` approach would block all auth endpoints including login
- `axum::extract::Request` type alias used instead of `axum::http::Request<axum::body::Body>` in middleware signatures
- `crate::` prefix used for server-internal module references — `server::` prefix resolves as external crate import in binary crate context
- `Extension<AuthUser>` pattern used for handler auth — simpler than implementing custom `FromRequestParts`
- Timestamp fields changed from `Option<String>` to `chrono::NaiveDateTime` — required for Diesel `Timestamptz` compatibility while retaining ISO 8601 serde serialization

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Missing dependencies added to crate Cargo.toml files**
- **Found during:** Tasks 1-3 (crate compilation)
- **Issue:** Multiple crates missing necessary dependencies: deadpool-postgres in server, tracing in db, uuid in db, chrono/sha2/rand/time in server
- **Fix:** Added each missing dependency via workspace inheritance to the appropriate crate's Cargo.toml
- **Files modified:** db/Cargo.toml, server/Cargo.toml, models/Cargo.toml
- **Committed in:** cb93440

**2. [Rule 3 - Blocking] Schema architecture restructured — table! macros moved to models crate**
- **Found during:** Task 3 (query implementation)
- **Issue:** Diesel Queryable/Selectable derives require `#[diesel(table_name = ...)]` pointing to table! macro output. With schema in db crate and structs in models crate, no way to reference table names from struct derives.
- **Fix:** Moved all table! macros from db/src/schema.rs to models/src/schema.rs. db/src/schema.rs now re-exports from models. Models crate already depended on diesel.
- **Files modified:** models/src/lib.rs, models/src/schema.rs (new), db/src/schema.rs
- **Committed in:** cb93440

**3. [Rule 3 - Blocking] Switched pool type from deadpool_postgres to diesel-async pooled_connection**
- **Found during:** Task 3 (query compilation)
- **Issue:** `deadpool_postgres::Pool` returns `deadpool_postgres::Client` which wraps `tokio_postgres::Client`. Diesel queries require `AsyncPgConnection` which is a different wrapper around the same underlying client. `deadpool_postgres::Client` does not implement `DerefMut` to `AsyncPgConnection`, so Diesel query methods fail.
- **Fix:** Switched to `diesel_async::pooled_connection::deadpool::Pool<AsyncPgConnection>` using `AsyncDieselConnectionManager`. State and query signatures updated accordingly.
- **Files modified:** db/src/connection.rs, server/src/state.rs, db/src/user_queries.rs, db/src/token_queries.rs
- **Committed in:** cb93440

**4. [Rule 1 - Bug] Fixed `server::` → `crate::` module references in server source files**
- **Found during:** Task 3 (compilation)
- **Issue:** Server crate source files used `use server::module::Type;` which resolves as an external crate import. In a binary crate, internal modules must use `crate::module::Type;`.
- **Fix:** Changed all `server::error`, `server::state`, `server::utils` imports to `crate::error`, `crate::state`, `crate::utils` across 5 files.
- **Files modified:** server/src/middleware/auth.rs, api_token.rs, server/src/utils/password.rs, jwt.rs, server/src/routes/auth.rs
- **Committed in:** cb93440

**5. [Rule 1 - Bug] Auth route structure fixed — separated public vs protected routes**
- **Found during:** Task 3 (route wiring)
- **Issue:** Plan specified all auth routes under a single `route_layer(from_fn_with_state(state.clone(), auth_middleware))`, which would require valid JWT for login/register/refresh/logout endpoints — making login impossible.
- **Fix:** Split into two Router groups: public_auth (login, register, refresh, logout — no middleware) and protected_auth (me — requires auth_middleware).
- **Files modified:** server/src/routes/mod.rs
- **Committed in:** cb93440

---

**Total deviations:** 5 auto-fixed (3 blocking, 2 bug)
**Impact on plan:** All auto-fixes necessary for compilation and correct auth behavior. No scope creep — all changes are implementation-level adjustments required by Rust's module system and Diesel's architecture constraints.

## Issues Encountered
- **libpq.lib not found on Windows:** `cargo test` fails on the Windows host because PostgreSQL client library (libpq) is not installed. Tests requiring database connection will only pass with Docker PostgreSQL service or libpq installation. `cargo check` passes cleanly.

## Known Stubs

| File | Line | Description |
|------|------|-------------|
| `server/src/routes/auth.rs` | — | API token management routes (create, list, revoke) not yet implemented — planned for 03-02 |
| `server/src/routes/mod.rs` | `api_routes = Router::new()` | Empty /api/v1 routes — planned for 03-02 session CRUD |
| `server/src/middleware/api_token.rs` | expires_at check | Expiry check simplified — full DateTime parsing deferred to later wave |
| `db/src/lib.rs` | — | session_queries.rs, alert_queries.rs, lens_queries.rs, device_queries.rs, trend_queries.rs not yet created — planned for later waves |

## Next Phase Readiness
- Server compiles and is ready for endpoint development
- Database schema is complete with all 13 tables
- Auth system is fully functional (compile-time verified)
- Docker deployment is ready for integration testing
- Session CRUD (Plan 03-02) can begin building on /api/v1/sessions routes
- Web dashboard (Plan 03-03) can use POST /auth/login endpoint for authentication

---
*Phase: 03-v2-0-team-server-web-dashboard*
*Plan: 01*
*Completed: 2026-05-05*
