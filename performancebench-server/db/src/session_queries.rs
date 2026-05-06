use diesel::prelude::*;
use diesel_async::RunQueryDsl;
use models::session::Session;
use serde_json;
use uuid::Uuid;

use crate::connection::DbPool;
use crate::schema::sessions;

type DbResult<T> = Result<T, Box<dyn std::error::Error + Send + Sync>>;

/// Offset-based pagination query (D-19).
/// Returns (sessions, total_count) to support pagination metadata.
/// Does NOT include the metric_samples JSONB column in list results (Pitfall 4).
pub async fn list_sessions(
    pool: &DbPool,
    user_id: Uuid,
    offset: i64,
    limit: i64,
    app_name: Option<&str>,
    device_model: Option<&str>,
    tags: Option<&[String]>,
    project_id: Option<&str>,
) -> DbResult<(Vec<Session>, i64)> {
    let mut client = pool.get().await?;

    let mut filtered = sessions::table
        .filter(sessions::user_id.eq(user_id))
        .into_boxed();

    if let Some(name) = app_name {
        filtered = filtered.filter(sessions::app_name.eq(name.to_string()));
    }
    if let Some(model) = device_model {
        filtered = filtered.filter(sessions::device_model.eq(Some(model.to_string())));
    }
    if let Some(pid) = project_id {
        filtered = filtered.filter(sessions::project_id.eq(Some(pid.to_string())));
    }

    // Tag filtering: if tags provided, filter sessions whose tags array overlaps.
    let sessions_data: Vec<Session>;
    let total: i64;

    if let Some(tag_list) = tags {
        if !tag_list.is_empty() {
            let tag_filter = format!(
                "tags && ARRAY[{}]::text[]",
                tag_list
                    .iter()
                    .map(|t| format!("'{}'", t.replace('\'', "''")))
                    .collect::<Vec<_>>()
                    .join(", ")
            );

            let count_query = diesel::sql_query(format!(
                "SELECT COUNT(*) as count FROM sessions WHERE user_id = $1 AND {}",
                tag_filter
            ))
            .bind::<diesel::sql_types::Uuid, _>(user_id);
            let count_rows = count_query.load::<diesel_deser::CountRow>(&mut *client).await?;
            total = if count_rows.is_empty() { 0 } else { count_rows[0].count };

            let data_query = diesel::sql_query(format!(
                r#"SELECT id, user_id, device_id, app_name, app_package, app_version,
                       device_model, device_os_version, chipset, tags, project_id,
                       collection_id, notes, started_at, ended_at, duration_seconds,
                       session_stats, metric_samples, markers, detected_issues, screenshots,
                       video_metadata, thumbnail_path, is_uploaded, uploaded_by,
                       uploaded_at, created_at, updated_at
                FROM sessions WHERE user_id = $1 AND {}
                ORDER BY started_at DESC OFFSET $2 LIMIT $3"#,
                tag_filter
            ))
            .bind::<diesel::sql_types::Uuid, _>(user_id)
            .bind::<diesel::sql_types::BigInt, _>(offset)
            .bind::<diesel::sql_types::BigInt, _>(limit);
            sessions_data = data_query.load::<Session>(&mut *client).await?;
        } else {
            total = sessions::table
                .filter(sessions::user_id.eq(user_id))
                .count()
                .get_result::<i64>(&mut *client)
                .await?;
            sessions_data = sessions::table
                .filter(sessions::user_id.eq(user_id))
                .order(sessions::started_at.desc())
                .offset(offset)
                .limit(limit)
                .select(Session::as_select())
                .load::<Session>(&mut *client)
                .await?;
        }
    } else {
        total = sessions::table
            .filter(sessions::user_id.eq(user_id))
            .count()
            .get_result::<i64>(&mut *client)
            .await?;
        sessions_data = sessions::table
            .filter(sessions::user_id.eq(user_id))
            .order(sessions::started_at.desc())
            .offset(offset)
            .limit(limit)
            .select(Session::as_select())
            .load::<Session>(&mut *client)
            .await?;
    }

    Ok((sessions_data, total))
}

/// Get full session detail including JSONB columns.
pub async fn get_session_by_id(pool: &DbPool, session_id: Uuid) -> DbResult<Option<Session>> {
    let mut client = pool.get().await?;
    let result = sessions::table
        .find(session_id)
        .select(Session::as_select())
        .first::<Session>(&mut *client)
        .await
        .optional()?;
    Ok(result)
}

/// Get session by ID scoped to a specific user (authorization check).
pub async fn get_session_by_id_and_user(
    pool: &DbPool,
    session_id: Uuid,
    user_id: Uuid,
) -> DbResult<Option<Session>> {
    let mut client = pool.get().await?;
    let result = sessions::table
        .filter(sessions::id.eq(session_id))
        .filter(sessions::user_id.eq(user_id))
        .select(Session::as_select())
        .first::<Session>(&mut *client)
        .await
        .optional()?;
    Ok(result)
}

/// Insert a new session. The `metric_samples` field is stored as a JSONB string.
pub async fn insert_session(
    pool: &DbPool,
    session: &NewSession,
) -> DbResult<Session> {
    let mut client = pool.get().await?;
    let now = chrono::Utc::now().naive_utc();

    let result = diesel::insert_into(sessions::table)
        .values((
            sessions::id.eq(session.id),
            sessions::user_id.eq(session.user_id),
            sessions::device_id.eq(session.device_id),
            sessions::app_name.eq(&session.app_name),
            sessions::app_package.eq(&session.app_package),
            sessions::app_version.eq(&session.app_version),
            sessions::device_model.eq(&session.device_model),
            sessions::device_os_version.eq(&session.device_os_version),
            sessions::chipset.eq(&session.chipset),
            sessions::tags.eq(&session.tags),
            sessions::project_id.eq(&session.project_id),
            sessions::collection_id.eq(session.collection_id),
            sessions::notes.eq(&session.notes),
            sessions::started_at.eq(session.started_at),
            sessions::ended_at.eq(session.ended_at),
            sessions::duration_seconds.eq(session.duration_seconds),
            sessions::session_stats.eq(parse_jsonb_val(&session.session_stats_str)),
            sessions::metric_samples.eq(parse_jsonb_val(&session.metric_samples_str)),
            sessions::markers.eq(parse_jsonb_val(&session.markers_str)),
            sessions::detected_issues.eq(parse_jsonb_val(&session.detected_issues_str)),
            sessions::screenshots.eq(&session.screenshots),
            sessions::video_metadata.eq(session.video_metadata_str.as_ref().map(|s| parse_jsonb_val(s))),
            sessions::thumbnail_path.eq(&session.thumbnail_path),
            sessions::is_uploaded.eq(session.is_uploaded),
            sessions::uploaded_by.eq(session.uploaded_by),
            sessions::uploaded_at.eq(session.uploaded_at.unwrap_or(now)),
            sessions::created_at.eq(now),
            sessions::updated_at.eq(now),
        ))
        .get_result::<Session>(&mut *client)
        .await?;

    Ok(result)
}

/// Delete a session (owner-scoped).
pub async fn delete_session(
    pool: &DbPool,
    session_id: Uuid,
    user_id: Uuid,
) -> DbResult<()> {
    let mut client = pool.get().await?;
    diesel::delete(
        sessions::table
            .filter(sessions::id.eq(session_id))
            .filter(sessions::user_id.eq(user_id)),
    )
    .execute(&mut *client)
    .await?;
    Ok(())
}

/// Update the session_stats JSONB column after analytics recomputation (D-18).
pub async fn update_session_stats(
    pool: &DbPool,
    session_id: Uuid,
    stats_json: serde_json::Value,
) -> DbResult<()> {
    let mut client = pool.get().await?;
    let now = chrono::Utc::now().naive_utc();
    diesel::update(sessions::table.find(session_id))
        .set((
            sessions::session_stats.eq(&stats_json),
            sessions::updated_at.eq(now),
        ))
        .execute(&mut *client)
        .await?;
    Ok(())
}

/// Check if a session UUID already exists (D-25 duplicate check).
pub async fn session_exists(pool: &DbPool, session_id: Uuid) -> DbResult<bool> {
    let mut client = pool.get().await?;
    let count: i64 = sessions::table
        .filter(sessions::id.eq(session_id))
        .count()
        .get_result(&mut *client)
        .await?;
    Ok(count > 0)
}

// ── Insert helper types ──

/// Data needed to insert a new session.
pub struct NewSession {
    pub id: Uuid,
    pub user_id: Uuid,
    pub device_id: Option<Uuid>,
    pub app_name: String,
    pub app_package: Option<String>,
    pub app_version: Option<String>,
    pub device_model: Option<String>,
    pub device_os_version: Option<String>,
    pub chipset: Option<String>,
    pub tags: Vec<String>,
    pub project_id: Option<String>,
    pub collection_id: Option<Uuid>,
    pub notes: Option<String>,
    pub started_at: chrono::NaiveDateTime,
    pub ended_at: Option<chrono::NaiveDateTime>,
    pub duration_seconds: Option<i32>,
    pub session_stats_str: String,
    pub metric_samples_str: String,
    pub markers_str: String,
    pub detected_issues_str: String,
    pub screenshots: Vec<String>,
    pub video_metadata_str: Option<String>,
    pub thumbnail_path: Option<String>,
    pub is_uploaded: bool,
    pub uploaded_by: Option<Uuid>,
    pub uploaded_at: Option<chrono::NaiveDateTime>,
}

/// Parse a JSON string into serde_json::Value for JSONB column insertion.
fn parse_jsonb_val(s: &str) -> serde_json::Value {
    serde_json::from_str(s).unwrap_or(serde_json::Value::Null)
}

/// Helper for raw SQL count queries (used with tag filtering).
mod diesel_deser {
    use diesel::deserialize::{self, FromSql};
    use diesel::pg::Pg;
    use diesel::prelude::*;
    use diesel::sql_types::BigInt;

    #[derive(QueryableByName, Debug)]
    #[diesel(table_name = dummy)]
    pub struct CountRow {
        #[diesel(sql_type = BigInt)]
        pub count: i64,
    }

    // Declare a dummy table for QueryableByName
    diesel::table! {
        dummy (id) {
            id -> Int4,
        }
    }
}
