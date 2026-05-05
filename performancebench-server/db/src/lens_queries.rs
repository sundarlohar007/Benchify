use diesel::prelude::*;
use diesel_async::RunQueryDsl;
use models::alert::Lens;
use serde_json;
use uuid::Uuid;

use crate::connection::DbPool;
use crate::schema::lenses;

type DbResult<T> = Result<T, Box<dyn std::error::Error + Send + Sync>>;

/// List lenses for a user, plus any public lenses from other users.
pub async fn list_lenses(pool: &DbPool, user_id: Uuid, include_public: bool) -> DbResult<Vec<Lens>> {
    let mut client = pool.get().await?;

    if include_public {
        lenses::table
            .filter(lenses::user_id.eq(user_id).or(lenses::is_public.eq(true)))
            .order(lenses::created_at.desc())
            .load::<Lens>(&mut *client)
            .await
            .map_err(|e| e.into())
    } else {
        lenses::table
            .filter(lenses::user_id.eq(user_id))
            .order(lenses::created_at.desc())
            .load::<Lens>(&mut *client)
            .await
            .map_err(|e| e.into())
    }
}

/// Get a single lens by ID.
pub async fn get_lens(pool: &DbPool, lens_id: Uuid) -> DbResult<Option<Lens>> {
    let mut client = pool.get().await?;
    lenses::table
        .find(lens_id)
        .first::<Lens>(&mut *client)
        .await
        .optional()
        .map_err(|e| e.into())
}

/// Create a new lens.
pub async fn create_lens(
    pool: &DbPool,
    user_id: Uuid,
    name: &str,
    description: Option<&str>,
    filters: serde_json::Value,
    chart_config: serde_json::Value,
    is_public: bool,
) -> DbResult<Lens> {
    let mut client = pool.get().await?;
    let new_id = Uuid::new_v4();
    let now = chrono::Utc::now().naive_utc();

    let result = diesel::insert_into(lenses::table)
        .values((
            lenses::id.eq(new_id),
            lenses::user_id.eq(user_id),
            lenses::name.eq(name),
            lenses::description.eq(description),
            lenses::filters.eq(filters),
            lenses::chart_config.eq(chart_config),
            lenses::is_public.eq(is_public),
            lenses::created_at.eq(now),
            lenses::updated_at.eq(now),
        ))
        .get_result::<Lens>(&mut *client)
        .await?;
    Ok(result)
}

/// Update an existing lens (owner-scoped).
pub async fn update_lens(
    pool: &DbPool,
    lens_id: Uuid,
    user_id: Uuid,
    name: Option<&str>,
    description: Option<Option<&str>>,
    filters: Option<serde_json::Value>,
    chart_config: Option<serde_json::Value>,
    is_public: Option<bool>,
) -> DbResult<Option<Lens>> {
    let mut client = pool.get().await?;
    let now = chrono::Utc::now().naive_utc();

    // Check ownership
    let existing = lenses::table
        .filter(lenses::id.eq(lens_id))
        .filter(lenses::user_id.eq(user_id))
        .first::<Lens>(&mut *client)
        .await
        .optional()?;

    let target = match existing {
        Some(_) => lenses::table
            .filter(lenses::id.eq(lens_id))
            .filter(lenses::user_id.eq(user_id)),
        None => return Ok(None),
    };

    let mut update = diesel::update(target).into_boxed();

    if let Some(n) = name {
        update = update.set(lenses::name.eq(n));
    }
    if let Some(d) = description {
        update = update.set(lenses::description.eq(d));
    }
    if let Some(f) = filters {
        update = update.set(lenses::filters.eq(f));
    }
    if let Some(c) = chart_config {
        update = update.set(lenses::chart_config.eq(c));
    }
    if let Some(p) = is_public {
        update = update.set(lenses::is_public.eq(p));
    }
    update = update.set(lenses::updated_at.eq(now));

    let result = update.get_result::<Lens>(&mut *client).await?;
    Ok(Some(result))
}

/// Delete a lens (owner-scoped).
pub async fn delete_lens(pool: &DbPool, lens_id: Uuid, user_id: Uuid) -> DbResult<()> {
    let mut client = pool.get().await?;
    diesel::delete(
        lenses::table
            .filter(lenses::id.eq(lens_id))
            .filter(lenses::user_id.eq(user_id)),
    )
    .execute(&mut *client)
    .await?;
    Ok(())
}
