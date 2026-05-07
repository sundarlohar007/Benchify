use axum::extract::{Query, State};
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::routing::get;
use axum::{Extension, Json, Router};
use serde::Deserialize;

use crate::error::AppError;
use crate::state::AppState;
use crate::utils::jwt::AuthUser;
use db::trend_queries;

#[derive(Debug, Deserialize)]
pub struct TrendsQuery {
    pub start_date: String,
    pub end_date: String,
    pub app_name: Option<String>,
}

/// GET /api/v1/trends/fps — FPS median trends across sessions.
pub async fn get_fps_trends(
    State(state): State<AppState>,
    Query(params): Query<TrendsQuery>,
    Extension(auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    let data = trend_queries::get_fps_trends(
        &state.pool,
        auth_user.user_id,
        &params.start_date,
        &params.end_date,
        params.app_name.as_deref(),
    )
    .await
    .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?;

    Ok((StatusCode::OK, Json(serde_json::json!({ "data": data }))))
}

/// GET /api/v1/trends/cpu — CPU avg trends across sessions.
pub async fn get_cpu_trends(
    State(state): State<AppState>,
    Query(params): Query<TrendsQuery>,
    Extension(auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    let data = trend_queries::get_metric_trends(
        &state.pool,
        auth_user.user_id,
        &params.start_date,
        &params.end_date,
        "cpuAvgPct",
        params.app_name.as_deref(),
    )
    .await
    .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?;

    Ok((StatusCode::OK, Json(serde_json::json!({ "data": data }))))
}

/// GET /api/v1/trends/memory — Memory avg trends across sessions.
pub async fn get_memory_trends(
    State(state): State<AppState>,
    Query(params): Query<TrendsQuery>,
    Extension(auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    let data = trend_queries::get_metric_trends(
        &state.pool,
        auth_user.user_id,
        &params.start_date,
        &params.end_date,
        "memoryAvgKb",
        params.app_name.as_deref(),
    )
    .await
    .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?;

    Ok((StatusCode::OK, Json(serde_json::json!({ "data": data }))))
}

/// GET /api/v1/trends/battery — Battery drain trends across sessions.
pub async fn get_battery_trends(
    State(state): State<AppState>,
    Query(params): Query<TrendsQuery>,
    Extension(auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    let data = trend_queries::get_metric_trends(
        &state.pool,
        auth_user.user_id,
        &params.start_date,
        &params.end_date,
        "batteryDrainPerHour",
        params.app_name.as_deref(),
    )
    .await
    .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?;

    Ok((StatusCode::OK, Json(serde_json::json!({ "data": data }))))
}

/// GET /api/v1/trends/network — Network avg trends across sessions.
pub async fn get_network_trends(
    State(state): State<AppState>,
    Query(params): Query<TrendsQuery>,
    Extension(auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    let data = trend_queries::get_metric_trends(
        &state.pool,
        auth_user.user_id,
        &params.start_date,
        &params.end_date,
        "netWifiAvgKbps",
        params.app_name.as_deref(),
    )
    .await
    .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?;

    Ok((StatusCode::OK, Json(serde_json::json!({ "data": data }))))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/fps", get(get_fps_trends))
        .route("/cpu", get(get_cpu_trends))
        .route("/memory", get(get_memory_trends))
        .route("/battery", get(get_battery_trends))
        .route("/network", get(get_network_trends))
}
