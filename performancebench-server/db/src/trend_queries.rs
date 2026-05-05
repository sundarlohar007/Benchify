use diesel::prelude::*;
use diesel_async::RunQueryDsl;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::connection::DbPool;

type DbResult<T> = Result<T, Box<dyn std::error::Error + Send + Sync>>;

/// A single trend data point returned by aggregation queries.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TrendPoint {
    pub timestamp: String,
    pub session_id: Uuid,
    pub app_name: String,
    /// JSONB-extracted value (e.g., fps_median, cpu_avg_pct)
    pub value: Option<f64>,
    pub label: Option<String>,
}

/// Get FPS trends: fps_median and fps_stability across sessions within date range.
/// Extracts from session_stats JSONB column.
pub async fn get_fps_trends(
    pool: &DbPool,
    user_id: Uuid,
    start_date: &str,
    end_date: &str,
    app_name: Option<&str>,
) -> DbResult<Vec<TrendPoint>> {
    use diesel::sql_types::{Text, Uuid as SqlUuid, Nullable, Double};

    let mut client = pool.get().await?;

    let base_sql = match app_name {
        Some(_) => {
            r#"
            SELECT started_at::text as ts, id as sid, app_name,
                   (session_stats->>'fpsMedian')::double precision as val
            FROM sessions
            WHERE user_id = $1
              AND started_at >= $2::timestamptz
              AND started_at <= $3::timestamptz
              AND app_name = $4
            ORDER BY started_at ASC
            "#
        }
        None => {
            r#"
            SELECT started_at::text as ts, id as sid, app_name,
                   (session_stats->>'fpsMedian')::double precision as val
            FROM sessions
            WHERE user_id = $1
              AND started_at >= $2::timestamptz
              AND started_at <= $3::timestamptz
            ORDER BY started_at ASC
            "#
        }
    };

    #[derive(QueryableByName, Debug)]
    #[diesel(table_name = trend_query)]
    struct TrendRow {
        #[diesel(sql_type = Text)]
        ts: String,
        #[diesel(sql_type = SqlUuid)]
        sid: Uuid,
        #[diesel(sql_type = Text)]
        app_name: String,
        #[diesel(sql_type = Nullable<Double>)]
        val: Option<f64>,
    }

    let query = if let Some(app) = app_name {
        diesel::sql_query(base_sql)
            .bind::<SqlUuid, _>(user_id)
            .bind::<Text, _>(start_date.to_string())
            .bind::<Text, _>(end_date.to_string())
            .bind::<Text, _>(app.to_string())
    } else {
        diesel::sql_query(base_sql)
            .bind::<SqlUuid, _>(user_id)
            .bind::<Text, _>(start_date.to_string())
            .bind::<Text, _>(end_date.to_string())
    };

    let rows = query.load::<TrendRow>(&mut *client).await?;

    Ok(rows
        .into_iter()
        .map(|r| TrendPoint {
            timestamp: r.ts,
            session_id: r.sid,
            app_name: r.app_name,
            value: r.val,
            label: Some("fpsMedian".to_string()),
        })
        .collect())
}

/// Get aggregation trends for a general metric (CPU, Memory, Battery, Network).
/// Extracts the given JSONB key as double precision.
pub async fn get_metric_trends(
    pool: &DbPool,
    user_id: Uuid,
    start_date: &str,
    end_date: &str,
    jsonb_key: &str,
    app_name: Option<&str>,
) -> DbResult<Vec<TrendPoint>> {
    use diesel::sql_types::{Text, Uuid as SqlUuid, Nullable, Double};

    let mut client = pool.get().await?;

    let sql = format!(
        r#"
        SELECT started_at::text as ts, id as sid, app_name,
               (session_stats->>'{}')::double precision as val
        FROM sessions
        WHERE user_id = $1
          AND started_at >= $2::timestamptz
          AND started_at <= $3::timestamptz
          {}"
        "#,
        jsonb_key,
        if app_name.is_some() { "AND app_name = $4" } else { "" }
    );

    #[derive(QueryableByName, Debug)]
    #[diesel(table_name = trend_query2)]
    struct TrendRow {
        #[diesel(sql_type = Text)]
        ts: String,
        #[diesel(sql_type = SqlUuid)]
        sid: Uuid,
        #[diesel(sql_type = Text)]
        app_name: String,
        #[diesel(sql_type = Nullable<Double>)]
        val: Option<f64>,
    }

    let query = if let Some(app) = app_name {
        diesel::sql_query(sql)
            .bind::<SqlUuid, _>(user_id)
            .bind::<Text, _>(start_date.to_string())
            .bind::<Text, _>(end_date.to_string())
            .bind::<Text, _>(app.to_string())
    } else {
        diesel::sql_query(sql)
            .bind::<SqlUuid, _>(user_id)
            .bind::<Text, _>(start_date.to_string())
            .bind::<Text, _>(end_date.to_string())
    };

    let rows = query.load::<TrendRow>(&mut *client).await?;

    Ok(rows
        .into_iter()
        .map(|r| TrendPoint {
            timestamp: r.ts,
            session_id: r.sid,
            app_name: r.app_name,
            value: r.val,
            label: Some(jsonb_key.to_string()),
        })
        .collect())
}

// Dummy tables for QueryableByName derive
diesel::table! {
    trend_query (id) {
        id -> Int4,
    }
}

diesel::table! {
    trend_query2 (id) {
        id -> Int4,
    }
}
