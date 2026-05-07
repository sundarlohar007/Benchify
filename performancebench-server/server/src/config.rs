use serde::Deserialize;

#[derive(Debug, Clone, Deserialize)]
pub struct AppConfig {
    pub database_url: String,
    pub jwt_secret: String,
    pub host: String,
    pub port: u16,
    pub tls_cert_path: Option<String>,
    pub tls_key_path: Option<String>,
    pub cors_allowed_origins: Vec<String>,
    pub upload_dir: String,
    pub smtp_host: Option<String>,
    pub smtp_port: Option<u16>,
    pub smtp_username: Option<String>,
    pub smtp_password: Option<String>,
    pub smtp_from_email: Option<String>,
    pub slack_webhook_url: Option<String>,

    // ── SSO Configuration ──
    /// Master switch: enable SSO endpoints. Default: false (backward compatible).
    #[serde(default = "default_false")]
    pub sso_enabled: bool,

    /// Base URL used for OIDC/SAML redirect URIs (e.g., "https://myhost.com").
    #[serde(default = "default_sso_redirect_base_url")]
    pub sso_redirect_base_url: String,

    /// OIDC providers defined in config file (optional — DB configs take precedence).
    /// Each entry provides client_id, client_secret, issuer_url, scopes, attribute_mapping.
    #[serde(default)]
    pub oidc_providers: Option<Vec<OidcProviderConfigEntry>>,

    // ── Jira Integration ──
    /// Master switch: enable Jira issue creation from sessions. Default: false.
    #[serde(default = "default_false")]
    pub jira_enabled: bool,

    /// Jira Cloud base URL (e.g., "https://your-domain.atlassian.net").
    pub jira_base_url: Option<String>,

    /// Jira account email for Basic auth.
    pub jira_email: Option<String>,

    /// Jira API token (not account password). Generate at https://id.atlassian.com/manage/api-tokens.
    pub jira_api_token: Option<String>,
}

fn default_false() -> bool {
    false
}

fn default_sso_redirect_base_url() -> String {
    "http://localhost:3000".to_string()
}

/// OIDC provider entry from config file (used when no DB config exists).
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct OidcProviderConfigEntry {
    pub name: String,
    pub client_id: String,
    pub client_secret: String,
    pub issuer_url: String,
    #[serde(default = "default_oidc_scopes")]
    pub scopes: Vec<String>,
    #[serde(default)]
    pub attribute_mapping: Option<AttributeMappingConfig>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AttributeMappingConfig {
    pub email: Option<String>,
    pub display_name: Option<String>,
}

fn default_oidc_scopes() -> Vec<String> {
    vec![
        "openid".to_string(),
        "profile".to_string(),
        "email".to_string(),
    ]
}

impl AppConfig {
    pub fn from_env() -> Result<Self, config::ConfigError> {
        let cfg = config::Config::builder()
            .add_source(
                config::Environment::default()
                    .prefix("")
                    .separator("__")
                    .try_parsing(true),
            )
            .set_default("database_url", "postgres://benchify:benchify@localhost:5432/benchify")?
            .set_default("jwt_secret", "")?
            .set_default("host", "0.0.0.0")?
            .set_default("port", 3000)?
            .set_default("cors_allowed_origins", vec![
                "http://localhost:5173".to_string(),
                "http://localhost:3000".to_string(),
            ])?
            .set_default("upload_dir", "./uploads")?
            .set_default("sso_enabled", false)?
            .set_default("sso_redirect_base_url", "http://localhost:3000")?
            .set_default("jira_enabled", false)?
            .build()?;

        let mut config: AppConfig = cfg.try_deserialize()?;

        // Require JWT_SECRET at startup — auto-generation invalidates all user sessions
        if config.jwt_secret.is_empty() {
            return Err(config::ConfigError::Message(
                "JWT_SECRET environment variable is required. \
                 Generate: openssl rand -base64 64".to_string(),
            ));
        }

        Ok(config)
    }
}
