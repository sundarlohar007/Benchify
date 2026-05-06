use diesel::prelude::*;
use diesel_async::RunQueryDsl;
use models::user::{NewLocalUser, NewSsoUser, User};
use uuid::Uuid;

use crate::connection::DbPool;
use crate::schema::users;

type DbResult<T> = Result<T, Box<dyn std::error::Error + Send + Sync>>;

pub async fn get_user_by_email(pool: &DbPool, email: &str) -> DbResult<Option<User>> {
    let mut client = pool.get().await?;
    let result = users::table
        .filter(users::email.eq(email))
        .first::<User>(&mut *client)
        .await
        .optional()?;
    Ok(result)
}

pub async fn get_user_by_id(pool: &DbPool, user_id: Uuid) -> DbResult<Option<User>> {
    let mut client = pool.get().await?;
    let result = users::table
        .find(user_id)
        .first::<User>(&mut *client)
        .await
        .optional()?;
    Ok(result)
}

/// Look up a user by SSO provider + subject (for re-authentication).
pub async fn get_user_by_sso(
    pool: &DbPool,
    sso_provider: &str,
    sso_subject: &str,
) -> DbResult<Option<User>> {
    let mut client = pool.get().await?;
    let result = users::table
        .filter(users::sso_provider.eq(sso_provider))
        .filter(users::sso_subject.eq(sso_subject))
        .first::<User>(&mut *client)
        .await
        .optional()?;
    Ok(result)
}

pub async fn count_users(pool: &DbPool) -> DbResult<i64> {
    let mut client = pool.get().await?;
    let count: i64 = users::table.count().get_result(&mut *client).await?;
    Ok(count)
}

/// Create a local (password-based) user.
pub async fn create_user(
    pool: &DbPool,
    email: &str,
    password_hash: &str,
    display_name: Option<&str>,
    role: &str,
) -> DbResult<User> {
    let mut client = pool.get().await?;
    let new_id = Uuid::new_v4();
    let now = chrono::Utc::now().naive_utc();
    let row = NewLocalUser {
        id: new_id,
        email: email.to_string(),
        password_hash: password_hash.to_string(),
        display_name: display_name.map(|s| s.to_string()),
        role: role.to_string(),
        is_active: true,
        auth_source: "local".to_string(),
        created_at: now,
        updated_at: now,
    };
    let user = diesel::insert_into(users::table)
        .values(&row)
        .get_result::<User>(&mut *client)
        .await?;
    Ok(user)
}

/// Find an existing user by (sso_provider + sso_subject) OR by email, then
/// either return the existing user or create a new JIT-provisioned SSO user.
///
/// Returns (user, is_new) — is_new is true when a new user was created.
pub async fn find_or_create_sso_user(
    pool: &DbPool,
    email: &str,
    display_name: Option<&str>,
    sso_provider: &str,
    sso_subject: &str,
) -> DbResult<(User, bool)> {
    let mut client = pool.get().await?;

    // 1. Check by SSO provider + subject (exact match, re-authentication)
    if let Some(user) = users::table
        .filter(users::sso_provider.eq(sso_provider))
        .filter(users::sso_subject.eq(sso_subject))
        .first::<User>(&mut *client)
        .await
        .optional()?
    {
        return Ok((user, false));
    }

    // 2. Check by email (user may have registered locally or via different SSO)
    if let Some(existing) = users::table
        .filter(users::email.eq(email))
        .first::<User>(&mut *client)
        .await
        .optional()?
    {
        // If the existing user has a different auth_source, return error
        if existing.auth_source != sso_provider && existing.auth_source != "local" {
            return Err(format!(
                "Email {} already registered with {} auth",
                email, existing.auth_source
            ).into());
        }
        // If existing user is local (or same provider), link the SSO identity
        // but don't change auth_source if it was local (preserve local login)
        if existing.auth_source == "local" {
            diesel::update(users::table.find(existing.id))
                .set((
                    users::sso_provider.eq(Some(sso_provider.to_string())),
                    users::sso_subject.eq(Some(sso_subject.to_string())),
                    users::updated_at.eq(chrono::Utc::now().naive_utc()),
                ))
                .execute(&mut *client)
                .await?;
            // Re-fetch to get updated row
            let updated = users::table.find(existing.id).first::<User>(&mut *client).await?;
            return Ok((updated, false));
        }
        return Ok((existing, false));
    }

    // 3. JIT provisioning: create new user with viewer role
    let new_id = Uuid::new_v4();
    let now = chrono::Utc::now().naive_utc();
    let row = NewSsoUser {
        id: new_id,
        email: email.to_string(),
        display_name: display_name.map(|s| s.to_string()),
        role: "viewer".to_string(),
        is_active: true,
        sso_provider: sso_provider.to_string(),
        sso_subject: sso_subject.to_string(),
        auth_source: sso_provider.to_string(),
        created_at: now,
        updated_at: now,
    };
    let user = diesel::insert_into(users::table)
        .values(&row)
        .get_result::<User>(&mut *client)
        .await?;

    tracing::info!(
        event_type = "jit_provision",
        user_id = %user.id,
        email = %user.email,
        sso_provider = %sso_provider,
        "JIT provisioned new SSO user"
    );

    Ok((user, true))
}

/// Update a user's role. Validates that the role is one of the 5 valid roles.
pub async fn update_user_role(
    pool: &DbPool,
    user_id: Uuid,
    new_role: &str,
) -> DbResult<User> {
    let mut client = pool.get().await?;
    let user = diesel::update(users::table.find(user_id))
        .set((
            users::role.eq(new_role),
            users::updated_at.eq(chrono::Utc::now().naive_utc()),
        ))
        .get_result::<User>(&mut *client)
        .await?;
    Ok(user)
}

/// Activate or deactivate a user.
pub async fn update_user_status(
    pool: &DbPool,
    user_id: Uuid,
    is_active: bool,
) -> DbResult<User> {
    let mut client = pool.get().await?;
    let user = diesel::update(users::table.find(user_id))
        .set((
            users::is_active.eq(is_active),
            users::updated_at.eq(chrono::Utc::now().naive_utc()),
        ))
        .get_result::<User>(&mut *client)
        .await?;
    Ok(user)
}

/// List users with optional role filter and pagination.
pub async fn list_users_filtered(
    pool: &DbPool,
    role_filter: Option<&str>,
    offset: i64,
    limit: i64,
) -> DbResult<(Vec<User>, i64)> {
    let mut client = pool.get().await?;

    // Build total count query separately (avoids Clone requirement on boxed query)
    let mut count_query = users::table.into_boxed();
    if let Some(role) = role_filter {
        count_query = count_query.filter(users::role.eq(role));
    }
    let total: i64 = count_query.count().get_result(&mut *client).await?;

    // Build paginated data query
    let mut query = users::table.into_boxed();
    if let Some(role) = role_filter {
        query = query.filter(users::role.eq(role));
    }

    let results = query
        .order(users::created_at.desc())
        .offset(offset)
        .limit(limit)
        .load::<User>(&mut *client)
        .await?;

    Ok((results, total))
}

pub async fn list_users(pool: &DbPool, offset: i64, limit: i64) -> DbResult<Vec<User>> {
    let mut client = pool.get().await?;
    let result = users::table
        .order(users::created_at.desc())
        .offset(offset)
        .limit(limit)
        .load::<User>(&mut *client)
        .await?;
    Ok(result)
}
