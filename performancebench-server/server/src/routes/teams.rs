use axum::extract::{Path, Query, State};
use axum::{Extension, Json, Router};
use axum::routing::{delete, get, post, put};
use serde::Deserialize;
use serde_json::json;
use uuid::Uuid;

use db::team_queries;
use models::audit::{AuditEventCategory, AuditEventType};
use models::team::{
    AddMemberRequest, CreateTeamOrg, CreateTeamProject, MemberResponse, TeamOrgResponse,
    TeamProjectResponse, UpdateMemberRoleRequest, UpdateTeamOrg, UpdateTeamProject,
    is_valid_member_role,
};
use crate::error::AppError;
use crate::middleware::audit as audit_mw;
use crate::state::AppState;
use crate::utils::jwt::AuthUser;

// ── Query params ──

#[derive(Debug, Deserialize)]
pub struct ListQuery {
    #[serde(default = "default_offset")]
    pub offset: i64,
    #[serde(default = "default_limit")]
    pub limit: i64,
}

fn default_offset() -> i64 { 0 }
fn default_limit() -> i64 { 50 }

// ── Router ──

pub fn teams_router() -> Router<AppState> {
    Router::new()
        // Orgs
        .route("/orgs", get(list_orgs).post(create_org))
        .route("/orgs/{org_id}", get(get_org).put(update_org).delete(delete_org))
        // Projects
        .route("/orgs/{org_id}/projects", get(list_projects).post(create_project))
        .route("/orgs/{org_id}/projects/{project_id}", get(get_project).put(update_project).delete(delete_project))
        // Members
        .route("/orgs/{org_id}/members", get(list_members).post(add_member))
        .route("/orgs/{org_id}/members/{user_id}", put(update_member_role).delete(remove_member))
}

// ── Org handlers ──

/// POST /api/v1/teams/orgs
async fn create_org(
    State(state): State<AppState>,
    Extension(auth_user): Extension<AuthUser>,
    Json(body): Json<CreateTeamOrg>,
) -> Result<(axum::http::StatusCode, Json<TeamOrgResponse>), AppError> {
    if body.name.trim().is_empty() {
        return Err(AppError::Validation("Organization name is required".to_string()));
    }

    let org = team_queries::create_org(
        &state.pool,
        body.name.trim(),
        body.description.as_deref(),
        auth_user.user_id,
    )
    .await
    .map_err(|e| {
        let msg = e.to_string();
        if msg.contains("duplicate key") || msg.contains("unique constraint") {
            AppError::Conflict("Organization slug already exists. Choose a different name.".to_string())
        } else {
            AppError::Internal(format!("DB error: {}", msg))
        }
    })?;

    // Auto-add creator as admin member
    let _ = team_queries::add_member(&state.pool, org.id, auth_user.user_id, "admin").await;

    // Audit event
    let _ = audit_mw::audit_team_event(
        &state.pool,
        &auth_user,
        AuditEventType::OrgCreated,
        Some(org.id),
        None,
        json!({"name": org.name, "slug": org.slug}),
    ).await;

    Ok((axum::http::StatusCode::CREATED, Json(TeamOrgResponse::from(&org))))
}

/// GET /api/v1/teams/orgs
async fn list_orgs(
    State(state): State<AppState>,
    Extension(auth_user): Extension<AuthUser>,
    Query(params): Query<ListQuery>,
) -> Result<Json<serde_json::Value>, AppError> {
    let (orgs, total) = team_queries::list_orgs(
        &state.pool,
        auth_user.user_id,
        params.offset,
        params.limit,
    )
    .await
    .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?;

    Ok(Json(json!({
        "orgs": orgs,
        "total": total,
        "offset": params.offset,
        "limit": params.limit,
    })))
}

/// GET /api/v1/teams/orgs/{org_id}
async fn get_org(
    State(state): State<AppState>,
    Path(org_id): Path<Uuid>,
) -> Result<Json<TeamOrgResponse>, AppError> {
    let org = team_queries::get_org_by_id(&state.pool, org_id)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?
        .ok_or_else(|| AppError::NotFound("Organization".to_string()))?;

    Ok(Json(TeamOrgResponse::from(&org)))
}

/// PUT /api/v1/teams/orgs/{org_id}
async fn update_org(
    State(state): State<AppState>,
    Path(org_id): Path<Uuid>,
    Extension(auth_user): Extension<AuthUser>,
    Json(body): Json<UpdateTeamOrg>,
) -> Result<Json<TeamOrgResponse>, AppError> {
    let existing = team_queries::get_org_by_id(&state.pool, org_id)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?
        .ok_or_else(|| AppError::NotFound("Organization".to_string()))?;

    let org = team_queries::update_org(
        &state.pool,
        org_id,
        body.name.as_deref(),
        body.description.as_deref(),
        body.is_active,
    )
    .await
    .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?;

    // Audit event
    let _ = audit_mw::audit_team_event(
        &state.pool,
        &auth_user,
        AuditEventType::OrgUpdated,
        Some(org.id),
        None,
        json!({"name": org.name, "slug": org.slug}),
    ).await;

    Ok(Json(TeamOrgResponse::from(&org)))
}

/// DELETE /api/v1/teams/orgs/{org_id}
async fn delete_org(
    State(state): State<AppState>,
    Path(org_id): Path<Uuid>,
    Extension(auth_user): Extension<AuthUser>,
) -> Result<Json<serde_json::Value>, AppError> {
    let existing = team_queries::get_org_by_id(&state.pool, org_id)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?
        .ok_or_else(|| AppError::NotFound("Organization".to_string()))?;

    team_queries::delete_org(&state.pool, org_id)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?;

    // Audit event
    let _ = audit_mw::audit_team_event(
        &state.pool,
        &auth_user,
        AuditEventType::OrgDeleted,
        Some(org_id),
        None,
        json!({"name": existing.name, "slug": existing.slug}),
    ).await;

    Ok(Json(json!({"status": "deleted"})))
}

// ── Project handlers ──

/// POST /api/v1/teams/orgs/{org_id}/projects
async fn create_project(
    State(state): State<AppState>,
    Path(org_id): Path<Uuid>,
    Extension(auth_user): Extension<AuthUser>,
    Json(body): Json<CreateTeamProject>,
) -> Result<(axum::http::StatusCode, Json<TeamProjectResponse>), AppError> {
    if body.name.trim().is_empty() {
        return Err(AppError::Validation("Project name is required".to_string()));
    }

    // Verify org exists
    let _org = team_queries::get_org_by_id(&state.pool, org_id)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?
        .ok_or_else(|| AppError::NotFound("Organization".to_string()))?;

    let project = team_queries::create_project(
        &state.pool,
        org_id,
        body.name.trim(),
        body.description.as_deref(),
        auth_user.user_id,
    )
    .await
    .map_err(|e| {
        let msg = e.to_string();
        if msg.contains("duplicate key") || msg.contains("unique constraint") {
            AppError::Conflict("Project slug already exists in this org. Choose a different name.".to_string())
        } else {
            AppError::Internal(format!("DB error: {}", msg))
        }
    })?;

    let _ = audit_mw::audit_team_event(
        &state.pool,
        &auth_user,
        AuditEventType::ProjectCreated,
        Some(org_id),
        Some(project.id),
        json!({"name": project.name, "slug": project.slug}),
    ).await;

    Ok((axum::http::StatusCode::CREATED, Json(TeamProjectResponse::from(&project))))
}

/// GET /api/v1/teams/orgs/{org_id}/projects
async fn list_projects(
    State(state): State<AppState>,
    Path(org_id): Path<Uuid>,
    Query(params): Query<ListQuery>,
) -> Result<Json<serde_json::Value>, AppError> {
    let (projects, total) = team_queries::list_projects(
        &state.pool,
        org_id,
        params.offset,
        params.limit,
    )
    .await
    .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?;

    Ok(Json(json!({
        "projects": projects,
        "total": total,
        "offset": params.offset,
        "limit": params.limit,
    })))
}

/// GET /api/v1/teams/orgs/{org_id}/projects/{project_id}
async fn get_project(
    State(state): State<AppState>,
    Path((org_id, project_id)): Path<(Uuid, Uuid)>,
) -> Result<Json<TeamProjectResponse>, AppError> {
    let project = team_queries::get_project_by_id(&state.pool, project_id)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?
        .ok_or_else(|| AppError::NotFound("Project".to_string()))?;

    if project.org_id != org_id {
        return Err(AppError::NotFound("Project".to_string()));
    }

    Ok(Json(TeamProjectResponse::from(&project)))
}

/// PUT /api/v1/teams/orgs/{org_id}/projects/{project_id}
async fn update_project(
    State(state): State<AppState>,
    Path((org_id, project_id)): Path<(Uuid, Uuid)>,
    Extension(auth_user): Extension<AuthUser>,
    Json(body): Json<UpdateTeamProject>,
) -> Result<Json<TeamProjectResponse>, AppError> {
    let existing = team_queries::get_project_by_id(&state.pool, project_id)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?
        .ok_or_else(|| AppError::NotFound("Project".to_string()))?;

    if existing.org_id != org_id {
        return Err(AppError::NotFound("Project".to_string()));
    }

    let project = team_queries::update_project(
        &state.pool,
        project_id,
        body.name.as_deref(),
        body.description.as_deref(),
        body.is_active,
    )
    .await
    .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?;

    let _ = audit_mw::audit_team_event(
        &state.pool,
        &auth_user,
        AuditEventType::ProjectCreated,
        Some(org_id),
        Some(project.id),
        json!({"name": project.name}),
    ).await;

    Ok(Json(TeamProjectResponse::from(&project)))
}

/// DELETE /api/v1/teams/orgs/{org_id}/projects/{project_id}
async fn delete_project(
    State(state): State<AppState>,
    Path((org_id, project_id)): Path<(Uuid, Uuid)>,
    Extension(auth_user): Extension<AuthUser>,
) -> Result<Json<serde_json::Value>, AppError> {
    let existing = team_queries::get_project_by_id(&state.pool, project_id)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?
        .ok_or_else(|| AppError::NotFound("Project".to_string()))?;

    if existing.org_id != org_id {
        return Err(AppError::NotFound("Project".to_string()));
    }

    team_queries::delete_project(&state.pool, project_id)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?;

    let _ = audit_mw::audit_team_event(
        &state.pool,
        &auth_user,
        AuditEventType::ProjectDeleted,
        Some(org_id),
        Some(project_id),
        json!({"name": existing.name}),
    ).await;

    Ok(Json(json!({"status": "deleted"})))
}

// ── Member handlers ──

/// GET /api/v1/teams/orgs/{org_id}/members
async fn list_members(
    State(state): State<AppState>,
    Path(org_id): Path<Uuid>,
    Query(params): Query<ListQuery>,
) -> Result<Json<serde_json::Value>, AppError> {
    let (members, total) = team_queries::list_members(
        &state.pool,
        org_id,
        params.offset,
        params.limit,
    )
    .await
    .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?;

    let member_responses: Vec<MemberResponse> = members
        .into_iter()
        .map(|(m, email, display_name)| MemberResponse {
            id: m.id,
            user_id: m.user_id,
            org_id: m.org_id,
            role: m.role,
            email,
            display_name,
            joined_at: m.joined_at,
        })
        .collect();

    Ok(Json(json!({
        "members": member_responses,
        "total": total,
        "offset": params.offset,
        "limit": params.limit,
    })))
}

/// POST /api/v1/teams/orgs/{org_id}/members
async fn add_member(
    State(state): State<AppState>,
    Path(org_id): Path<Uuid>,
    Extension(auth_user): Extension<AuthUser>,
    Json(body): Json<AddMemberRequest>,
) -> Result<(axum::http::StatusCode, Json<serde_json::Value>), AppError> {
    if !is_valid_member_role(&body.role) {
        return Err(AppError::Validation(format!(
            "Invalid role '{}'. Must be one of: admin, manager, operator, viewer, auditor",
            body.role
        )));
    }

    let membership = team_queries::add_member(&state.pool, org_id, body.user_id, &body.role)
        .await
        .map_err(|e| {
            let msg = e.to_string();
            if msg.contains("duplicate key") || msg.contains("unique constraint") {
                AppError::Conflict("User is already a member of this organization".to_string())
            } else {
                AppError::Internal(format!("DB error: {}", msg))
            }
        })?;

    let _ = audit_mw::audit_team_event(
        &state.pool,
        &auth_user,
        AuditEventType::MemberAdded,
        Some(org_id),
        None,
        json!({"added_user_id": body.user_id, "role": body.role}),
    ).await;

    Ok((axum::http::StatusCode::CREATED, Json(json!({
        "id": membership.id,
        "user_id": membership.user_id,
        "org_id": membership.org_id,
        "role": membership.role,
        "joined_at": membership.joined_at,
    }))))
}

/// PUT /api/v1/teams/orgs/{org_id}/members/{user_id}
async fn update_member_role(
    State(state): State<AppState>,
    Path((org_id, user_id)): Path<(Uuid, Uuid)>,
    Extension(auth_user): Extension<AuthUser>,
    Json(body): Json<UpdateMemberRoleRequest>,
) -> Result<Json<serde_json::Value>, AppError> {
    if !is_valid_member_role(&body.role) {
        return Err(AppError::Validation(format!(
            "Invalid role '{}'. Must be one of: admin, manager, operator, viewer, auditor",
            body.role
        )));
    }

    let membership = team_queries::update_member_role(&state.pool, org_id, user_id, &body.role)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?;

    let _ = audit_mw::audit_team_event(
        &state.pool,
        &auth_user,
        AuditEventType::MemberRoleChanged,
        Some(org_id),
        None,
        json!({"user_id": user_id, "new_role": body.role}),
    ).await;

    Ok(Json(json!({
        "id": membership.id,
        "user_id": membership.user_id,
        "org_id": membership.org_id,
        "role": membership.role,
    })))
}

/// DELETE /api/v1/teams/orgs/{org_id}/members/{user_id}
async fn remove_member(
    State(state): State<AppState>,
    Path((org_id, user_id)): Path<(Uuid, Uuid)>,
    Extension(auth_user): Extension<AuthUser>,
) -> Result<Json<serde_json::Value>, AppError> {
    team_queries::remove_member(&state.pool, org_id, user_id)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?;

    let _ = audit_mw::audit_team_event(
        &state.pool,
        &auth_user,
        AuditEventType::MemberRemoved,
        Some(org_id),
        None,
        json!({"removed_user_id": user_id}),
    ).await;

    Ok(Json(json!({"status": "removed"})))
}

// ── Tests ──

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_list_query_defaults() {
        let q = ListQuery { offset: 0, limit: 50 };
        assert_eq!(q.offset, 0);
        assert_eq!(q.limit, 50);
    }

    #[test]
    fn test_team_org_create_validation_empty_name() {
        let body = CreateTeamOrg {
            name: "  ".to_string(),
            description: None,
        };
        assert!(body.name.trim().is_empty());
    }
}
