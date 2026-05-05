use axum::extract::{Path, Query, State};
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::{Extension, Json, Router};
use axum::routing::{delete, get, post, put};
use serde::Deserialize;
use uuid::Uuid;

use db::alert_queries;
use crate::error::AppError;
use crate::state::AppState;
use crate::utils::jwt::AuthUser;

// ── Alert Rules ──

#[derive(Debug, Deserialize)]
pub struct CreateAlertRuleBody {
    pub name: String,
    pub metric_name: String,
    pub condition: String,
    pub threshold: f64,
    #[serde(default = "default_duration_seconds")]
    pub duration_seconds: i32,
    #[serde(default)]
    pub channels: serde_json::Value,
}

fn default_duration_seconds() -> i32 {
    30
}

#[derive(Debug, Deserialize)]
pub struct UpdateAlertRuleBody {
    pub name: Option<String>,
    pub metric_name: Option<String>,
    pub condition: Option<String>,
    pub threshold: Option<f64>,
    pub duration_seconds: Option<i32>,
    pub channels: Option<serde_json::Value>,
    pub is_active: Option<bool>,
}

/// GET /api/v1/alerts/rules — list alert rules for user.
pub async fn list_alert_rules(
    State(state): State<AppState>,
    Extension(auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    let rules = alert_queries::list_alert_rules(&state.pool, auth_user.user_id)
        .await
        .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?;

    Ok((StatusCode::OK, Json(serde_json::json!({ "data": rules }))))
}

/// POST /api/v1/alerts/rules — create a new alert rule.
pub async fn create_alert_rule(
    State(state): State<AppState>,
    Json(body): Json<CreateAlertRuleBody>,
    Extension(auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    let rule = alert_queries::create_alert_rule(
        &state.pool,
        auth_user.user_id,
        &body.name,
        &body.metric_name,
        &body.condition,
        body.threshold,
        body.duration_seconds,
        body.channels,
    )
    .await
    .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?;

    Ok((StatusCode::CREATED, Json(rule)))
}

/// PUT /api/v1/alerts/rules/:id — update an alert rule.
pub async fn update_alert_rule(
    State(state): State<AppState>,
    Path(rule_id): Path<Uuid>,
    Json(body): Json<UpdateAlertRuleBody>,
    Extension(auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    let rule = alert_queries::update_alert_rule(
        &state.pool,
        rule_id,
        auth_user.user_id,
        body.name.as_deref(),
        body.metric_name.as_deref(),
        body.condition.as_deref(),
        body.threshold,
        body.duration_seconds,
        body.channels,
        body.is_active,
    )
    .await
    .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?
    .ok_or_else(|| AppError::NotFound("AlertRule".to_string()))?;

    Ok((StatusCode::OK, Json(rule)))
}

/// DELETE /api/v1/alerts/rules/:id — delete an alert rule.
pub async fn delete_alert_rule(
    State(state): State<AppState>,
    Path(rule_id): Path<Uuid>,
    Extension(auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    alert_queries::delete_alert_rule(&state.pool, rule_id, auth_user.user_id)
        .await
        .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?;

    Ok((StatusCode::OK, Json(serde_json::json!({"status": "deleted"}))))
}

// ── Alert Events ──

#[derive(Debug, Deserialize)]
pub struct ListAlertEventsQuery {
    pub rule_id: Option<Uuid>,
    pub session_id: Option<Uuid>,
    pub severity: Option<String>,
    #[serde(default = "default_limit")]
    pub limit: i64,
    #[serde(default = "default_offset")]
    pub offset: i64,
}

fn default_limit() -> i64 {
    50
}
fn default_offset() -> i64 {
    0
}

/// GET /api/v1/alerts/events — list alert events with filters.
pub async fn list_alert_events(
    State(state): State<AppState>,
    Query(params): Query<ListAlertEventsQuery>,
    Extension(_auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    let events = alert_queries::list_alert_events(
        &state.pool,
        params.rule_id,
        params.session_id,
        params.severity.as_deref(),
        params.limit,
        params.offset,
    )
    .await
    .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?;

    Ok((StatusCode::OK, Json(serde_json::json!({ "data": events }))))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/rules", get(list_alert_rules).post(create_alert_rule))
        .route("/rules/{id}", put(update_alert_rule).delete(delete_alert_rule))
        .route("/events", get(list_alert_events))
}
