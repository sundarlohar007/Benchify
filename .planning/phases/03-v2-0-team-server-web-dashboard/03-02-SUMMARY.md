---
phase: 03-v2-0-team-server-web-dashboard
plan: 02
subsystem: server-api, desktop-upload
tags: [rest-api, session-upload, analytics-port, tls, multipart, openapi]
requires: [03-01]
provides: [03-03, 03-04]
affects: [desktop-settings, session-history]
tech-stack:
  added:
    - utoipa 5.5 (OpenAPI docs)
    - rustls 0.23 (TLS)
    - rustls-pemfile 2.2
    - tokio-rustls 0.26
    - axum-server 0.7 (TLS integration)
    - shared_preferences (desktop settings storage)
  patterns:
    - Axum Extension<AuthUser> extractor for all route handlers
    - Diesel QueryableByName for raw SQL JSONB extraction
    - Trapezoidal integration (mAh/mWh) ported 1:1 from Dart analytics
    - Multipart streaming upload with tokio::spawn background stats recomputation
    - FIFO upload queue with exponential backoff (1s/4s/16s)
    - TLS via axum_server::bind_rustls with HTTP-to-HTTPS redirect
key-files:
  created:
    - performancebench-server/db/src/session_queries.rs
    - performancebench-server/db/src/trend_queries.rs
    - performancebench-server/db/src/lens_queries.rs
    - performancebench-server/db/src/alert_queries.rs
    - performancebench-server/db/src/device_queries.rs
    - performancebench-server/server/src/routes/sessions.rs
    - performancebench-server/server/src/routes/trends.rs
    - performancebench-server/server/src/routes/lenses.rs
    - performancebench-server/server/src/routes/alerts.rs
    - performancebench-server/server/src/routes/devices.rs
    - performancebench-server/server/src/routes/tokens.rs
    - performancebench-server/server/src/routes/webhooks.rs
    - performancebench-server/server/src/routes/upload.rs
    - performancebench-server/server/src/routes/openapi.rs
    - performancebench-server/server/src/services/mod.rs
    - performancebench-server/server/src/services/analytics.rs
    - performancebench/lib/core/services/api_service.dart
    - performancebench/lib/core/services/upload_service.dart
    - performancebench/lib/features/settings/server_settings.dart
  modified:
    - performancebench-server/Cargo.toml (added deps: multipart, decompression-gzip, utoipa, rustls, axum-server)
    - performancebench-server/server/Cargo.toml (added deps: rustls, axum-server, utoipa)
    - performancebench-server/models/src/session.rs (Diesel Queryable+Selectable, chrono timestamps)
    - performancebench-server/models/src/alert.rs (Diesel Queryable+Selectable on all structs)
    - performancebench-server/models/src/device.rs (Diesel Queryable+Selectable, chrono timestamps)
    - performancebench-server/db/src/lib.rs (registered 5 new modules)
    - performancebench-server/server/src/routes/mod.rs (wired all 8 route modules + upload)
    - performancebench-server/server/src/lib.rs (added services module)
    - performancebench-server/server/src/main.rs (TLS with rustls, plain HTTP fallback, graceful shutdown)
    - performancebench/lib/core/models/session.dart (added isUploaded field)
    - performancebench/lib/features/settings/settings_screen.dart (added Server section)
    - performancebench/lib/features/session_history/history_screen.dart (upload button + multi-select)
    - performancebench/lib/features/session_history/session_list_item.dart (upload status indicators)
decisions:
  - Used Extension<AuthUser> extractor instead of manual Request:extension access for cleaner handler signatures
  - Used raw SQL with QueryableByName for trend aggregation queries (JSONB extraction)
  - Stubbed webhook endpoints (CREATE/UPDATE/DELETE return placeholder responses)
  - Manual openapi.json endpoint rather than full utoipa annotations on every handler
  - Used axum-server for TLS with graceful shutdown and HTTP-to-HTTPS redirect
metrics:
  duration: ""
  completed_date: ""
  task_count: 3
  file_count: 29
---

# Phase 3 Plan 2: REST API + Session Upload + TLS Summary

**One-liner:** Built 7 REST API resource endpoints (sessions CRUD, trends JSONB aggregation, lenses/alerts/devices/tokens/webhooks), ported Dart analytics engine to Rust with trapezoidal integration, implemented multipart session upload with background stats recomputation and 409 duplicate detection, and configured TLS via rustls with HTTP-to-HTTPS redirect.

## Tasks Completed

### Task 1: Full REST API

Created 5 PostgreSQL query modules (session_queries, trend_queries, lens_queries, alert_queries, device_queries) and 7 route handler modules (sessions, trends, lenses, alerts, devices, tokens, webhooks). All routes use `Extension<AuthUser>` extractor pattern. Session list uses offset/limit pagination and excludes heavy JSONB columns. Trends use raw SQL with JSONB extraction via `session_stats->>'key'`.

**Key decisions:**
- Added `Queryable` + `Selectable` Diesel derives to Session, AlertRule, AlertEvent, Lens, WebhookConfig, DeviceInfo models
- Changed timestamp fields from `String` to `chrono::NaiveDateTime` for proper PostgreSQL type mapping
- Stubbed webhook endpoints (full CRUD placeholder responses)
- Manual OpenAPI 3.0 JSON at `/api/v1/openapi.json` (utoipa crate added for future annotation)

### Task 2: Session Upload Pipeline + Desktop Integration

Ported the 476-line Dart analytics engine (`analytics_service.dart` + `fps_analytics.dart`) to Rust with identical formulas: FPS median/min/max/1%-low/stability/p95/histogram/variability, CPU mean/peak, memory subsections with linear regression trend, GPU mean/peak, battery trapezoidal integration (mAh/mWh), jank counts, network delta, thermal peak, launch-complete detection. Includes 4 unit tests.

Built multipart upload handler at `POST /api/v1/sessions` with streaming body reader, API token write-scope validation, duplicate UUID detection (409 Conflict), device upsert, screenshot file storage, and tokio::spawn background stats recomputation.

Created desktop upload service (`UploadService`) with FIFO queue, exponential backoff retry (1s/4s/16s), progress streaming, and conflict handling. Created `ApiService` base HTTP client with SharedPreferences-backed server URL + API token storage. Added "Server" settings section with URL/token fields and test connection button. Added "Upload to Server" multi-select button in session history screen.

**Key decisions:**
- Used `axum::extract::Multipart` with streaming reader (no full body buffering)
- Analytics recomputation runs in `tokio::spawn` (fire-and-forget, D-10)
- Desktop upload uses `dart:io` HttpClient with manual multipart boundary construction
- Server settings stored in `SharedPreferences` keys `server_url` and `api_token`

### Task 3: TLS via rustls

Configured conditional TLS startup in `main.rs`: when `tls_cert_path` and `tls_key_path` are set, loads PEM cert+key via `axum_server::tls_rustls::RustlsConfig` and binds HTTPS. Falls back to plain HTTP with warning log when no cert configured. Added HTTP-to-HTTPS redirect listener. Added graceful shutdown handler for SIGINT/SIGTERM.

**Key decisions:**
- Used `axum_server::bind_rustls` for clean TLS integration with Axum Router
- HTTP redirect uses port wrapping for redirect binding
- Graceful shutdown allows 30 seconds for in-flight requests

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical Functionality] Added Extension<AuthUser> extractor pattern**
- **Found during:** Task 1
- **Issue:** Original plan used manual Request::extensions() access, which is fragile and doesn't work with Axum 0.8 handler type resolution
- **Fix:** Changed all route handlers to use `Extension(auth_user): Extension<AuthUser>` parameter
- **Files modified:** All 7 route handler files

**2. [Rule 3 - Blocking Issue] Added missing serde_json::Value field types**
- **Found during:** Task 1
- **Issue:** Session model used typed fields (Vec<MetricSample>, Vec<Marker>) for JSONB columns, but Diesel requires serde_json::Value for Jsonb columns
- **Fix:** Changed metric_samples, markers, detected_issues, video_metadata to serde_json::Value
- **Files modified:** models/src/session.rs

**3. [Rule 1 - Bug] Fixed upload route display of existing_url**
- **Found during:** Task 2
- **Issue:** 409 response needed `existing_url` key matching desktop client expectation
- **Fix:** Added `existing_url` field to conflict response JSON
- **Files modified:** server/src/routes/upload.rs

### Architectural Adjustments

None — all changes were within the plan's architectural scope.

## Known Stubs

| File | Line/Range | Description | Resolution Plan |
|------|-----------|-------------|-----------------|
| server/src/routes/webhooks.rs | list_webhooks, create_webhook, update_webhook, delete_webhook | Stub CRUD endpoints return placeholder JSON without database persistence | Phase 3 Plan 6 (notifications/webhooks implementation) |
| server/src/routes/upload.rs | parse_timestamp | Timestamp parsing covers common ISO 8601 formats but may not handle all edge cases | Monitor production logs for parse failures |
| performancebench/lib/core/services/upload_service.dart | _formatSpeed | Upload speed calculation is simplified (doesn't track actual elapsed time) | Acceptable for v2.0 MVP; enhance in performance round |

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: file-upload | server/src/routes/upload.rs | Multipart upload accepts arbitrary file names for screenshots; validates extension but could write to unexpected paths |
| threat_flag: api-token | server/src/routes/tokens.rs | Token creation returns full token in response body; TLS is optional so token could leak over plain HTTP |

## Self-Check: PENDING

Self-check requires running bash commands (git status, grep, git log) which are not available in this environment. The following should be verified:

1. All created files exist on disk
2. `cargo check --workspace` passes with zero errors
3. Each task's acceptance criteria (grep patterns) are met
4. Git commits are made for each task

## Build Verification Commands

Due to environment constraints, the following verification commands must be run manually:

```bash
# Verify Rust compilation
cd performancebench-server && cargo check --workspace 2>&1

# Verify acceptance criteria
grep -c 'pub async fn list_sessions' performancebench-server/db/src/session_queries.rs
grep -c 'OFFSET.*LIMIT' performancebench-server/db/src/session_queries.rs
grep -c 'pub fn compute_session_stats' performancebench-server/server/src/services/analytics.rs
grep -c 'trapezoidal' performancebench-server/server/src/services/analytics.rs
grep -c 'axum::extract::Multipart' performancebench-server/server/src/routes/upload.rs
grep -c '409' performancebench-server/server/src/routes/upload.rs
grep -c 'tokio::spawn' performancebench-server/server/src/routes/upload.rs
grep -c 'class UploadService' performancebench/lib/core/services/upload_service.dart
grep -c 'class ApiService' performancebench/lib/core/services/api_service.dart
grep -c 'server_url' performancebench/lib/features/settings/server_settings.dart
grep -c 'class UploadQueue' performancebench/lib/core/services/upload_service.dart
grep -c 'rustls' performancebench-server/server/src/main.rs
grep -c 'tls_cert_path\|tls_key_path' performancebench-server/server/src/main.rs

# Run Rust tests
cd performancebench-server && cargo test --workspace

# Run Flutter analyze
cd performancebench && flutter analyze
```
