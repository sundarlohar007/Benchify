use diesel::prelude::*;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, Queryable, Selectable)]
#[diesel(table_name = crate::schema::users)]
#[diesel(check_for_backend(diesel::pg::Pg))]
#[serde(rename_all = "camelCase")]
pub struct User {
    pub id: Uuid,
    pub email: String,
    #[serde(skip_serializing)]
    pub password_hash: Option<String>,
    pub display_name: Option<String>,
    pub role: String,
    pub is_active: bool,
    pub sso_provider: Option<String>,
    pub sso_subject: Option<String>,
    pub auth_source: String,
    pub created_at: chrono::NaiveDateTime,
    pub updated_at: chrono::NaiveDateTime,
}

/// Insertable struct for local (password-based) users.
#[derive(Debug, Insertable)]
#[diesel(table_name = crate::schema::users)]
pub struct NewLocalUser {
    pub id: Uuid,
    pub email: String,
    pub password_hash: String,
    pub display_name: Option<String>,
    pub role: String,
    pub is_active: bool,
    pub auth_source: String,
    pub created_at: chrono::NaiveDateTime,
    pub updated_at: chrono::NaiveDateTime,
}

/// Insertable struct for JIT-provisioned SSO users (no password).
#[derive(Debug, Insertable)]
#[diesel(table_name = crate::schema::users)]
pub struct NewSsoUser {
    pub id: Uuid,
    pub email: String,
    pub display_name: Option<String>,
    pub role: String,
    pub is_active: bool,
    pub sso_provider: String,
    pub sso_subject: String,
    pub auth_source: String,
    pub created_at: chrono::NaiveDateTime,
    pub updated_at: chrono::NaiveDateTime,
}
