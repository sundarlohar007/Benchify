use diesel::prelude::*;
use diesel_async::RunQueryDsl;
use models::alert::{AlertEvent, AlertRule};
use serde_json;
use uuid::Uuid;

use crate::connection::DbPool;
use crate::schema::{alert_events, alert_rules};

type DbResult<T> = Result<T, Box<dyn std::error::Error + Send + Sync>>;

// ── Alert Rules ──

/// List alert rules for a user.
pub async fn list_alert_rules(pool: &DbPool, user_id: Uuid) -> DbResult<Vec<AlertRule>> {
    let mut client = pool.get().await?;
    let result = alert_rules::table
        .filter(alert_rules::user_id.eq(user_id))
        .order(alert_rules::created_at.desc())
        .load::<AlertRule>(&mut *client)
        .await?;
    Ok(result)
}

/// Get a single alert rule by ID.
pub async fn get_alert_rule(pool: &DbPool, rule_id: Uuid) -> DbResult<Option<AlertRule>> {
    let mut client = pool.get().await?;
    let result = alert_rules::table
        .find(rule_id)
        .first::<AlertRule>(&mut *client)
        .await
        .optional()?;
    Ok(result)
}

/// Create a new alert rule.
pub async fn create_alert_rule(
    pool: &DbPool,
    user_id: Uuid,
    name: &str,
    metric_name: &str,
    condition: &str,
    threshold: f64,
    duration_seconds: i32,
    channels: serde_json::Value,
) -> DbResult<AlertRule> {
    let mut client = pool.get().await?;
    let new_id = Uuid::new_v4();
    let now = chrono::Utc::now().naive_utc();

    let result = diesel::insert_into(alert_rules::table)
        .values((
            alert_rules::id.eq(new_id),
            alert_rules::user_id.eq(user_id),
            alert_rules::name.eq(name),
            alert_rules::metric_name.eq(metric_name),
            alert_rules::condition.eq(condition),
            alert_rules::threshold.eq(threshold),
            alert_rules::duration_seconds.eq(duration_seconds),
            alert_rules::channels.eq(channels),
            alert_rules::is_active.eq(true),
            alert_rules::created_at.eq(now),
            alert_rules::updated_at.eq(now),
        ))
        .get_result::<AlertRule>(&mut *client)
        .await?;
    Ok(result)
}

/// Update an existing alert rule (owner-scoped).
pub async fn update_alert_rule(
    pool: &DbPool,
    rule_id: Uuid,
    user_id: Uuid,
    name: Option<&str>,
    metric_name: Option<&str>,
    condition: Option<&str>,
    threshold: Option<f64>,
    duration_seconds: Option<i32>,
    channels: Option<serde_json::Value>,
    is_active: Option<bool>,
) -> DbResult<Option<AlertRule>> {
    let mut client = pool.get().await?;

    // Check ownership
    let existing = alert_rules::table
        .filter(alert_rules::id.eq(rule_id))
        .filter(alert_rules::user_id.eq(user_id))
        .first::<AlertRule>(&mut *client)
        .await
        .optional()?;

    if existing.is_none() {
        return Ok(None);
    }

    let target = alert_rules::table
        .filter(alert_rules::id.eq(rule_id))
        .filter(alert_rules::user_id.eq(user_id));

    let now = chrono::Utc::now().naive_utc();
    let mut update = diesel::update(target).into_boxed();

    if let Some(n) = name {
        update = update.set(alert_rules::name.eq(n));
    }
    if let Some(m) = metric_name {
        update = update.set(alert_rules::metric_name.eq(m));
    }
    if let Some(c) = condition {
        update = update.set(alert_rules::condition.eq(c));
    }
    if let Some(t) = threshold {
        update = update.set(alert_rules::threshold.eq(t));
    }
    if let Some(d) = duration_seconds {
        update = update.set(alert_rules::duration_seconds.eq(d));
    }
    if let Some(ch) = channels {
        update = update.set(alert_rules::channels.eq(ch));
    }
    if let Some(a) = is_active {
        update = update.set(alert_rules::is_active.eq(a));
    }
    update = update.set(alert_rules::updated_at.eq(now));

    let result = update.get_result::<AlertRule>(&mut *client).await?;
    Ok(Some(result))
}

/// Delete an alert rule (owner-scoped).
pub async fn delete_alert_rule(pool: &DbPool, rule_id: Uuid, user_id: Uuid) -> DbResult<()> {
    let mut client = pool.get().await?;
    diesel::delete(
        alert_rules::table
            .filter(alert_rules::id.eq(rule_id))
            .filter(alert_rules::user_id.eq(user_id)),
    )
    .execute(&mut *client)
    .await?;
    Ok(())
}

// ── Alert Events ──

/// List all active alert rules across all users (for evaluation engine).
/// No user_id filter — used internally by alert evaluation triggered after session upload.
pub async fn list_active_alert_rules(pool: &DbPool) -> DbResult<Vec<AlertRule>> {
    let mut client = pool.get().await?;
    let result = alert_rules::table
        .filter(alert_rules::is_active.eq(true))
        .load::<AlertRule>(&mut *client)
        .await?;
    Ok(result)
}

/// Create a new alert event (fired when a metric exceeds threshold).
pub async fn create_alert_event(
    pool: &DbPool,
    rule_id: Uuid,
    session_id: Option<Uuid>,
    metric_value: f64,
    threshold: f64,
) -> DbResult<AlertEvent> {
    let mut client = pool.get().await?;
    let new_id = Uuid::new_v4();
    let now = chrono::Utc::now().naive_utc();

    let result = diesel::insert_into(alert_events::table)
        .values((
            alert_events::id.eq(new_id),
            alert_events::rule_id.eq(rule_id),
            alert_events::session_id.eq(session_id),
            alert_events::metric_value.eq(metric_value),
            alert_events::threshold.eq(threshold),
            alert_events::fired_at.eq(now),
        ))
        .get_result::<AlertEvent>(&mut *client)
        .await?;
    Ok(result)
}

/// List alert events with optional filters.
pub async fn list_alert_events(
    pool: &DbPool,
    rule_id: Option<Uuid>,
    session_id: Option<Uuid>,
    severity: Option<&str>,
    limit: i64,
    offset: i64,
) -> DbResult<Vec<AlertEvent>> {
    let mut client = pool.get().await?;

    let mut query = alert_events::table.into_boxed();

    if let Some(rid) = rule_id {
        query = query.filter(alert_events::rule_id.eq(rid));
    }
    if let Some(sid) = session_id {
        query = query.filter(alert_events::session_id.eq(sid));
    }

    // Severity filtering is done via rule join if needed; skip for now
    let _ = severity;

    let result = query
        .order(alert_events::fired_at.desc())
        .limit(limit)
        .offset(offset)
        .load::<AlertEvent>(&mut *client)
        .await?;
    Ok(result)
}
