use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::{Extension, Json, Router};
use axum::routing::get;
use uuid::Uuid;

use db::device_queries;
use crate::error::AppError;
use crate::state::AppState;
use crate::utils::jwt::AuthUser;

/// GET /api/v1/devices — list devices the user has sessions for.
pub async fn list_devices(
    State(state): State<AppState>,
    Extension(auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    let devices = device_queries::list_devices_for_user(&state.pool, auth_user.user_id)
        .await
        .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?;

    Ok((StatusCode::OK, Json(serde_json::json!({ "data": devices }))))
}

/// GET /api/v1/devices/:id — device detail with session count.
pub async fn get_device(
    State(state): State<AppState>,
    Path(device_id): Path<Uuid>,
    Extension(auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    let device = device_queries::get_device(&state.pool, device_id)
        .await
        .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?
        .ok_or_else(|| AppError::NotFound("Device".to_string()))?;

    let session_count = device_queries::get_device_session_count(
        &state.pool,
        device_id,
        auth_user.user_id,
    )
    .await
    .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?;

    Ok((
        StatusCode::OK,
        Json(serde_json::json!({
            "device": device,
            "session_count": session_count,
        })),
    ))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/", get(list_devices))
        .route("/{id}", get(get_device))
}
