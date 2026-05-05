use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::{Extension, Json, Router};
use axum::routing::{delete, get, post, put};
use serde::Deserialize;
use uuid::Uuid;

use crate::error::AppError;
use crate::state::AppState;
use crate::utils::jwt::AuthUser;

#[derive(Debug, Deserialize)]
pub struct CreateWebhookBody {
    pub name: String,
    pub url: String,
    pub secret: Option<String>,
    #[serde(default = "default_events")]
    pub events: Vec<String>,
}

fn default_events() -> Vec<String> {
    vec!["session_end".to_string(), "alert_fired".to_string()]
}

#[derive(Debug, Deserialize)]
pub struct UpdateWebhookBody {
    pub name: Option<String>,
    pub url: Option<String>,
    pub secret: Option<Option<String>>,
    pub events: Option<Vec<String>>,
    pub is_active: Option<bool>,
}

/// GET /api/v1/webhooks — list webhook configs for user.
pub async fn list_webhooks(
    State(state): State<AppState>,
    Extension(_auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    let _ = state;
    Ok((StatusCode::OK, Json(serde_json::json!({ "data": [] }))))
}

/// POST /api/v1/webhooks — create a new webhook config.
pub async fn create_webhook(
    State(_state): State<AppState>,
    Json(body): Json<CreateWebhookBody>,
    Extension(_auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    let new_id = Uuid::new_v4();
    Ok((
        StatusCode::CREATED,
        Json(serde_json::json!({
            "id": new_id,
            "name": body.name,
            "url": body.url,
            "events": body.events,
            "is_active": true,
        })),
    ))
}

/// PUT /api/v1/webhooks/:id — update a webhook config.
pub async fn update_webhook(
    State(_state): State<AppState>,
    Path(webhook_id): Path<Uuid>,
    Json(_body): Json<UpdateWebhookBody>,
    Extension(_auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    Ok((
        StatusCode::OK,
        Json(serde_json::json!({
            "id": webhook_id,
            "status": "updated",
        })),
    ))
}

/// DELETE /api/v1/webhooks/:id — delete a webhook config.
pub async fn delete_webhook(
    State(_state): State<AppState>,
    Path(webhook_id): Path<Uuid>,
    Extension(_auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    Ok((
        StatusCode::OK,
        Json(serde_json::json!({
            "id": webhook_id,
            "status": "deleted",
        })),
    ))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/", get(list_webhooks).post(create_webhook))
        .route("/{id}", put(update_webhook).delete(delete_webhook))
}
