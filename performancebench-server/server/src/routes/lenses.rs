use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::{Extension, Json, Router};
use axum::routing::{delete, get, post, put};
use serde::Deserialize;
use uuid::Uuid;

use db::lens_queries;
use crate::error::AppError;
use crate::state::AppState;
use crate::utils::jwt::AuthUser;

#[derive(Debug, Deserialize)]
pub struct ListLensesQuery {
    #[serde(default = "default_include_public")]
    pub include_public: bool,
}

fn default_include_public() -> bool {
    true
}

#[derive(Debug, Deserialize)]
pub struct CreateLensBody {
    pub name: String,
    pub description: Option<String>,
    #[serde(default)]
    pub filters: serde_json::Value,
    #[serde(default)]
    pub chart_config: serde_json::Value,
    #[serde(default)]
    pub is_public: bool,
}

#[derive(Debug, Deserialize)]
pub struct UpdateLensBody {
    pub name: Option<String>,
    pub description: Option<Option<String>>,
    pub filters: Option<serde_json::Value>,
    pub chart_config: Option<serde_json::Value>,
    pub is_public: Option<bool>,
}

/// GET /api/v1/lenses — list user's lenses + optionally public lenses.
pub async fn list_lenses(
    State(state): State<AppState>,
    axum::extract::Query(params): axum::extract::Query<ListLensesQuery>,
    Extension(auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    let lenses = lens_queries::list_lenses(&state.pool, auth_user.user_id, params.include_public)
        .await
        .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?;

    Ok((StatusCode::OK, Json(serde_json::json!({ "data": lenses }))))
}

/// GET /api/v1/lenses/:id — get lens detail.
pub async fn get_lens(
    State(state): State<AppState>,
    Path(lens_id): Path<Uuid>,
    Extension(_auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    let lens = lens_queries::get_lens(&state.pool, lens_id)
        .await
        .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?
        .ok_or_else(|| AppError::NotFound("Lens".to_string()))?;

    Ok((StatusCode::OK, Json(lens)))
}

/// POST /api/v1/lenses — create a new lens.
pub async fn create_lens(
    State(state): State<AppState>,
    Json(body): Json<CreateLensBody>,
    Extension(auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    let lens = lens_queries::create_lens(
        &state.pool,
        auth_user.user_id,
        &body.name,
        body.description.as_deref(),
        body.filters,
        body.chart_config,
        body.is_public,
    )
    .await
    .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?;

    Ok((StatusCode::CREATED, Json(lens)))
}

/// PUT /api/v1/lenses/:id — update an existing lens.
pub async fn update_lens(
    State(state): State<AppState>,
    Path(lens_id): Path<Uuid>,
    Json(body): Json<UpdateLensBody>,
    Extension(auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    let lens = lens_queries::update_lens(
        &state.pool,
        lens_id,
        auth_user.user_id,
        body.name.as_deref(),
        body.description,
        body.filters,
        body.chart_config,
        body.is_public,
    )
    .await
    .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?
    .ok_or_else(|| AppError::NotFound("Lens".to_string()))?;

    Ok((StatusCode::OK, Json(lens)))
}

/// DELETE /api/v1/lenses/:id — delete a lens.
pub async fn delete_lens(
    State(state): State<AppState>,
    Path(lens_id): Path<Uuid>,
    Extension(auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    lens_queries::delete_lens(&state.pool, lens_id, auth_user.user_id)
        .await
        .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?;

    Ok((StatusCode::OK, Json(serde_json::json!({"status": "deleted"}))))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/", get(list_lenses).post(create_lens))
        .route("/{id}", get(get_lens).put(update_lens).delete(delete_lens))
}
