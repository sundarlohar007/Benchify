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
            .build()?;

        let mut config: AppConfig = cfg.try_deserialize()?;

        // Auto-generate JWT secret if not provided
        if config.jwt_secret.is_empty() {
            config.jwt_secret = uuid::Uuid::new_v4().to_string();
            tracing::warn!(
                jwt_secret = %config.jwt_secret,
                "JWT_SECRET not set — auto-generated UUID. Set JWT_SECRET in .env to persist across restarts."
            );
        }

        Ok(config)
    }
}
