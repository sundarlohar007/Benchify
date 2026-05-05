use diesel::prelude::*;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, Queryable, Selectable)]
#[diesel(table_name = crate::schema::api_tokens)]
#[diesel(check_for_backend(diesel::pg::Pg))]
#[serde(rename_all = "camelCase")]
pub struct ApiToken {
    pub id: Uuid,
    pub user_id: Uuid,
    pub name: String,
    pub token_prefix: String,
    pub token_hash: String,
    pub scopes: Vec<String>,
    pub last_used_at: Option<chrono::NaiveDateTime>,
    pub expires_at: Option<chrono::NaiveDateTime>,
    pub is_revoked: bool,
    pub created_at: chrono::NaiveDateTime,
}

#[derive(Debug, Clone, Serialize, Deserialize, Queryable, Selectable)]
#[diesel(table_name = crate::schema::refresh_tokens)]
#[diesel(check_for_backend(diesel::pg::Pg))]
#[serde(rename_all = "camelCase")]
pub struct RefreshToken {
    pub id: Uuid,
    pub user_id: Uuid,
    pub token_hash: String,
    pub expires_at: chrono::NaiveDateTime,
    pub is_revoked: bool,
    pub created_at: chrono::NaiveDateTime,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateApiToken {
    pub user_id: Uuid,
    pub name: String,
    pub token_prefix: String,
    pub token_hash: String,
    #[serde(default = "default_scopes")]
    pub scopes: Vec<String>,
    pub expires_at: Option<String>,
}

fn default_scopes() -> Vec<String> {
    vec!["read".to_string()]
}
