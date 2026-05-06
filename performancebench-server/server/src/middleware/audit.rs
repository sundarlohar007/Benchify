use db::audit_queries;
use db::connection::DbPool;
use models::audit::{AuditEventCategory, AuditEventType, CreateAuditEvent};
use uuid::Uuid;

use crate::utils::jwt::AuthUser;

/// Record an audit event in the database. Fire-and-forget: if the insert fails,
/// logs a warning via tracing but does NOT propagate the error.
///
/// This ensures audit logging failures never break business operations (T-06-09).
pub async fn record_audit_event(
    pool: &DbPool,
    actor: Option<&AuthUser>,
    event_type: AuditEventType,
    category: AuditEventCategory,
    target_type: Option<&str>,
    target_id: Option<Uuid>,
    details: serde_json::Value,
) {
    let event = CreateAuditEvent {
        event_type: event_type.to_string(),
        event_category: category.to_string(),
        actor_id: actor.map(|a| a.user_id),
        actor_email: actor.map(|a| a.email.clone()),
        target_type: target_type.map(|s| s.to_string()),
        target_id,
        details,
        ip_address: None,
        user_agent: None,
    };

    // Fire-and-forget: if the audit insert fails, log a warning but don't fail the request
    if let Err(e) = audit_queries::insert_audit_event(pool, event).await {
        tracing::warn!(
            error = %e,
            event_type = %event_type,
            "Failed to insert audit event — audit log may be incomplete"
        );
    }
}

// ── Convenience helpers for common events ──

/// Record an authentication event (login, logout, token operations).
pub async fn audit_auth_event(
    pool: &DbPool,
    actor: Option<&AuthUser>,
    event_type: AuditEventType,
    success: bool,
) {
    record_audit_event(
        pool,
        actor,
        event_type,
        AuditEventCategory::Auth,
        None,
        None,
        serde_json::json!({"success": success}),
    )
    .await;
}

/// Record a session event (upload, delete, export).
pub async fn audit_session_event(
    pool: &DbPool,
    actor: &AuthUser,
    event_type: AuditEventType,
    session_id: Uuid,
    extra_details: Option<serde_json::Value>,
) {
    let mut details = serde_json::json!({"session_id": session_id.to_string()});
    if let Some(extra) = extra_details {
        if let serde_json::Value::Object(ref mut map) = details {
            if let serde_json::Value::Object(extra_map) = extra {
                for (k, v) in extra_map {
                    map.insert(k, v);
                }
            }
        }
    }
    record_audit_event(
        pool,
        Some(actor),
        event_type,
        AuditEventCategory::Session,
        Some("session"),
        Some(session_id),
        details,
    )
    .await;
}

/// Record a user management event (role change, activation/deactivation).
pub async fn audit_user_event(
    pool: &DbPool,
    actor: &AuthUser,
    event_type: AuditEventType,
    target_user_id: Uuid,
    details: serde_json::Value,
) {
    record_audit_event(
        pool,
        Some(actor),
        event_type,
        AuditEventCategory::User,
        Some("user"),
        Some(target_user_id),
        details,
    )
    .await;
}

/// Record a config/settings event (SSO config changes, server settings).
pub async fn audit_config_event(
    pool: &DbPool,
    actor: &AuthUser,
    event_type: AuditEventType,
    config_type: &str,
    config_id: Option<Uuid>,
    details: serde_json::Value,
) {
    record_audit_event(
        pool,
        Some(actor),
        event_type,
        AuditEventCategory::Config,
        Some(config_type),
        config_id,
        details,
    )
    .await;
}

/// Record a team event (org/project/member changes).
pub async fn audit_team_event(
    pool: &DbPool,
    actor: &AuthUser,
    event_type: AuditEventType,
    org_id: Option<Uuid>,
    project_id: Option<Uuid>,
    details: serde_json::Value,
) {
    record_audit_event(
        pool,
        Some(actor),
        event_type,
        AuditEventCategory::Team,
        Some("team"),
        org_id,
        details,
    )
    .await;
    let _ = project_id; // Included for API clarity, stored in details
}

/// Record a system event (purge, startup, shutdown).
pub async fn audit_system_event(
    pool: &DbPool,
    event_type: AuditEventType,
    details: serde_json::Value,
) {
    record_audit_event(
        pool,
        None,
        event_type,
        AuditEventCategory::System,
        None,
        None,
        details,
    )
    .await;
}

// ── Tests ──

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_event_type_to_string_matches_category() {
        // Verify that event types serialize to the expected strings
        let event = AuditEventType::Login;
        assert_eq!(event.to_string(), "login");
        assert_eq!(event.category(), AuditEventCategory::Auth);

        let event = AuditEventType::SessionUploaded;
        assert_eq!(event.to_string(), "session_uploaded");
        assert_eq!(event.category(), AuditEventCategory::Session);

        let event = AuditEventType::UserRoleChanged;
        assert_eq!(event.to_string(), "user_role_changed");
        assert_eq!(event.category(), AuditEventCategory::User);
    }

    #[test]
    fn test_create_audit_event_builder_pattern() {
        let auth_user = AuthUser {
            user_id: Uuid::new_v4(),
            email: "test@example.com".to_string(),
            role: "admin".to_string(),
        };

        let event = CreateAuditEvent {
            event_type: AuditEventType::Login.to_string(),
            event_category: AuditEventCategory::Auth.to_string(),
            actor_id: Some(auth_user.user_id),
            actor_email: Some(auth_user.email.clone()),
            target_type: None,
            target_id: None,
            details: serde_json::json!({"success": true}),
            ip_address: None,
            user_agent: None,
        };

        assert_eq!(event.event_type, "login");
        assert_eq!(event.actor_email, Some("test@example.com".to_string()));
    }
}
