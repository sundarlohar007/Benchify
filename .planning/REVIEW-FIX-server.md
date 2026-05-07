---
phase: server
fixed_at: 2026-05-07T09:10:00Z
review_path: .planning/REVIEW-server.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase Server: Code Review Fix Report

**Fixed at:** 2026-05-07T09:10:00Z
**Source review:** .planning/REVIEW-server.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4 (all HIGH/CR severity)
- Fixed: 4
- Skipped: 0

## Fixed Issues

### CR-01: WebSocket endpoint has NO authentication

**Files modified:** `performancebench-server/server/src/routes/ws.rs`, `performancebench-server/server/src/routes/mod.rs`
**Commit:** 0bdaf6e
**Applied fix:** Added `auth_middleware` to `/ws/live/{session_id}` route and `session_queries::get_session_by_id_and_user` ownership verification in `ws_handler`. The handler now requires `Extension<AuthUser>` and returns `Result<impl IntoResponse, AppError>`, rejecting unauthenticated or unauthorized connections before upgrading to WebSocket.

### CR-02: Path traversal in screenshot file saving

**Files modified:** `performancebench-server/server/src/routes/upload.rs`
**Commit:** 5b36715
**Applied fix:** Sanitized screenshot filenames by using `std::path::Path::file_name()` to extract only the basename, stripping any directory traversal components. Added belt-and-suspenders check rejecting filenames containing `..` or starting with `/` or `\`. Falls back to UUID-based name if basename extraction fails.

### CR-03: Deactivated users can still authenticate

**Files modified:** `performancebench-server/server/src/routes/auth.rs`
**Commit:** d26ce96
**Applied fix:** Added `!user.is_active` check immediately after user lookup in the `login` handler, before password verification. Deactivated accounts now receive `AppError::Unauthorized` with a structured log message recording the rejection.

### CR-04: SQL injection risk via raw string interpolation in tag filter

**Files modified:** `performancebench-server/db/src/session_queries.rs`
**Commit:** 07c85fd (included with web fixes)
**Applied fix:** Replaced `format!()`-based raw SQL string interpolation with Diesel's parameterized `bind::<Array<Text>, _>(tag_list)`. The tag filter now uses `tags && $2::text[]` with bound parameters instead of string-formatted `ARRAY['tag1','tag2']::text[]`. Eliminates the fragile manual single-quote escaping and makes the query safe against SQL injection from user-controlled tag values.

---

_Fixed: 2026-05-07T09:10:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
