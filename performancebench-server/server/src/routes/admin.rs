use axum::extract::{Path, Query, State};
use axum::routing::{delete, get, post, put};
use axum::{Extension, Json, Router};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::error::AppError;
use crate::middleware::audit as audit_mw;
use crate::state::AppState;
use crate::utils::jwt::AuthUser;
use db::{sso_queries, user_queries};
use models::audit::{AuditEventCategory, AuditEventType};
use models::sso::SsoConfig;

// ── Request / Response types ──

#[derive(Debug, Deserialize)]
pub struct ListUsersQuery {
    #[serde(default)]
    pub role: Option<String>,
    #[serde(default = "default_offset")]
    pub offset: i64,
    #[serde(default = "default_limit")]
    pub limit: i64,
}

fn default_offset() -> i64 {
    0
}
fn default_limit() -> i64 {
    50
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateRoleRequest {
    pub role: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateStatusRequest {
    pub is_active: bool,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct UserListResponse {
    pub users: Vec<UserDetail>,
    pub total: i64,
}

/// Full user detail for admin view (includes SSO info).
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct UserDetail {
    pub id: Uuid,
    pub email: String,
    pub display_name: Option<String>,
    pub role: String,
    pub is_active: bool,
    pub auth_source: String,
    pub sso_provider: Option<String>,
    pub created_at: chrono::NaiveDateTime,
    pub updated_at: chrono::NaiveDateTime,
}

impl From<&models::user::User> for UserDetail {
    fn from(u: &models::user::User) -> Self {
        Self {
            id: u.id,
            email: u.email.clone(),
            display_name: u.display_name.clone(),
            role: u.role.clone(),
            is_active: u.is_active,
            auth_source: u.auth_source.clone(),
            sso_provider: u.sso_provider.clone(),
            created_at: u.created_at,
            updated_at: u.updated_at,
        }
    }
}

// ── SSO Config types ──

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateSsoConfigRequest {
    pub provider_type: String,
    pub name: String,
    pub config: serde_json::Value,
    pub is_active: Option<bool>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateSsoConfigRequest {
    pub name: Option<String>,
    pub config: Option<serde_json::Value>,
    pub is_active: Option<bool>,
}

// ── Router ──

pub fn admin_router() -> Router<AppState> {
    Router::new()
        .route("/users", get(list_users))
        .route("/users/{id}", get(get_user))
        .route("/users/{id}/role", put(update_user_role))
        .route("/users/{id}/status", put(update_user_status))
        .route(
            "/sso-configs",
            get(list_sso_configs).post(create_sso_config),
        )
        .route(
            "/sso-configs/{id}",
            put(update_sso_config).delete(delete_sso_config),
        )
}

// ── Handlers ──

/// GET /api/v1/admin/users?role={role}&offset={offset}&limit={limit}
async fn list_users(
    State(state): State<AppState>,
    Query(params): Query<ListUsersQuery>,
) -> Result<Json<UserListResponse>, AppError> {
    let (users, total) = user_queries::list_users_filtered(
        &state.pool,
        params.role.as_deref(),
        params.offset,
        params.limit,
    )
    .await
    .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?;

    let user_details: Vec<UserDetail> = users.iter().map(UserDetail::from).collect();

    Ok(Json(UserListResponse {
        users: user_details,
        total,
    }))
}

/// GET /api/v1/admin/users/{id}
async fn get_user(
    State(state): State<AppState>,
    Path(user_id): Path<Uuid>,
) -> Result<Json<UserDetail>, AppError> {
    let user = user_queries::get_user_by_id(&state.pool, user_id)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?
        .ok_or(AppError::NotFound("User".to_string()))?;

    Ok(Json(UserDetail::from(&user)))
}

/// PUT /api/v1/admin/users/{id}/role
async fn update_user_role(
    State(state): State<AppState>,
    Path(user_id): Path<Uuid>,
    axum::extract::Extension(auth_user): axum::extract::Extension<AuthUser>,
    Json(body): Json<UpdateRoleRequest>,
) -> Result<Json<UserDetail>, AppError> {
    // Validate role string
    let valid_roles = ["admin", "manager", "operator", "viewer", "auditor"];
    if !valid_roles.contains(&body.role.as_str()) {
        return Err(AppError::Validation(format!(
            "Invalid role '{}'. Must be one of: {}",
            body.role,
            valid_roles.join(", ")
        )));
    }

    // Prevent self-demotion from admin
    if user_id == auth_user.user_id && body.role != "admin" {
        return Err(AppError::Validation(
            "Cannot demote yourself below admin role".to_string(),
        ));
    }

    // Get current role for audit
    let existing_user = user_queries::get_user_by_id(&state.pool, user_id)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?
        .ok_or(AppError::NotFound("User".to_string()))?;
    let old_role = existing_user.role.clone();

    let user = user_queries::update_user_role(&state.pool, user_id, &body.role)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?;

    // Audit role change
    let _ = audit_mw::audit_user_event(
        &state.pool,
        &auth_user,
        AuditEventType::UserRoleChanged,
        user_id,
        serde_json::json!({"old_role": old_role, "new_role": body.role}),
    )
    .await;

    Ok(Json(UserDetail::from(&user)))
}

/// PUT /api/v1/admin/users/{id}/status
async fn update_user_status(
    State(state): State<AppState>,
    Path(user_id): Path<Uuid>,
    axum::extract::Extension(auth_user): axum::extract::Extension<AuthUser>,
    Json(body): Json<UpdateStatusRequest>,
) -> Result<Json<UserDetail>, AppError> {
    // Prevent self-deactivation
    if user_id == auth_user.user_id && !body.is_active {
        return Err(AppError::Validation(
            "Cannot deactivate your own account".to_string(),
        ));
    }

    let user = user_queries::update_user_status(&state.pool, user_id, body.is_active)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?;

    // Audit user activation/deactivation
    let event_type = if body.is_active {
        AuditEventType::UserActivated
    } else {
        AuditEventType::UserDeactivated
    };
    let _ = audit_mw::audit_user_event(
        &state.pool,
        &auth_user,
        event_type,
        user_id,
        serde_json::json!({"is_active": body.is_active}),
    )
    .await;

    Ok(Json(UserDetail::from(&user)))
}

// ── SSO Config CRUD Handlers ──

/// GET /api/v1/admin/sso-configs — list all SSO configs (active and inactive).
async fn list_sso_configs(State(state): State<AppState>) -> Result<Json<Vec<SsoConfig>>, AppError> {
    let configs = sso_queries::list_all_sso_configs(&state.pool)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?;
    Ok(Json(configs))
}

/// POST /api/v1/admin/sso-configs — create a new SSO provider config.
async fn create_sso_config(
    State(state): State<AppState>,
    Extension(auth_user): Extension<AuthUser>,
    Json(body): Json<CreateSsoConfigRequest>,
) -> Result<Json<SsoConfig>, AppError> {
    let valid_types = ["oidc", "saml", "ldap"];
    if !valid_types.contains(&body.provider_type.as_str()) {
        return Err(AppError::Validation(format!(
            "Invalid provider_type '{}'. Must be one of: oidc, saml, ldap",
            body.provider_type
        )));
    }

    let config = sso_queries::create_sso_config(
        &state.pool,
        &body.provider_type,
        &body.name,
        body.config.clone(),
    )
    .await
    .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?;

    // Audit SSO config creation
    let _ = audit_mw::audit_config_event(
        &state.pool,
        &auth_user,
        AuditEventType::SsoConfigCreated,
        &body.provider_type,
        Some(config.id),
        serde_json::json!({"name": body.name, "provider_type": body.provider_type}),
    )
    .await;

    Ok(Json(config))
}

/// PUT /api/v1/admin/sso-configs/{id} — update an SSO provider config.
async fn update_sso_config(
    State(state): State<AppState>,
    Path(config_id): Path<Uuid>,
    Extension(auth_user): Extension<AuthUser>,
    Json(body): Json<UpdateSsoConfigRequest>,
) -> Result<Json<SsoConfig>, AppError> {
    let input = models::sso::UpdateSsoConfig {
        name: body.name,
        config: body.config,
        is_active: body.is_active,
    };

    let config = sso_queries::update_sso_config(&state.pool, config_id, &input)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?;

    // Audit SSO config update
    let _ = audit_mw::audit_config_event(
        &state.pool,
        &auth_user,
        AuditEventType::SsoConfigUpdated,
        &config.provider_type,
        Some(config_id),
        serde_json::json!({"updated_fields": serde_json::to_value(&input).unwrap_or_default()}),
    )
    .await;

    Ok(Json(config))
}

/// DELETE /api/v1/admin/sso-configs/{id} — delete an SSO provider config.
async fn delete_sso_config(
    State(state): State<AppState>,
    Path(config_id): Path<Uuid>,
    Extension(auth_user): Extension<AuthUser>,
) -> Result<Json<serde_json::Value>, AppError> {
    // Get config before deleting for audit
    let existing = sso_queries::get_sso_config_by_id(&state.pool, config_id)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?
        .ok_or(AppError::NotFound("SSO config".to_string()))?;

    sso_queries::delete_sso_config(&state.pool, config_id)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?;

    // Audit SSO config deletion
    let _ = audit_mw::audit_config_event(
        &state.pool,
        &auth_user,
        AuditEventType::SsoConfigDeleted,
        &existing.provider_type,
        Some(config_id),
        serde_json::json!({"name": existing.name, "provider_type": existing.provider_type}),
    )
    .await;

    Ok(Json(serde_json::json!({"status": "deleted"})))
}
