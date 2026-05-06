use axum::extract::{Path, Query, State};
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::{Extension, Json, Router};
use axum::routing::get;
use serde::Deserialize;
use uuid::Uuid;

use db::session_queries;
use models::audit::{AuditEventCategory, AuditEventType};
use crate::error::AppError;
use crate::middleware::audit as audit_mw;
use crate::state::AppState;
use crate::utils::jwt::AuthUser;

/// Query params for session list endpoint.
#[derive(Debug, Deserialize)]
pub struct ListSessionsQuery {
    #[serde(default = "default_offset")]
    pub offset: i64,
    #[serde(default = "default_limit")]
    pub limit: i64,
    pub app_name: Option<String>,
    pub device_model: Option<String>,
    pub project_id: Option<String>,
    /// Comma-separated tags
    pub tags: Option<String>,
}

fn default_offset() -> i64 {
    0
}
fn default_limit() -> i64 {
    50
}

/// GET /api/v1/sessions — list sessions with offset/limit pagination.
/// Excludes metric_samples JSONB from response (Pitfall 4).
pub async fn list_sessions(
    State(state): State<AppState>,
    Query(params): Query<ListSessionsQuery>,
    Extension(auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {

    let tags_vec: Option<Vec<String>> = params
        .tags
        .as_ref()
        .map(|t| t.split(',').map(|s| s.trim().to_string()).collect());

    let (mut sessions, total) = session_queries::list_sessions(
        &state.pool,
        auth_user.user_id,
        params.offset,
        params.limit,
        params.app_name.as_deref(),
        params.device_model.as_deref(),
        tags_vec.as_deref(),
        params.project_id.as_deref(),
    )
    .await
    .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?;

    // Zero out heavy JSONB fields for list endpoint (Pitfall 4)
    for session in &mut sessions {
        session.metric_samples = serde_json::Value::Array(vec![]);
        session.markers = serde_json::Value::Array(vec![]);
        session.detected_issues = serde_json::Value::Array(vec![]);
    }

    let response = serde_json::json!({
        "data": sessions,
        "total": total,
        "offset": params.offset,
        "limit": params.limit,
    });

    Ok((StatusCode::OK, Json(response)))
}

/// GET /api/v1/sessions/:id — get full session detail including JSONB data.
pub async fn get_session(
    State(state): State<AppState>,
    Path(session_id): Path<Uuid>,
    Extension(auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {

    let session = session_queries::get_session_by_id_and_user(
        &state.pool,
        session_id,
        auth_user.user_id,
    )
    .await
    .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?
    .ok_or_else(|| AppError::NotFound("Session".to_string()))?;

    Ok((StatusCode::OK, Json(session)))
}

/// DELETE /api/v1/sessions/:id — delete a session (owner-scoped).
pub async fn delete_session(
    State(state): State<AppState>,
    Path(session_id): Path<Uuid>,
    Extension(auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    // Verify ownership
    let _existing = session_queries::get_session_by_id_and_user(
        &state.pool,
        session_id,
        auth_user.user_id,
    )
    .await
    .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?
    .ok_or_else(|| AppError::NotFound("Session".to_string()))?;

    session_queries::delete_session(&state.pool, session_id, auth_user.user_id)
        .await
        .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?;

    // Audit session delete
    let _ = audit_mw::audit_session_event(
        &state.pool,
        &auth_user,
        AuditEventType::SessionDeleted,
        session_id,
        None,
    ).await;

    Ok((StatusCode::OK, Json(serde_json::json!({"status": "deleted"}))))
}

/// GET /api/v1/sessions/{id}/cpu-threads — per-thread CPU breakdown.
///
/// Extracts thread-level CPU data from session_stats JSONB (populated by PC profiling agent).
/// Returns `available: false` if the session doesn't have thread CPU data (e.g., Android/iOS targets).
/// Documents the root/administrator requirement for thread-level CPU profiling.
pub async fn get_cpu_threads(
    State(state): State<AppState>,
    Path(session_id): Path<Uuid>,
    Extension(auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    let session = session_queries::get_session_by_id_and_user(
        &state.pool,
        session_id,
        auth_user.user_id,
    )
    .await
    .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?
    .ok_or_else(|| AppError::NotFound("Session".to_string()))?;

    // Check if the session has PC thread CPU data in session_stats JSONB
    let thread_cpu_data = session
        .session_stats
        .get("pc_metrics")
        .and_then(|pm| pm.get("thread_cpu"))
        .and_then(|tc| tc.as_array());

    match thread_cpu_data {
        Some(raw_threads) if !raw_threads.is_empty() => {
            // Aggregate: group by (tid, thread_name), compute avg/peak, sum times, count samples
            let mut threads_map: std::collections::HashMap<
                (i64, String),
                (f64, f64, i64, i64, usize),
            > = std::collections::HashMap::new();

            for sample in raw_threads {
                let tid = sample.get("tid").and_then(|v| v.as_i64()).unwrap_or(0);
                let thread_name = sample
                    .get("thread_name")
                    .and_then(|v| v.as_str())
                    .unwrap_or("unknown")
                    .to_string();
                let cpu_pct = sample.get("cpu_percent").and_then(|v| v.as_f64()).unwrap_or(0.0);
                let user_time = sample.get("user_time_ms").and_then(|v| v.as_i64()).unwrap_or(0);
                let kernel_time = sample
                    .get("kernel_time_ms")
                    .and_then(|v| v.as_i64())
                    .unwrap_or(0);

                let entry = threads_map
                    .entry((tid, thread_name.clone()))
                    .or_insert((0.0, 0.0, 0, 0, 0));
                entry.0 += cpu_pct; // sum for avg
                entry.1 = entry.1.max(cpu_pct); // peak
                entry.2 += user_time;
                entry.3 += kernel_time;
                entry.4 += 1; // sample count
            }

            let threads: Vec<serde_json::Value> = threads_map
                .into_iter()
                .map(|((tid, thread_name), (cpu_sum, cpu_peak, user_time, kernel_time, count))| {
                    serde_json::json!({
                        "thread_name": thread_name,
                        "tid": tid,
                        "cpu_percent_avg": format!("{:.1}", cpu_sum / count as f64).parse::<f64>().unwrap_or(0.0),
                        "cpu_percent_peak": cpu_peak,
                        "user_time_ms": user_time,
                        "kernel_time_ms": kernel_time,
                        "sample_count": count,
                    })
                })
                .collect();

            let total_threads = threads.len();

            let response = serde_json::json!({
                "available": true,
                "requires_root": true,
                "note": "Thread-level CPU breakdown requires root/administrator access on the target device",
                "threads": threads,
                "total_threads": total_threads,
                "collection_duration_ms": 60000,
            });

            Ok((StatusCode::OK, Json(response)))
        }
        _ => {
            // No thread CPU data available (Android/iOS, or PC session without root)
            let response = serde_json::json!({
                "available": false,
                "requires_root": true,
                "note": "Thread-level CPU breakdown requires root/administrator access on the target device. This session does not have thread CPU data (only available from PC profiling agent with root access).",
                "threads": [],
                "total_threads": 0,
                "collection_duration_ms": 0,
            });

            Ok((StatusCode::OK, Json(response)))
        }
    }
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/", get(list_sessions))
        .route("/{id}", get(get_session).delete(delete_session))
        .route("/{id}/cpu-threads", get(get_cpu_threads))
        .route("/{id}/jira", axum::routing::post(crate::routes::jira::create_jira_issue))
}
