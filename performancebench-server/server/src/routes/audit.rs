use axum::extract::{Path, Query, State};
use axum::http::header;
use axum::response::{IntoResponse, Response};
use axum::routing::{delete, get};
use axum::{Extension, Json, Router};
use serde::Deserialize;
use serde_json::json;
use uuid::Uuid;

use crate::error::AppError;
use crate::middleware::audit as audit_mw;
use crate::state::AppState;
use crate::utils::jwt::AuthUser;
use db::audit_queries;
use db::audit_queries::AuditFilter;
use models::audit::{AuditEventCategory, AuditEventResponse, AuditEventType};

// ── Request types ──

#[derive(Debug, Deserialize)]
pub struct AuditListQuery {
    pub category: Option<String>,
    #[serde(rename = "eventType")]
    pub event_type: Option<String>,
    #[serde(rename = "actorId")]
    pub actor_id: Option<Uuid>,
    pub from: Option<String>,
    pub to: Option<String>,
    #[serde(default = "default_offset")]
    pub offset: i64,
    #[serde(default = "default_limit")]
    pub limit: i64,
}

#[derive(Debug, Deserialize)]
pub struct AuditExportQuery {
    pub format: String,
    pub from: Option<String>,
    pub to: Option<String>,
    pub category: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct AuditPurgeQuery {
    pub before: String,
}

fn default_offset() -> i64 {
    0
}
fn default_limit() -> i64 {
    50
}

fn parse_iso_date(s: &str) -> Result<chrono::NaiveDateTime, AppError> {
    chrono::NaiveDateTime::parse_from_str(s, "%Y-%m-%dT%H:%M:%S")
        .or_else(|_| chrono::NaiveDateTime::parse_from_str(s, "%Y-%m-%d"))
        .map_err(|e| {
            AppError::Validation(format!(
                "Invalid date format: {}. Use ISO 8601 (YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS)",
                e
            ))
        })
}

// ── Router ──

pub fn audit_router() -> Router<AppState> {
    Router::new()
        .route("/events", get(list_audit_events))
        .route("/events/{id}", get(get_audit_event))
        .route("/export", get(export_audit_events))
        .route("/events", delete(purge_audit_events))
}

// ── Handlers ──

/// GET /api/v1/audit/events — paginated list with optional filters.
async fn list_audit_events(
    State(state): State<AppState>,
    Query(params): Query<AuditListQuery>,
) -> Result<Json<serde_json::Value>, AppError> {
    let filter = AuditFilter {
        event_category: params.category,
        event_type: params.event_type,
        actor_id: params.actor_id,
        target_type: None,
        target_id: None,
        from_date: params.from.as_deref().map(parse_iso_date).transpose()?,
        to_date: params.to.as_deref().map(parse_iso_date).transpose()?,
    };

    let (events, total) =
        audit_queries::get_audit_events(&state.pool, &filter, params.offset, params.limit)
            .await
            .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?;

    let event_responses: Vec<AuditEventResponse> =
        events.into_iter().map(AuditEventResponse::from).collect();

    Ok(Json(json!({
        "events": event_responses,
        "total": total,
        "offset": params.offset,
        "limit": params.limit,
    })))
}

/// GET /api/v1/audit/events/{id} — single event detail.
async fn get_audit_event(
    State(state): State<AppState>,
    Path(event_id): Path<Uuid>,
) -> Result<Json<AuditEventResponse>, AppError> {
    let event = audit_queries::get_audit_event_by_id(&state.pool, event_id)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?
        .ok_or_else(|| AppError::NotFound("Audit event".to_string()))?;

    Ok(Json(AuditEventResponse::from(event)))
}

/// GET /api/v1/audit/export?format=csv|json&from=...&to=...&category=...
async fn export_audit_events(
    State(state): State<AppState>,
    Extension(auth_user): Extension<AuthUser>,
    Query(params): Query<AuditExportQuery>,
) -> Result<Response, AppError> {
    // Validate format
    let format_lower = params.format.to_lowercase();
    if format_lower != "csv" && format_lower != "json" {
        return Err(AppError::Validation(
            "Invalid format. Must be 'csv' or 'json'.".to_string(),
        ));
    }

    // Default date range: last 30 days if not specified
    let now = chrono::Utc::now().naive_utc();
    let default_from = now - chrono::Duration::days(30);
    let from_date = params
        .from
        .as_deref()
        .map(parse_iso_date)
        .transpose()?
        .unwrap_or(default_from);
    let to_date = params
        .to
        .as_deref()
        .map(parse_iso_date)
        .transpose()?
        .unwrap_or(now);

    let categories: Option<Vec<String>> = params
        .category
        .map(|c| c.split(',').map(|s| s.trim().to_string()).collect());

    let events = audit_queries::get_audit_events_range(&state.pool, from_date, to_date, categories)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?;

    // Record meta audit event for export
    let _ = audit_mw::record_audit_event(
        &state.pool,
        Some(&auth_user),
        AuditEventType::AuditExported,
        AuditEventCategory::Export,
        None,
        None,
        json!({
            "format": format_lower,
            "event_count": events.len(),
            "from": from_date.to_string(),
            "to": to_date.to_string(),
        }),
    )
    .await;

    let date_str = chrono::Utc::now().format("%Y-%m-%d").to_string();

    match format_lower.as_str() {
        "csv" => {
            let mut wtr = csv::Writer::from_writer(Vec::new());

            // Header
            let _ = wtr.write_record(&[
                "id",
                "event_type",
                "event_category",
                "actor_id",
                "actor_email",
                "target_type",
                "target_id",
                "details",
                "ip_address",
                "created_at",
            ]);

            for event in &events {
                let _ = wtr.write_record(&[
                    event.id.to_string(),
                    event.event_type.clone(),
                    event.event_category.clone(),
                    event.actor_id.map(|id| id.to_string()).unwrap_or_default(),
                    event.actor_email.clone().unwrap_or_default(),
                    event.target_type.clone().unwrap_or_default(),
                    event.target_id.map(|id| id.to_string()).unwrap_or_default(),
                    event.details.to_string(),
                    event.ip_address.clone().unwrap_or_default(),
                    event.created_at.to_string(),
                ]);
            }

            let csv_data = wtr
                .into_inner()
                .map_err(|e| AppError::Internal(format!("CSV write error: {}", e)))?;

            let filename = format!("audit-export-{}.csv", date_str);

            let response = Response::builder()
                .header(header::CONTENT_TYPE, "text/csv; charset=utf-8")
                .header(
                    header::CONTENT_DISPOSITION,
                    format!("attachment; filename=\"{}\"", filename),
                )
                .body(axum::body::Body::from(csv_data))
                .map_err(|e| AppError::Internal(format!("Response build error: {}", e)))?;

            Ok(response)
        }
        "json" => {
            let json_data = serde_json::to_vec(&events)
                .map_err(|e| AppError::Internal(format!("JSON serialize error: {}", e)))?;

            let filename = format!("audit-export-{}.json", date_str);

            let response = Response::builder()
                .header(header::CONTENT_TYPE, "application/json; charset=utf-8")
                .header(
                    header::CONTENT_DISPOSITION,
                    format!("attachment; filename=\"{}\"", filename),
                )
                .body(axum::body::Body::from(json_data))
                .map_err(|e| AppError::Internal(format!("Response build error: {}", e)))?;

            Ok(response)
        }
        _ => unreachable!("format already validated"),
    }
}

/// DELETE /api/v1/audit/events?before=2025-01-01 — purge events older than date.
/// Admin only. Records a meta-audit event for the purge itself.
async fn purge_audit_events(
    State(state): State<AppState>,
    Extension(auth_user): Extension<AuthUser>,
    Query(params): Query<AuditPurgeQuery>,
) -> Result<Json<serde_json::Value>, AppError> {
    let before_date = parse_iso_date(&params.before)?;

    // Minimum 30-day retention window (T-06-12)
    let now = chrono::Utc::now().naive_utc();
    let min_retain_date = now - chrono::Duration::days(30);
    if before_date > min_retain_date {
        return Err(AppError::Validation(format!(
            "Purge date must be at least 30 days in the past. Earliest allowed: {}",
            min_retain_date.format("%Y-%m-%d")
        )));
    }

    let deleted_count = audit_queries::delete_audit_events_before(&state.pool, before_date)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?;

    // Record meta-audit event for the purge operation
    let _ = audit_mw::record_audit_event(
        &state.pool,
        Some(&auth_user),
        AuditEventType::RetentionPurge,
        AuditEventCategory::System,
        None,
        None,
        json!({
            "purged_before": before_date.to_string(),
            "deleted_count": deleted_count,
        }),
    )
    .await;

    Ok(Json(json!({
        "deleted_count": deleted_count,
        "purged_before": before_date.to_string(),
    })))
}

// ── Tests ──

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Datelike;

    #[test]
    fn test_parse_iso_date_valid() {
        let result = parse_iso_date("2025-01-01");
        assert!(result.is_ok());
        let dt = result.unwrap();
        assert_eq!(dt.year(), 2025);
        assert_eq!(dt.month(), 1);
        assert_eq!(dt.day(), 1);
    }

    #[test]
    fn test_parse_iso_date_valid_datetime() {
        let result = parse_iso_date("2025-01-01T12:00:00");
        assert!(result.is_ok());
    }

    #[test]
    fn test_parse_iso_date_invalid() {
        let result = parse_iso_date("not-a-date");
        assert!(result.is_err());
    }

    #[test]
    fn test_parse_iso_date_empty() {
        let result = parse_iso_date("");
        assert!(result.is_err());
    }
}
