use diesel::prelude::*;
use diesel_async::RunQueryDsl;
use models::user::User;
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

pub async fn count_users(pool: &DbPool) -> DbResult<i64> {
    let mut client = pool.get().await?;
    let count: i64 = users::table.count().get_result(&mut *client).await?;
    Ok(count)
}

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
    let user = diesel::insert_into(users::table)
        .values((
            users::id.eq(new_id),
            users::email.eq(email),
            users::password_hash.eq(password_hash),
            users::display_name.eq(display_name),
            users::role.eq(role),
            users::is_active.eq(true),
            users::created_at.eq(now),
            users::updated_at.eq(now),
        ))
        .get_result::<User>(&mut *client)
        .await?;
    Ok(user)
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
