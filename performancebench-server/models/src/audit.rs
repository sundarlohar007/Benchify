use diesel::prelude::*;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

// ── Audit Event ──

#[derive(Debug, Clone, Serialize, Deserialize, Queryable, Selectable)]
#[diesel(table_name = crate::schema::audit_events)]
#[diesel(check_for_backend(diesel::pg::Pg))]
#[serde(rename_all = "camelCase")]
pub struct AuditEvent {
    pub id: Uuid,
    pub event_type: String,
    pub event_category: String,
    pub actor_id: Option<Uuid>,
    pub actor_email: Option<String>,
    pub target_type: Option<String>,
    pub target_id: Option<Uuid>,
    pub details: serde_json::Value,
    pub ip_address: Option<String>,
    pub user_agent: Option<String>,
    pub created_at: chrono::NaiveDateTime,
}

/// Insertable struct — id and created_at are DB defaults.
#[derive(Debug, Insertable)]
#[diesel(table_name = crate::schema::audit_events)]
pub struct CreateAuditEvent {
    pub event_type: String,
    pub event_category: String,
    pub actor_id: Option<Uuid>,
    pub actor_email: Option<String>,
    pub target_type: Option<String>,
    pub target_id: Option<Uuid>,
    pub details: serde_json::Value,
    pub ip_address: Option<String>,
    pub user_agent: Option<String>,
}

/// API response for audit event with actor display info (joinable from users).
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AuditEventResponse {
    pub id: Uuid,
    pub event_type: String,
    pub event_category: String,
    pub actor_id: Option<Uuid>,
    pub actor_email: Option<String>,
    pub target_type: Option<String>,
    pub target_id: Option<Uuid>,
    pub details: serde_json::Value,
    pub ip_address: Option<String>,
    pub user_agent: Option<String>,
    pub created_at: chrono::NaiveDateTime,
}

impl From<AuditEvent> for AuditEventResponse {
    fn from(e: AuditEvent) -> Self {
        Self {
            id: e.id,
            event_type: e.event_type,
            event_category: e.event_category,
            actor_id: e.actor_id,
            actor_email: e.actor_email,
            target_type: e.target_type,
            target_id: e.target_id,
            details: e.details,
            ip_address: e.ip_address,
            user_agent: e.user_agent,
            created_at: e.created_at,
        }
    }
}

impl From<&AuditEvent> for AuditEventResponse {
    fn from(e: &AuditEvent) -> Self {
        Self {
            id: e.id,
            event_type: e.event_type.clone(),
            event_category: e.event_category.clone(),
            actor_id: e.actor_id,
            actor_email: e.actor_email.clone(),
            target_type: e.target_type.clone(),
            target_id: e.target_id,
            details: e.details.clone(),
            ip_address: e.ip_address.clone(),
            user_agent: e.user_agent.clone(),
            created_at: e.created_at,
        }
    }
}

// ── Audit Event Taxonomy ──

/// Type-safe event type enum. Stored as snake_case string in DB.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AuditEventType {
    // Auth events
    Login,
    Logout,
    SsoLogin,
    TokenRefresh,
    TokenRevoked,
    PasswordChanged,
    // Session events
    SessionUploaded,
    SessionDeleted,
    SessionExported,
    JiraIssueCreated,
    // User events
    UserCreated,
    UserRoleChanged,
    UserDeactivated,
    UserActivated,
    // Config events
    SsoConfigCreated,
    SsoConfigUpdated,
    SsoConfigDeleted,
    SettingsChanged,
    // Team events
    OrgCreated,
    OrgUpdated,
    OrgDeleted,
    ProjectCreated,
    ProjectDeleted,
    MemberAdded,
    MemberRemoved,
    MemberRoleChanged,
    // Export events
    AuditExported,
    SessionDataExported,
    // System events
    RetentionPurge,
    ServerStartup,
    ServerShutdown,
}

/// Event category for filtering and grouping.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AuditEventCategory {
    Auth,
    Session,
    User,
    Config,
    Team,
    Export,
    System,
}

impl AuditEventType {
    /// Return the category this event type belongs to.
    pub fn category(&self) -> AuditEventCategory {
        match self {
            AuditEventType::Login
            | AuditEventType::Logout
            | AuditEventType::SsoLogin
            | AuditEventType::TokenRefresh
            | AuditEventType::TokenRevoked
            | AuditEventType::PasswordChanged => AuditEventCategory::Auth,
            AuditEventType::SessionUploaded
            | AuditEventType::SessionDeleted
            | AuditEventType::SessionExported
            | AuditEventType::JiraIssueCreated => AuditEventCategory::Session,
            AuditEventType::UserCreated
            | AuditEventType::UserRoleChanged
            | AuditEventType::UserDeactivated
            | AuditEventType::UserActivated => AuditEventCategory::User,
            AuditEventType::SsoConfigCreated
            | AuditEventType::SsoConfigUpdated
            | AuditEventType::SsoConfigDeleted
            | AuditEventType::SettingsChanged => AuditEventCategory::Config,
            AuditEventType::OrgCreated
            | AuditEventType::OrgUpdated
            | AuditEventType::OrgDeleted
            | AuditEventType::ProjectCreated
            | AuditEventType::ProjectDeleted
            | AuditEventType::MemberAdded
            | AuditEventType::MemberRemoved
            | AuditEventType::MemberRoleChanged => AuditEventCategory::Team,
            AuditEventType::AuditExported | AuditEventType::SessionDataExported => {
                AuditEventCategory::Export
            }
            AuditEventType::RetentionPurge
            | AuditEventType::ServerStartup
            | AuditEventType::ServerShutdown => AuditEventCategory::System,
        }
    }
}

impl std::fmt::Display for AuditEventType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let s = serde_json::to_string(self).unwrap_or_else(|_| String::from("unknown"));
        // Strip surrounding quotes from serde_json output
        let trimmed = s.trim_matches('"');
        write!(f, "{}", trimmed)
    }
}

impl std::fmt::Display for AuditEventCategory {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let s = serde_json::to_string(self).unwrap_or_else(|_| String::from("unknown"));
        let trimmed = s.trim_matches('"');
        write!(f, "{}", trimmed)
    }
}

impl From<&AuditEventType> for String {
    fn from(t: &AuditEventType) -> Self {
        t.to_string()
    }
}

impl From<&AuditEventCategory> for String {
    fn from(c: &AuditEventCategory) -> Self {
        c.to_string()
    }
}

// ── Tests ──

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_audit_event_type_display_is_snake_case() {
        assert_eq!(AuditEventType::SsoLogin.to_string(), "sso_login");
        assert_eq!(AuditEventType::Login.to_string(), "login");
        assert_eq!(
            AuditEventType::UserRoleChanged.to_string(),
            "user_role_changed"
        );
        assert_eq!(
            AuditEventType::SessionUploaded.to_string(),
            "session_uploaded"
        );
        assert_eq!(
            AuditEventType::RetentionPurge.to_string(),
            "retention_purge"
        );
    }

    #[test]
    fn test_audit_event_category_display_is_snake_case() {
        assert_eq!(AuditEventCategory::Auth.to_string(), "auth");
        assert_eq!(AuditEventCategory::Session.to_string(), "session");
        assert_eq!(AuditEventCategory::User.to_string(), "user");
        assert_eq!(AuditEventCategory::Config.to_string(), "config");
        assert_eq!(AuditEventCategory::Team.to_string(), "team");
        assert_eq!(AuditEventCategory::Export.to_string(), "export");
        assert_eq!(AuditEventCategory::System.to_string(), "system");
    }

    #[test]
    fn test_category_for_all_event_types() {
        // Verify every event type maps to the correct category
        assert_eq!(AuditEventType::Login.category(), AuditEventCategory::Auth);
        assert_eq!(AuditEventType::Logout.category(), AuditEventCategory::Auth);
        assert_eq!(
            AuditEventType::SsoLogin.category(),
            AuditEventCategory::Auth
        );
        assert_eq!(
            AuditEventType::TokenRefresh.category(),
            AuditEventCategory::Auth
        );
        assert_eq!(
            AuditEventType::TokenRevoked.category(),
            AuditEventCategory::Auth
        );
        assert_eq!(
            AuditEventType::PasswordChanged.category(),
            AuditEventCategory::Auth
        );

        assert_eq!(
            AuditEventType::SessionUploaded.category(),
            AuditEventCategory::Session
        );
        assert_eq!(
            AuditEventType::SessionDeleted.category(),
            AuditEventCategory::Session
        );
        assert_eq!(
            AuditEventType::SessionExported.category(),
            AuditEventCategory::Session
        );
        assert_eq!(
            AuditEventType::JiraIssueCreated.category(),
            AuditEventCategory::Session
        );

        assert_eq!(
            AuditEventType::UserCreated.category(),
            AuditEventCategory::User
        );
        assert_eq!(
            AuditEventType::UserRoleChanged.category(),
            AuditEventCategory::User
        );
        assert_eq!(
            AuditEventType::UserDeactivated.category(),
            AuditEventCategory::User
        );
        assert_eq!(
            AuditEventType::UserActivated.category(),
            AuditEventCategory::User
        );

        assert_eq!(
            AuditEventType::SsoConfigCreated.category(),
            AuditEventCategory::Config
        );
        assert_eq!(
            AuditEventType::SsoConfigUpdated.category(),
            AuditEventCategory::Config
        );
        assert_eq!(
            AuditEventType::SsoConfigDeleted.category(),
            AuditEventCategory::Config
        );
        assert_eq!(
            AuditEventType::SettingsChanged.category(),
            AuditEventCategory::Config
        );

        assert_eq!(
            AuditEventType::OrgCreated.category(),
            AuditEventCategory::Team
        );
        assert_eq!(
            AuditEventType::OrgUpdated.category(),
            AuditEventCategory::Team
        );
        assert_eq!(
            AuditEventType::OrgDeleted.category(),
            AuditEventCategory::Team
        );
        assert_eq!(
            AuditEventType::ProjectCreated.category(),
            AuditEventCategory::Team
        );
        assert_eq!(
            AuditEventType::ProjectDeleted.category(),
            AuditEventCategory::Team
        );
        assert_eq!(
            AuditEventType::MemberAdded.category(),
            AuditEventCategory::Team
        );
        assert_eq!(
            AuditEventType::MemberRemoved.category(),
            AuditEventCategory::Team
        );
        assert_eq!(
            AuditEventType::MemberRoleChanged.category(),
            AuditEventCategory::Team
        );

        assert_eq!(
            AuditEventType::AuditExported.category(),
            AuditEventCategory::Export
        );
        assert_eq!(
            AuditEventType::SessionDataExported.category(),
            AuditEventCategory::Export
        );

        assert_eq!(
            AuditEventType::RetentionPurge.category(),
            AuditEventCategory::System
        );
        assert_eq!(
            AuditEventType::ServerStartup.category(),
            AuditEventCategory::System
        );
        assert_eq!(
            AuditEventType::ServerShutdown.category(),
            AuditEventCategory::System
        );
    }

    #[test]
    fn test_audit_event_type_serde_roundtrip() {
        let variants = vec![
            AuditEventType::Login,
            AuditEventType::SsoLogin,
            AuditEventType::UserRoleChanged,
            AuditEventType::SessionUploaded,
            AuditEventType::RetentionPurge,
        ];
        for variant in variants {
            let json = serde_json::to_string(&variant).unwrap();
            let deserialized: AuditEventType = serde_json::from_str(&json).unwrap();
            assert_eq!(variant, deserialized, "Round-trip failed for: {}", json);
        }
    }

    #[test]
    fn test_audit_event_category_serde_roundtrip() {
        let categories = vec![
            AuditEventCategory::Auth,
            AuditEventCategory::Session,
            AuditEventCategory::User,
            AuditEventCategory::Config,
            AuditEventCategory::Team,
            AuditEventCategory::Export,
            AuditEventCategory::System,
        ];
        for cat in categories {
            let json = serde_json::to_string(&cat).unwrap();
            let deserialized: AuditEventCategory = serde_json::from_str(&json).unwrap();
            assert_eq!(cat, deserialized, "Round-trip failed for: {}", json);
        }
    }

    #[test]
    fn test_create_audit_event_structure() {
        let event = CreateAuditEvent {
            event_type: "login".to_string(),
            event_category: "auth".to_string(),
            actor_id: Some(Uuid::new_v4()),
            actor_email: Some("test@example.com".to_string()),
            target_type: None,
            target_id: None,
            details: serde_json::json!({"success": true}),
            ip_address: Some("127.0.0.1".to_string()),
            user_agent: Some("test-agent".to_string()),
        };
        assert_eq!(event.event_type, "login");
        assert_eq!(event.event_category, "auth");
        assert_eq!(event.details, serde_json::json!({"success": true}));
    }
}
