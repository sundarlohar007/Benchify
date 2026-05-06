use diesel::prelude::*;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

// ── Team Organization ──

#[derive(Debug, Clone, Serialize, Deserialize, Queryable, Selectable)]
#[diesel(table_name = crate::schema::team_orgs)]
#[diesel(check_for_backend(diesel::pg::Pg))]
#[serde(rename_all = "camelCase")]
pub struct TeamOrg {
    pub id: Uuid,
    pub name: String,
    pub slug: String,
    pub description: Option<String>,
    pub is_active: bool,
    pub settings: serde_json::Value,
    pub created_by: Uuid,
    pub created_at: chrono::NaiveDateTime,
    pub updated_at: chrono::NaiveDateTime,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateTeamOrg {
    pub name: String,
    pub description: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateTeamOrg {
    pub name: Option<String>,
    pub description: Option<String>,
    pub is_active: Option<bool>,
}

// ── Team Project ──

#[derive(Debug, Clone, Serialize, Deserialize, Queryable, Selectable)]
#[diesel(table_name = crate::schema::team_projects)]
#[diesel(check_for_backend(diesel::pg::Pg))]
#[serde(rename_all = "camelCase")]
pub struct TeamProject {
    pub id: Uuid,
    pub org_id: Uuid,
    pub name: String,
    pub slug: String,
    pub description: Option<String>,
    pub is_active: bool,
    pub created_by: Uuid,
    pub created_at: chrono::NaiveDateTime,
    pub updated_at: chrono::NaiveDateTime,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateTeamProject {
    pub name: String,
    pub description: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateTeamProject {
    pub name: Option<String>,
    pub description: Option<String>,
    pub is_active: Option<bool>,
}

// ── Team Membership ──

#[derive(Debug, Clone, Serialize, Deserialize, Queryable, Selectable)]
#[diesel(table_name = crate::schema::team_membership)]
#[diesel(check_for_backend(diesel::pg::Pg))]
#[serde(rename_all = "camelCase")]
pub struct TeamMembership {
    pub id: Uuid,
    pub user_id: Uuid,
    pub org_id: Uuid,
    pub role: String,
    pub joined_at: chrono::NaiveDateTime,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AddMemberRequest {
    pub user_id: Uuid,
    pub role: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateMemberRoleRequest {
    pub role: String,
}

// ── API Response types ──

/// Member with user display info (joined from users table).
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MemberResponse {
    pub id: Uuid,
    pub user_id: Uuid,
    pub org_id: Uuid,
    pub role: String,
    pub email: String,
    pub display_name: Option<String>,
    pub joined_at: chrono::NaiveDateTime,
}

/// Org with member count for list display.
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TeamOrgResponse {
    pub id: Uuid,
    pub name: String,
    pub slug: String,
    pub description: Option<String>,
    pub is_active: bool,
    pub settings: serde_json::Value,
    pub created_by: Uuid,
    pub created_at: chrono::NaiveDateTime,
    pub updated_at: chrono::NaiveDateTime,
    pub member_count: Option<i64>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TeamProjectResponse {
    pub id: Uuid,
    pub org_id: Uuid,
    pub name: String,
    pub slug: String,
    pub description: Option<String>,
    pub is_active: bool,
    pub created_by: Uuid,
    pub created_at: chrono::NaiveDateTime,
    pub updated_at: chrono::NaiveDateTime,
}

impl From<&TeamOrg> for TeamOrgResponse {
    fn from(org: &TeamOrg) -> Self {
        Self {
            id: org.id,
            name: org.name.clone(),
            slug: org.slug.clone(),
            description: org.description.clone(),
            is_active: org.is_active,
            settings: org.settings.clone(),
            created_by: org.created_by,
            created_at: org.created_at,
            updated_at: org.updated_at,
            member_count: None,
        }
    }
}

impl From<&TeamProject> for TeamProjectResponse {
    fn from(proj: &TeamProject) -> Self {
        Self {
            id: proj.id,
            org_id: proj.org_id,
            name: proj.name.clone(),
            slug: proj.slug.clone(),
            description: proj.description.clone(),
            is_active: proj.is_active,
            created_by: proj.created_by,
            created_at: proj.created_at,
            updated_at: proj.updated_at,
        }
    }
}

// ── Db insertable structs (not exposed via API) ──

#[derive(Debug, Insertable)]
#[diesel(table_name = crate::schema::team_orgs)]
pub(crate) struct NewTeamOrg {
    pub id: Uuid,
    pub name: String,
    pub slug: String,
    pub description: Option<String>,
    pub is_active: bool,
    pub settings: serde_json::Value,
    pub created_by: Uuid,
    pub created_at: chrono::NaiveDateTime,
    pub updated_at: chrono::NaiveDateTime,
}

#[derive(Debug, Insertable)]
#[diesel(table_name = crate::schema::team_projects)]
pub(crate) struct NewTeamProject {
    pub id: Uuid,
    pub org_id: Uuid,
    pub name: String,
    pub slug: String,
    pub description: Option<String>,
    pub is_active: bool,
    pub created_by: Uuid,
    pub created_at: chrono::NaiveDateTime,
    pub updated_at: chrono::NaiveDateTime,
}

#[derive(Debug, Insertable)]
#[diesel(table_name = crate::schema::team_membership)]
pub(crate) struct NewTeamMembership {
    pub id: Uuid,
    pub user_id: Uuid,
    pub org_id: Uuid,
    pub role: String,
    pub joined_at: chrono::NaiveDateTime,
}

// ── Validations ──

/// Valid team membership roles.
pub const VALID_MEMBER_ROLES: &[&str] = &["admin", "manager", "operator", "viewer", "auditor"];

pub fn is_valid_member_role(role: &str) -> bool {
    VALID_MEMBER_ROLES.contains(&role)
}

// ── Tests ──

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_valid_member_roles() {
        assert!(is_valid_member_role("admin"));
        assert!(is_valid_member_role("manager"));
        assert!(is_valid_member_role("operator"));
        assert!(is_valid_member_role("viewer"));
        assert!(is_valid_member_role("auditor"));
        assert!(!is_valid_member_role("superadmin"));
        assert!(!is_valid_member_role(""));
        assert!(!is_valid_member_role("member"));
    }

    #[test]
    fn test_create_team_org_deserialization() {
        let json = r#"{"name": "My Org", "description": "Test org"}"#;
        let input: CreateTeamOrg = serde_json::from_str(json).unwrap();
        assert_eq!(input.name, "My Org");
        assert_eq!(input.description, Some("Test org".to_string()));
    }

    #[test]
    fn test_create_team_org_no_description() {
        let json = r#"{"name": "Minimal Org"}"#;
        let input: CreateTeamOrg = serde_json::from_str(json).unwrap();
        assert_eq!(input.name, "Minimal Org");
        assert_eq!(input.description, None);
    }

    #[test]
    fn test_add_member_request_deserialization() {
        let json = r#"{"userId": "00000000-0000-0000-0000-000000000001", "role": "viewer"}"#;
        let input: AddMemberRequest = serde_json::from_str(json).unwrap();
        assert_eq!(input.role, "viewer");
    }

    #[test]
    fn test_team_org_response_from_ref() {
        let org = TeamOrg {
            id: Uuid::new_v4(),
            name: "Test".to_string(),
            slug: "test".to_string(),
            description: None,
            is_active: true,
            settings: serde_json::json!({}),
            created_by: Uuid::new_v4(),
            created_at: chrono::Utc::now().naive_utc(),
            updated_at: chrono::Utc::now().naive_utc(),
        };
        let resp = TeamOrgResponse::from(&org);
        assert_eq!(resp.name, "Test");
        assert_eq!(resp.slug, "test");
    }
}
