use crate::connection::DbPool;
use diesel::prelude::*;
use diesel_async::RunQueryDsl;
use models::token::{ApiToken, CreateApiToken, RefreshToken};
use sha2::{Digest, Sha256};
use uuid::Uuid;

use crate::schema::{api_tokens, refresh_tokens};

type DbResult<T> = Result<T, Box<dyn std::error::Error + Send + Sync>>;

/// Hash a full token string to SHA-256 for storage.
pub fn hash_token(token: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(token.as_bytes());
    format!("{:x}", hasher.finalize())
}

// ── API Tokens ──

pub async fn create_api_token(pool: &DbPool, token: &CreateApiToken) -> DbResult<ApiToken> {
    let mut client = pool.get().await?;
    let new_id = Uuid::new_v4();
    let now = chrono::Utc::now().naive_utc();
    let result = diesel::insert_into(api_tokens::table)
        .values((
            api_tokens::id.eq(new_id),
            api_tokens::user_id.eq(token.user_id),
            api_tokens::name.eq(&token.name),
            api_tokens::token_prefix.eq(&token.token_prefix),
            api_tokens::token_hash.eq(&token.token_hash),
            api_tokens::scopes.eq(&token.scopes),
            api_tokens::is_revoked.eq(false),
            api_tokens::created_at.eq(now),
        ))
        .get_result::<ApiToken>(&mut *client)
        .await?;
    Ok(result)
}

pub async fn get_token_by_hash(pool: &DbPool, token_hash: &str) -> DbResult<Option<ApiToken>> {
    let mut client = pool.get().await?;
    let result = api_tokens::table
        .filter(api_tokens::token_hash.eq(token_hash))
        .first::<ApiToken>(&mut *client)
        .await
        .optional()?;
    Ok(result)
}

pub async fn list_tokens_for_user(pool: &DbPool, user_id: Uuid) -> DbResult<Vec<ApiToken>> {
    let mut client = pool.get().await?;
    let result = api_tokens::table
        .filter(api_tokens::user_id.eq(user_id))
        .order(api_tokens::created_at.desc())
        .load::<ApiToken>(&mut *client)
        .await?;
    Ok(result)
}

pub async fn revoke_token(pool: &DbPool, token_id: Uuid) -> DbResult<()> {
    let mut client = pool.get().await?;
    diesel::update(api_tokens::table.find(token_id))
        .set(api_tokens::is_revoked.eq(true))
        .execute(&mut *client)
        .await?;
    Ok(())
}

pub async fn update_token_last_used(pool: &DbPool, token_id: Uuid) -> DbResult<()> {
    let mut client = pool.get().await?;
    let now = chrono::Utc::now().naive_utc();
    diesel::update(api_tokens::table.find(token_id))
        .set(api_tokens::last_used_at.eq(Some(now)))
        .execute(&mut *client)
        .await?;
    Ok(())
}

// ── Refresh Tokens ──

pub async fn create_refresh_token(
    pool: &DbPool,
    user_id: Uuid,
    token_hash: &str,
    expires_at: chrono::NaiveDateTime,
) -> DbResult<RefreshToken> {
    let mut client = pool.get().await?;
    let new_id = Uuid::new_v4();
    let now = chrono::Utc::now().naive_utc();
    let result = diesel::insert_into(refresh_tokens::table)
        .values((
            refresh_tokens::id.eq(new_id),
            refresh_tokens::user_id.eq(user_id),
            refresh_tokens::token_hash.eq(token_hash),
            refresh_tokens::expires_at.eq(expires_at),
            refresh_tokens::is_revoked.eq(false),
            refresh_tokens::created_at.eq(now),
        ))
        .get_result::<RefreshToken>(&mut *client)
        .await?;
    Ok(result)
}

pub async fn get_refresh_token_by_hash(
    pool: &DbPool,
    token_hash: &str,
) -> DbResult<Option<RefreshToken>> {
    let mut client = pool.get().await?;
    let result = refresh_tokens::table
        .filter(refresh_tokens::token_hash.eq(token_hash))
        .first::<RefreshToken>(&mut *client)
        .await
        .optional()?;
    Ok(result)
}

pub async fn revoke_refresh_token(pool: &DbPool, token_id: Uuid) -> DbResult<()> {
    let mut client = pool.get().await?;
    diesel::update(refresh_tokens::table.find(token_id))
        .set(refresh_tokens::is_revoked.eq(true))
        .execute(&mut *client)
        .await?;
    Ok(())
}
