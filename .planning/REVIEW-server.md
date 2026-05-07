---
phase: server-review
reviewed: 2026-05-07T12:00:00Z
depth: deep
files_reviewed: 17
files_reviewed_list:
  - performancebench-server/server/src/routes/auth.rs
  - performancebench-server/server/src/routes/sessions.rs
  - performancebench-server/server/src/routes/upload.rs
  - performancebench-server/server/src/routes/ws.rs
  - performancebench-server/server/src/routes/tokens.rs
  - performancebench-server/server/src/routes/alerts.rs
  - performancebench-server/server/src/routes/devices.rs
  - performancebench-server/server/src/routes/lenses.rs
  - performancebench-server/server/src/routes/trends.rs
  - performancebench-server/server/src/routes/webhooks.rs
  - performancebench-server/server/src/routes/health.rs
  - performancebench-server/server/src/routes/mod.rs
  - performancebench-server/server/src/routes/sso.rs
  - performancebench-server/server/src/middleware/auth.rs
  - performancebench-server/server/src/middleware/api_token.rs
  - performancebench-server/server/src/middleware/rbac.rs
  - performancebench-server/server/src/middleware/audit.rs
  - performancebench-server/server/src/services/analytics.rs
  - performancebench-server/server/src/utils/jwt.rs
  - performancebench-server/server/src/utils/password.rs
  - performancebench-server/server/src/state.rs
  - performancebench-server/server/src/error.rs
  - performancebench-server/server/src/config.rs
  - performancebench-server/server/src/main.rs
  - performancebench-server/server/src/lib.rs
  - performancebench-server/db/src/session_queries.rs
  - performancebench-server/db/src/user_queries.rs
  - performancebench-server/db/src/token_queries.rs
  - performancebench-server/db/src/trend_queries.rs
  - performancebench-server/db/src/audit_queries.rs
  - performancebench-server/db/src/connection.rs
findings:
  critical: 4
  warning: 9
  info: 0
  total: 13
status: issues_found
---

# Phase Server: Code Review Report

**Reviewed:** 2026-05-07
**Depth:** deep (cross-file call tracing, import graph, middleware chain analysis)
**Files Reviewed:** 17 source files across server and db crates
**Status:** issues_found — 4 HIGH, 9 MEDIUM

## Summary

Deep review of the Rust/Axum server covering auth flows, JWT validation, session upload, WebSocket, database queries, middleware, and configuration. The codebase is reasonably well-structured but has several high-severity security issues: an unauthenticated WebSocket endpoint, path traversal in file upload, a deactivated-user authentication bypass, and raw SQL string interpolation in database queries. Multiple medium-severity issues involve missing expiry checks, panic-prone `unwrap()` calls in request handlers, blocking mutex in async context, and unrecoverable state on restart.

---

## HIGH Severity Issues

### CR-01: WebSocket endpoint has NO authentication — unauthenticated access to real-time session data

**File:** `performancebench-server/server/src/routes/mod.rs:53-55`, `performancebench-server/server/src/routes/ws.rs:15-21`

**Problem:** The WebSocket upgrade handler at `GET /ws/live/{session_id}` has zero authentication. The route is configured without any auth middleware:

```rust
// routes/mod.rs:53-55
let ws_routes = Router::new()
    .route("/live/{session_id}", get(ws::ws_handler));
```

The comment claims "auth checked implicitly by session UUID (unguessable)". This is incorrect because:
- UUIDv4 has only 122 bits of entropy — brute-forceable and enumerable
- An unauthenticated attacker discovering a valid session ID can receive real-time metric data from another user's session
- The `push_live_batch` companion endpoint has API token auth, but `ws_handler` does not — this asymmetry means data flows OUT without any authorization check

Any network-accessible attacker who guesses or discovers a `session_id` can open a WebSocket and receive real-time profiling data.

**Fix:** Add `auth_middleware` and session ownership verification to the `ws_handler`. The route should:
```rust
let ws_routes = Router::new()
    .route("/live/{session_id}", get(ws::ws_handler))
    .route_layer(from_fn_with_state(state.clone(), auth_mw::auth_middleware));
```
And in `ws_handler`, verify the authenticated user owns the session:
```rust
pub async fn ws_handler(
    ws: WebSocketUpgrade,
    State(state): State<AppState>,
    Path(session_id): Path<Uuid>,
    Extension(auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    // Verify session ownership
    session_queries::get_session_by_id_and_user(&state.pool, session_id, auth_user.user_id)
        .await
        .map_err(|_| AppError::Unauthorized)?
        .ok_or(AppError::NotFound("Session".to_string()))?;
    Ok(ws.on_upgrade(move |socket| handle_socket(socket, state, session_id)))
}
```

---

### CR-02: Path traversal in screenshot file saving via attacker-controlled filename

**File:** `performancebench-server/server/src/routes/upload.rs:122-127`, `255-259`

**Problem:** Screenshot filenames come from the multipart form submission (`field.file_name()`), which is attacker-controlled. The filename is used directly in path construction without any sanitization:

```rust
// upload.rs:123-127
let filename = field.file_name()
    .unwrap_or("unknown.png")
    .to_string();
```

```rust
// upload.rs:255-256
let path = format!("{}/{}", screenshot_dir, filename);
if let Err(e) = std::fs::write(&path, data) {
```

An attacker can set `filename` to `../../../../etc/cron.d/evil` (or `..\..\..\Windows\System32\evil.dll` on Windows) to write files to arbitrary locations on the server filesystem. Because the server runs with the privileges of the server process, this could overwrite critical system files, deploy executable payloads, or read/write sensitive data.

**Fix:** Sanitize the filename by stripping path components:
```rust
use std::path::Path;

let filename = field.file_name()
    .unwrap_or("unknown.png")
    .to_string();

// Strip any directory components — use only the basename
let safe_name = Path::new(&filename)
    .file_name()
    .map(|n| n.to_string_lossy().to_string())
    .unwrap_or_else(|| format!("{}.png", Uuid::new_v4()));

// Additional: reject filenames with suspicious patterns
if safe_name.contains("..") || safe_name.starts_with('/') || safe_name.starts_with('\\') {
    return Err(AppError::Validation("Invalid filename".to_string()));
}
```

---

### CR-03: Deactivated users can still authenticate — missing `is_active` check on login

**File:** `performancebench-server/server/src/routes/auth.rs:104-107`

**Problem:** The `login` handler fetches the user and validates their password, but never checks `user.is_active`:

```rust
let user = user_queries::get_user_by_email(&state.pool, &body.email)
    .await
    .map_err(map_db_err)?
    .ok_or(AppError::Unauthorized)?;

// password hash check follows immediately — is_active NEVER checked
let password_hash = user.password_hash.as_deref().ok_or(AppError::Unauthorized)?;
```

This means an administrator can "deactivate" a user via the admin API, but that user can still log in and obtain fresh access/refresh tokens. The deactivation only prevents new API operations that explicitly call `get_user_by_id` (like `GET /auth/me`). The login itself is not gated.

**Fix:** Add an `is_active` check immediately after user lookup:
```rust
let user = user_queries::get_user_by_email(&state.pool, &body.email)
    .await
    .map_err(map_db_err)?
    .ok_or(AppError::Unauthorized)?;

if !user.is_active {
    tracing::info!(
        event_type = "login",
        user_id = %user.id,
        "Login rejected: account deactivated"
    );
    return Err(AppError::Unauthorized);
}
```

---

### CR-04: SQL injection risk in `list_sessions` tag filter via raw string interpolation

**File:** `performancebench-server/db/src/session_queries.rs:45-77`

**Problem:** When tag filtering is active, the function builds SQL via `format!()` with raw string interpolation instead of Diesel's parameterized query builders:

```rust
let tag_filter = format!(
    "tags && ARRAY[{}]::text[]",
    tag_list
        .iter()
        .map(|t| format!("'{}'", t.replace('\'', "''")))
        .collect::<Vec<_>>()
        .join(", ")
);

let count_query = diesel::sql_query(format!(
    "SELECT COUNT(*) as count FROM sessions WHERE user_id = $1 AND {}",
    tag_filter
))
```

Tags come from user-controlled HTTP query parameters (`?tags=a,b,c`). The single-quote escaping (`replace('\'', "''")`) is _technically_ correct for standard PostgreSQL string literals. However, manual SQL escaping is widely recognized as fragile and error-prone:

- It relies on correct and complete implementation of PostgreSQL escaping rules
- It bypasses Diesel's compile-time query safety guarantees
- It creates a maintenance hazard: any future modification to this code path could reintroduce a vulnerability
- It does not handle edge cases like null bytes in tag values

**Fix:** Use parameterized query construction. One approach with Diesel:
```rust
// Build a parameterized overlap query using Diesel's `sql_function!` or ARRAY constructor
use diesel::expression::dsl::sql;
use diesel::sql_types::{Array, Text};

// Alternative: bind each tag as a parameter using ANY()
let count_query = diesel::sql_query(
    "SELECT COUNT(*) as count FROM sessions WHERE user_id = $1 AND tags && $2::text[]"
)
.bind::<diesel::sql_types::Uuid, _>(user_id)
.bind::<diesel::sql_types::Array<diesel::sql_types::Text>, _>(tag_list);
```

---

## MEDIUM Severity Issues

### WR-01: JWT secret auto-generated on every restart — invalidates all user sessions

**File:** `performancebench-server/server/src/config.rs:111-118`

**Problem:** If `JWT_SECRET` is not set in the environment, a new UUID is generated on each restart:

```rust
if config.jwt_secret.is_empty() {
    config.jwt_secret = uuid::Uuid::new_v4().to_string();
}
```

This means:
- All existing JWTs (cookies, refresh tokens) become invalid after restart
- All users are forcibly logged out
- In a production deployment, this could be triggered accidentally by a misconfigured environment variable
- The generated secret is logged at WARN level, which means it appears in logs

**Fix:** Require `JWT_SECRET` at startup — fail with a clear error instead of auto-generating:
```rust
if config.jwt_secret.is_empty() {
    return Err(config::ConfigError::Message(
        "JWT_SECRET environment variable is required. \
         Generate: openssl rand -base64 64".to_string()
    ));
}
```

---

### WR-02: `std::sync::Mutex` used in async context — blocks tokio worker threads

**File:** `performancebench-server/server/src/routes/ws.rs:29`, `89`; `state.rs:17`

**Problem:** The `live_sessions` HashMap uses `Arc<Mutex<HashMap<...>>>` (std Mutex, not tokio Mutex). When the lock is acquired in an async handler and contention occurs, the holding thread blocks the tokio worker completely:

```rust
// ws.rs:29 — in ws_handler (async fn)
let rx = {
    let mut sessions = state.live_sessions.lock().unwrap(); // std::sync::Mutex
    // ...
    tx.subscribe()
};
```

```rust
// ws.rs:89 — in push_live_batch (async fn)
let tx = {
    let mut sessions = state.live_sessions.lock().unwrap(); // std::sync::Mutex
    // ...
};
```

In a production scenario with many concurrent WebSocket connections, contention on this lock will block tokio worker threads, causing cascading latency across the entire server.

**Fix:** Replace `Arc<Mutex<HashMap<...>>>` with `Arc<tokio::sync::Mutex<HashMap<...>>>` and use `.lock().await`:
```rust
// state.rs
pub live_sessions: Arc<tokio::sync::Mutex<HashMap<Uuid, broadcast::Sender<MetricSample>>>>,

// ws.rs
let rx = {
    let mut sessions = state.live_sessions.lock().await;
    // ...
};
```

Alternatively, use `dashmap::DashMap` for lock-free concurrent access to this HashMap if it becomes a hotspot.

---

### WR-03: Missing refresh token `expires_at` check on token refresh

**File:** `performancebench-server/server/src/routes/auth.rs:237-245`

**Problem:** The refresh handler checks `stored.is_revoked` but does NOT check `stored.expires_at` against the current time:

```rust
let stored = token_queries::get_refresh_token_by_hash(&state.pool, &rt_hash)
    .await
    .map_err(map_db_err)?
    .ok_or(AppError::Unauthorized)?;

if stored.is_revoked {
    return Err(AppError::Unauthorized);
}
// MISSING: no check of stored.expires_at
```

A refresh token that has passed its natural 7-day expiry but wasn't explicitly revoked could still be used.

**Fix:** Add an expiry check:
```rust
let now = chrono::Utc::now().naive_utc();
if stored.is_revoked || stored.expires_at <= now {
    return Err(AppError::Unauthorized);
}
```

---

### WR-04: Hardcoded default database credentials in config

**File:** `performancebench-server/server/src/config.rs:95`

**Problem:** The default database URL contains a hardcoded username and password:

```rust
.set_default("database_url", "postgres://benchify:benchify@localhost:5432/benchify")?
```

If an operator deploys without setting the `DATABASE_URL` environment variable, the database uses the well-known password `benchify`. While this is localhost-only by default, it's still a publicly-known credential in the source code and a security hardening issue.

**Fix:** Either:
1. Remove the default entirely and fail with a clear error if `DATABASE_URL` is not set
2. Use a default with no password (requiring peer/trust auth only):
```rust
.set_default("database_url", "postgres://localhost:5432/benchify")?
```

---

### WR-05: `unwrap()` on `SystemTime::now().duration_since(UNIX_EPOCH)` can panic in request handlers

**File:** `performancebench-server/server/src/utils/jwt.rs:29`, `47`

**Problem:** Token creation uses unchecked `unwrap()` on `SystemTime::now().duration_since(UNIX_EPOCH)`:

```rust
let now = std::time::SystemTime::now()
    .duration_since(std::time::UNIX_EPOCH)
    .unwrap()  // panics if system clock is before 1970
    .as_secs() as usize;
```

`duration_since()` returns `Err` when the current time is before the UNIX epoch. This can happen on systems with incorrect clocks, during boot before NTP sync, or on embedded devices. A panic here would crash the tokio task serving the request, potentially taking down the connection handler.

**Fix:** Return an error instead of panicking:
```rust
let now = std::time::SystemTime::now()
    .duration_since(std::time::UNIX_EPOCH)
    .map_err(|_| AppError::Internal("System clock is before UNIX epoch".to_string()))?
    .as_secs() as usize;
```

---

### WR-06: No rate limiting on auth endpoints — brute force vulnerability

**File:** `performancebench-server/server/src/routes/auth.rs:98-132` (login), `174-214` (register)

**Problem:** The login and register endpoints have no rate limiting. An attacker can attempt unlimited password guesses against the login endpoint. The register endpoint, while gated to `user_count == 0`, could be probed repeatedly.

**Fix:** Add a rate-limiting middleware to auth endpoints. With `tower`:
```rust
use tower::limit::RateLimitLayer;

let public_auth = Router::new()
    .route("/auth/login", post(auth::login))
    .layer(RateLimitLayer::new(5, std::time::Duration::from_secs(60))) // 5 req/min
    ...
```

---

### WR-07: `push_live_batch` accepts any API token scope — missing write scope check

**File:** `performancebench-server/server/src/routes/ws.rs:82-115`, `routes/mod.rs:68-70`

**Problem:** The `push_live_batch` handler requires API token auth but does NOT verify:
1. That the token has `write` scope (a `read`-only token can push data)
2. That the authenticated user owns the target session

```rust
// ws.rs:82 — no scope or ownership check
pub async fn push_live_batch(
    State(state): State<AppState>,
    Path(session_id): Path<Uuid>,
    Json(body): Json<LiveBatchBody>,
) -> Result<impl IntoResponse, AppError> {
```

A read-only API token can inject arbitrary metric samples into any session, potentially poisoning analytics data.

**Fix:** Add scope and ownership validation:
```rust
pub async fn push_live_batch(
    State(state): State<AppState>,
    Path(session_id): Path<Uuid>,
    Extension(auth_user): Extension<AuthUser>,
    Json(body): Json<LiveBatchBody>,
) -> Result<impl IntoResponse, AppError> {
    // Scope check
    if auth_user.role != "write" && auth_user.role != "admin" {
        return Err(AppError::Forbidden);
    }
    // Ownership check
    if !session_queries::session_exists(&state.pool, session_id).await.unwrap_or(false) {
        return Err(AppError::NotFound("Session".to_string()));
    }
    // ... rest of handler
}
```

---

### WR-08: Unbounded `live_sessions` HashMap — entries never removed (memory leak)

**File:** `performancebench-server/server/src/routes/ws.rs:30-35`, `state.rs:17`

**Problem:** The `live_sessions` HashMap maps `session_id` to `broadcast::Sender`. Entries are added via `entry().or_insert_with()` but are **never removed**. When all WebSocket clients disconnect from a session, the broadcast sender remains in the map indefinitely:

```rust
// ws.rs:30
let tx = sessions.entry(session_id).or_insert_with(|| {
    let (tx, _) = tokio::sync::broadcast::channel(1024);
    tx
});
```

Over time, this unbounded growth will exhaust server memory. Every session ever pushed to or watched via WebSocket permanently occupies an entry in this map.

**Fix:** Periodically clean up entries with zero receivers, or use weak references to detect when the last receiver disconnects:
```rust
// After tx.subscribe(), detect when all receivers drop
// Use sender.receiver_count() to check for active receivers

// In a background task or on each new connection:
let mut sessions = state.live_sessions.lock().await;
sessions.retain(|_, tx| tx.receiver_count() > 0);
```

---

### WR-09: JSONB key interpolated into raw SQL — maintenance risk for future SQL injection

**File:** `performancebench-server/db/src/trend_queries.rs:126-138`, `147-159`

**Problem:** The `get_metric_trends` function interpolates `jsonb_key` into raw SQL via `format!()`:

```rust
let sql = format!(
    r#"SELECT started_at::text as ts, id as sid, app_name,
       (session_stats->>'{}')::double precision as val
       FROM sessions WHERE ..."#,
    jsonb_key,
);
```

Currently, all callers use hardcoded string literals (`"cpuAvgPct"`, `"memoryAvgKb"`, etc.), so no injection is possible today. However, this pattern creates a latent vulnerability: if any caller is changed to pass user-controlled input into `jsonb_key`, an attacker could break out of the `->>` JSON operator and inject arbitrary SQL.

**Fix:** Use Diesel's typed JSONB path extraction instead of raw string interpolation:
```rust
// Use Diesel's JSONB operators
let sql = r#"
    SELECT started_at::text as ts, id as sid, app_name,
           (session_stats->>$1)::double precision as val
    FROM sessions WHERE ..."#;

diesel::sql_query(sql)
    .bind::<Text, _>(jsonb_key)
    // ... other binds
```

This makes `jsonb_key` a bound parameter.

---

### WR-10: `parse_timestamp` silently returns None — hides data quality issues

**File:** `performancebench-server/server/src/routes/upload.rs:371-400`, `194`

**Problem:** When a timestamp cannot be parsed, `parse_timestamp` returns `None`, and the caller silently falls back to `chrono::Utc::now()`:

```rust
let started_at = parse_timestamp(&payload.session.started_at)
    .unwrap_or_else(|| chrono::Utc::now().naive_utc());
```

This masks data quality problems — if a client sends malformed timestamps, they are silently replaced with "now" rather than being rejected. The incorrect timestamps will then pollute analytics queries and trend calculations.

**Fix:** Return an error for unparseable timestamps instead of silently substituting:
```rust
let started_at = parse_timestamp(&payload.session.started_at)
    .ok_or_else(|| AppError::Validation(format!(
        "Invalid started_at timestamp: {}", payload.session.started_at
    )))?;
```

---

_Reviewed: 2026-05-07T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
