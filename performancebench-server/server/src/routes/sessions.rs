use axum::extract::{Path, Query, State};
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::{Extension, Json, Router};
use axum::routing::get;
use serde::Deserialize;
use uuid::Uuid;

use db::session_queries;
use crate::error::AppError;
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

    Ok((StatusCode::OK, Json(serde_json::json!({"status": "deleted"}))))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/", get(list_sessions))
        .route("/{id}", get(get_session).delete(delete_session))
}
