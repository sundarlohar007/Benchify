use diesel::prelude::*;
use diesel_async::RunQueryDsl;
use models::audit::{AuditEvent, CreateAuditEvent};
use uuid::Uuid;

use crate::connection::DbPool;
use crate::schema::audit_events;

type DbResult<T> = Result<T, Box<dyn std::error::Error + Send + Sync>>;

// ── Filters ──

/// Optional filters for querying audit events.
pub struct AuditFilter {
    pub event_category: Option<String>,
    pub event_type: Option<String>,
    pub actor_id: Option<Uuid>,
    pub target_type: Option<String>,
    pub target_id: Option<Uuid>,
    pub from_date: Option<chrono::NaiveDateTime>,
    pub to_date: Option<chrono::NaiveDateTime>,
}

impl Default for AuditFilter {
    fn default() -> Self {
        Self {
            event_category: None,
            event_type: None,
            actor_id: None,
            target_type: None,
            target_id: None,
            from_date: None,
            to_date: None,
        }
    }
}

/// Apply optional filter fields to a boxed audit_events query.
fn apply_filters<'a>(
    mut query: audit_events::BoxedQuery<'a, diesel::pg::Pg>,
    filter: &AuditFilter,
) -> audit_events::BoxedQuery<'a, diesel::pg::Pg> {
    if let Some(ref cat) = filter.event_category {
        query = query.filter(audit_events::event_category.eq(cat.clone()));
    }
    if let Some(ref ev_type) = filter.event_type {
        query = query.filter(audit_events::event_type.eq(ev_type.clone()));
    }
    if let Some(actor_id) = filter.actor_id {
        query = query.filter(audit_events::actor_id.eq(actor_id));
    }
    if let Some(ref target_type) = filter.target_type {
        query = query.filter(audit_events::target_type.eq(target_type.clone()));
    }
    if let Some(target_id) = filter.target_id {
        query = query.filter(audit_events::target_id.eq(target_id));
    }
    if let Some(from) = filter.from_date {
        query = query.filter(audit_events::created_at.ge(from));
    }
    if let Some(to) = filter.to_date {
        query = query.filter(audit_events::created_at.le(to));
    }
    query
}

// ── Queries ──

/// Insert an audit event. Returns the created event.
/// Callers should use fire-and-forget: `let _ = insert_audit_event(...).await;`
pub async fn insert_audit_event(pool: &DbPool, event: CreateAuditEvent) -> DbResult<AuditEvent> {
    let mut client = pool.get().await?;
    let result = diesel::insert_into(audit_events::table)
        .values(&event)
        .get_result::<AuditEvent>(&mut *client)
        .await?;
    Ok(result)
}

/// Get paginated audit events with optional filters.
/// Returns (events, total_count).
pub async fn get_audit_events(
    pool: &DbPool,
    filter: &AuditFilter,
    offset: i64,
    limit: i64,
) -> DbResult<(Vec<AuditEvent>, i64)> {
    let mut client = pool.get().await?;

    // Count query
    let count_query = apply_filters(audit_events::table.into_boxed(), filter);
    let total: i64 = count_query.count().get_result(&mut *client).await?;

    // Data query
    let data_query = apply_filters(audit_events::table.into_boxed(), filter);
    let events = data_query
        .order(audit_events::created_at.desc())
        .offset(offset)
        .limit(limit)
        .load::<AuditEvent>(&mut *client)
        .await?;

    Ok((events, total))
}

/// Get audit events within a date range for export (no pagination).
pub async fn get_audit_events_range(
    pool: &DbPool,
    start_date: chrono::NaiveDateTime,
    end_date: chrono::NaiveDateTime,
    categories: Option<Vec<String>>,
) -> DbResult<Vec<AuditEvent>> {
    let mut client = pool.get().await?;

    let mut query = audit_events::table
        .filter(audit_events::created_at.ge(start_date))
        .filter(audit_events::created_at.le(end_date))
        .into_boxed();

    if let Some(cats) = categories {
        if !cats.is_empty() {
            query = query.filter(audit_events::event_category.eq_any(cats));
        }
    }

    let events = query
        .order(audit_events::created_at.asc())
        .load::<AuditEvent>(&mut *client)
        .await?;

    Ok(events)
}

/// Delete audit events older than the specified date.
/// Returns the number of deleted rows.
pub async fn delete_audit_events_before(
    pool: &DbPool,
    before_date: chrono::NaiveDateTime,
) -> DbResult<u64> {
    let mut client = pool.get().await?;

    let deleted =
        diesel::delete(audit_events::table.filter(audit_events::created_at.lt(before_date)))
            .execute(&mut *client)
            .await?;

    Ok(deleted as u64)
}

/// Get a single audit event by id.
pub async fn get_audit_event_by_id(pool: &DbPool, event_id: Uuid) -> DbResult<Option<AuditEvent>> {
    let mut client = pool.get().await?;
    let result = audit_events::table
        .find(event_id)
        .first::<AuditEvent>(&mut *client)
        .await
        .optional()?;
    Ok(result)
}

// ── Tests ──

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_audit_filter_defaults() {
        let filter = AuditFilter::default();
        assert!(filter.event_category.is_none());
        assert!(filter.event_type.is_none());
        assert!(filter.actor_id.is_none());
        assert!(filter.target_type.is_none());
        assert!(filter.target_id.is_none());
        assert!(filter.from_date.is_none());
        assert!(filter.to_date.is_none());
    }

    #[test]
    fn test_audit_filter_with_category() {
        let filter = AuditFilter {
            event_category: Some("auth".to_string()),
            ..AuditFilter::default()
        };
        assert_eq!(filter.event_category, Some("auth".to_string()));
    }

    #[test]
    fn test_create_audit_event_fields() {
        let event = CreateAuditEvent {
            event_type: "login".to_string(),
            event_category: "auth".to_string(),
            actor_id: Some(Uuid::new_v4()),
            actor_email: Some("test@example.com".to_string()),
            target_type: None,
            target_id: None,
            details: serde_json::json!({"success": true}),
            ip_address: Some("127.0.0.1".to_string()),
            user_agent: Some("test".to_string()),
        };
        assert_eq!(event.event_type, "login");
    }
}
