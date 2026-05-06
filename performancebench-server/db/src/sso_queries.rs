use diesel::prelude::*;
use diesel_async::RunQueryDsl;
use models::sso::{CreateSsoConfig, SsoConfig, UpdateSsoConfig};
use uuid::Uuid;

use crate::connection::DbPool;
use crate::schema::sso_configs;

type DbResult<T> = Result<T, Box<dyn std::error::Error + Send + Sync>>;

/// Get all active SSO configs, optionally filtered by provider type.
pub async fn get_active_sso_configs(
    pool: &DbPool,
    provider_type: Option<&str>,
) -> DbResult<Vec<SsoConfig>> {
    let mut client = pool.get().await?;
    let mut query = sso_configs::table
        .filter(sso_configs::is_active.eq(true))
        .into_boxed();

    if let Some(pt) = provider_type {
        query = query.filter(sso_configs::provider_type.eq(pt));
    }

    let results = query
        .order(sso_configs::name.asc())
        .load::<SsoConfig>(&mut *client)
        .await?;
    Ok(results)
}

/// Get a single SSO config by ID.
pub async fn get_sso_config_by_id(pool: &DbPool, config_id: Uuid) -> DbResult<Option<SsoConfig>> {
    let mut client = pool.get().await?;
    let result = sso_configs::table
        .find(config_id)
        .first::<SsoConfig>(&mut *client)
        .await
        .optional()?;
    Ok(result)
}

/// Create a new SSO configuration.
pub async fn create_sso_config(
    pool: &DbPool,
    provider_type: &str,
    name: &str,
    config: serde_json::Value,
) -> DbResult<SsoConfig> {
    let mut client = pool.get().await?;
    let now = chrono::Utc::now().naive_utc();
    let row = CreateSsoConfig {
        id: Uuid::new_v4(),
        provider_type: provider_type.to_string(),
        name: name.to_string(),
        config,
        is_active: true,
        created_at: now,
        updated_at: now,
    };
    let result = diesel::insert_into(sso_configs::table)
        .values(&row)
        .get_result::<SsoConfig>(&mut *client)
        .await?;
    Ok(result)
}

/// Update an existing SSO configuration.
pub async fn update_sso_config(
    pool: &DbPool,
    config_id: Uuid,
    input: &UpdateSsoConfig,
) -> DbResult<SsoConfig> {
    let mut client = pool.get().await?;
    let target = sso_configs::table.find(config_id);

    // Build updates dynamically
    let config = diesel::update(target)
        .set((
            input.name.as_ref().map(|n| sso_configs::name.eq(n)),
            input.config.as_ref().map(|c| sso_configs::config.eq(c)),
            input.is_active.map(|a| sso_configs::is_active.eq(a)),
            Some(sso_configs::updated_at.eq(chrono::Utc::now().naive_utc())),
        ))
        .get_result::<SsoConfig>(&mut *client)
        .await?;

    Ok(config)
}

/// Delete an SSO configuration by ID.
pub async fn delete_sso_config(pool: &DbPool, config_id: Uuid) -> DbResult<()> {
    let mut client = pool.get().await?;
    diesel::delete(sso_configs::table.find(config_id))
        .execute(&mut *client)
        .await?;
    Ok(())
}
