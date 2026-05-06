use diesel::prelude::*;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// SSO provider configuration stored in the database.
#[derive(Debug, Clone, Serialize, Deserialize, Queryable, Selectable)]
#[diesel(table_name = crate::schema::sso_configs)]
#[diesel(check_for_backend(diesel::pg::Pg))]
#[serde(rename_all = "camelCase")]
pub struct SsoConfig {
    pub id: Uuid,
    pub provider_type: String,
    pub name: String,
    pub config: serde_json::Value,
    pub is_active: bool,
    pub created_at: chrono::NaiveDateTime,
    pub updated_at: chrono::NaiveDateTime,
}

/// Enum representing the type of SSO provider.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum SsoProviderType {
    Oidc,
    Saml,
    Ldap,
}

impl std::fmt::Display for SsoProviderType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            SsoProviderType::Oidc => write!(f, "oidc"),
            SsoProviderType::Saml => write!(f, "saml"),
            SsoProviderType::Ldap => write!(f, "ldap"),
        }
    }
}

impl std::str::FromStr for SsoProviderType {
    type Err = String;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "oidc" => Ok(SsoProviderType::Oidc),
            "saml" => Ok(SsoProviderType::Saml),
            "ldap" => Ok(SsoProviderType::Ldap),
            _ => Err(format!("Unknown SSO provider type: {}", s)),
        }
    }
}

// ── Provider-specific configuration structs ──

/// OIDC provider configuration stored in sso_configs.config JSONB field.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct OidcProviderConfig {
    pub client_id: String,
    #[serde(skip_serializing)]
    pub client_secret: String,
    pub issuer_url: String,
    #[serde(default = "default_oidc_scopes")]
    pub scopes: Vec<String>,
    pub attribute_mapping: Option<AttributeMapping>,
}

/// SAML 2.0 provider configuration stored in sso_configs.config JSONB field.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SamlProviderConfig {
    pub idp_metadata_url: Option<String>,
    pub idp_sso_url: String,
    pub idp_entity_id: String,
    pub sp_entity_id: String,
    pub acs_url: String,
    pub attribute_mapping: Option<AttributeMapping>,
    #[serde(skip_serializing)]
    pub idp_signing_cert: Option<String>,
}

/// LDAP provider configuration stored in sso_configs.config JSONB field.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LdapProviderConfig {
    pub server_url: String,
    pub bind_dn: String,
    #[serde(skip_serializing)]
    pub bind_password: String,
    pub search_base: String,
    pub user_filter: String,
    pub attribute_mapping: Option<AttributeMapping>,
}

/// Attribute mapping for SSO → user profile fields.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AttributeMapping {
    pub email: Option<String>,
    pub display_name: Option<String>,
}

// ── Insertable / update structs ──

#[derive(Debug, Insertable)]
#[diesel(table_name = crate::schema::sso_configs)]
pub struct CreateSsoConfig {
    pub id: Uuid,
    pub provider_type: String,
    pub name: String,
    pub config: serde_json::Value,
    pub is_active: bool,
    pub created_at: chrono::NaiveDateTime,
    pub updated_at: chrono::NaiveDateTime,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateSsoConfig {
    pub name: Option<String>,
    pub config: Option<serde_json::Value>,
    pub is_active: Option<bool>,
}

// ── Helpers ──

fn default_oidc_scopes() -> Vec<String> {
    vec![
        "openid".to_string(),
        "profile".to_string(),
        "email".to_string(),
    ]
}
