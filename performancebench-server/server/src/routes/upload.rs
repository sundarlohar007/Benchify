use axum::extract::{Multipart, State};
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::{Extension, Json};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use db::{alert_queries, device_queries, session_queries};
use db::session_queries::NewSession;
use models::detected_issue::DetectedIssue;
use models::marker::Marker;
use models::metric_sample::MetricSample;
use models::session::Session;
use models::video::VideoMetadata;
use crate::error::AppError;
use crate::services::analytics;
// TODO: Re-enable after fixing lettre API
// use crate::services::notifications::{
//     dispatch_notification, NotificationChannel, NotificationPayload,
// };
use crate::state::AppState;
use crate::utils::jwt::AuthUser;

/// Upload payload structure matching export_service.dart format (D-30).
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct UploadPayload {
    session: SessionPayload,
    samples: Vec<MetricSample>,
    #[serde(default)]
    markers: Vec<Marker>,
    #[serde(default)]
    detected_issues: Vec<DetectedIssue>,
    #[serde(default)]
    video_metadata: Vec<VideoMetadata>,
}

/// Session data portion of the upload payload.
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct SessionPayload {
    id: Uuid,
    app_name: String,
    #[serde(default)]
    app_package: Option<String>,
    #[serde(default)]
    app_version: Option<String>,
    #[serde(default)]
    device_model: Option<String>,
    #[serde(default)]
    device_os_version: Option<String>,
    #[serde(default)]
    chipset: Option<String>,
    #[serde(default)]
    tags: Vec<String>,
    #[serde(default)]
    project_id: Option<String>,
    #[serde(default)]
    collection_id: Option<Uuid>,
    #[serde(default)]
    notes: Option<String>,
    started_at: String,
    #[serde(default)]
    ended_at: Option<String>,
    #[serde(default)]
    duration_seconds: Option<i32>,
    #[serde(default)]
    screenshots: Vec<String>,
    #[serde(default)]
    thumbnail_path: Option<String>,
    #[serde(default)]
    devices: Option<Vec<UploadDevice>>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct UploadDevice {
    #[serde(default)]
    name: Option<String>,
    #[serde(default)]
    model: Option<String>,
    os_type: String,
    #[serde(default)]
    os_version: Option<String>,
    #[serde(default)]
    chipset: Option<String>,
    #[serde(default)]
    serial_number: Option<String>,
}

/// POST /api/v1/sessions — Multipart session upload endpoint (D-20, D-21, D-25).
///
/// Accepts multipart body with:
/// - Field "metadata": JSON string containing UploadPayload
/// - Field "screenshots": Multiple binary .png files (optional, D-21)
///
/// Auth: API token Bearer (validated by api_token middleware).
pub async fn upload_session(
    State(state): State<AppState>,
    Extension(auth_user): Extension<AuthUser>,
    mut multipart: Multipart,
) -> Result<impl IntoResponse, AppError> {
    // Only users with write scope or admin can upload
    if auth_user.role != "write" && auth_user.role != "admin" {
        return Err(AppError::Forbidden);
    }

    let mut metadata_json: Option<String> = None;
    let mut screenshot_files: Vec<(String, Vec<u8>)> = Vec::new();

    // Stream multipart fields
    while let Ok(Some(field)) = multipart.next_field().await {
        let name = field.name().unwrap_or("").to_string();

        match name.as_str() {
            "metadata" => {
                let bytes = field.bytes().await
                    .map_err(|e| AppError::Validation(format!("Failed to read metadata: {}", e)))?;
                metadata_json = Some(String::from_utf8(bytes.to_vec())
                    .map_err(|e| AppError::Validation(format!("Invalid UTF-8 in metadata: {}", e)))?);
            }
            "screenshots" => {
                let filename = field.file_name()
                    .unwrap_or("unknown.png")
                    .to_string();
                let bytes = field.bytes().await
                    .map_err(|e| AppError::Validation(format!("Failed to read screenshot: {}", e)))?;
                screenshot_files.push((filename, bytes.to_vec()));
            }
            _ => {
                // Skip unknown fields
                tracing::debug!(field_name = %name, "Skipping unknown multipart field");
                continue;
            }
        }
    }

    let metadata_str = metadata_json.ok_or_else(|| {
        AppError::Validation("Missing 'metadata' field in multipart body".to_string())
    })?;

    // Parse the upload payload
    let payload: UploadPayload = serde_json::from_str(&metadata_str)
        .map_err(|e| AppError::Validation(format!("Invalid upload payload: {}", e)))?;

    let session_id = payload.session.id;

    // ── Check for duplicate (D-25) ──
    let exists = session_queries::session_exists(&state.pool, session_id)
        .await
        .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?;

    if exists {
        let existing_url = format!("/api/v1/sessions/{}", session_id);
        return Ok((
            StatusCode::CONFLICT,
            Json(serde_json::json!({
                "code": "CONFLICT",
                "message": "Session already uploaded",
                "existing_url": existing_url,
            })),
        ));
    }

    // ── Upsert device info if provided ──
    let device_id: Option<Uuid> = if let Some(devices) = &payload.session.devices {
        if let Some(dev) = devices.first() {
            match device_queries::upsert_device(
                &state.pool,
                dev.name.as_deref(),
                dev.model.as_deref(),
                &dev.os_type,
                dev.os_version.as_deref(),
                dev.chipset.as_deref(),
                dev.serial_number.as_deref(),
            )
            .await
            {
                Ok(device) => Some(device.id),
                Err(e) => {
                    tracing::warn!(error = %e, "Failed to upsert device");
                    None
                }
            }
        } else {
            None
        }
    } else {
        None
    };

    // ── Parse timestamps ──
    let started_at = parse_timestamp(&payload.session.started_at)
        .unwrap_or_else(|| chrono::Utc::now().naive_utc());
    let ended_at = payload.session.ended_at.as_deref()
        .and_then(parse_timestamp);
    let now = chrono::Utc::now().naive_utc();

    // ── Serialize JSONB fields ──
    let metric_samples_str = serde_json::to_string(&payload.samples)
        .unwrap_or_else(|_| "[]".to_string());
    let markers_str = serde_json::to_string(&payload.markers)
        .unwrap_or_else(|_| "[]".to_string());
    let detected_issues_str = serde_json::to_string(&payload.detected_issues)
        .unwrap_or_else(|_| "[]".to_string());
    let video_metadata_str = if payload.video_metadata.is_empty() {
        None
    } else {
        Some(serde_json::to_string(&payload.video_metadata).unwrap_or_else(|_| "[]".to_string()))
    };

    // Start with empty session_stats — will be recomputed in background
    let empty_stats = serde_json::json!({});

    // ── Insert session ──
    let new_session = NewSession {
        id: session_id,
        user_id: auth_user.user_id,
        device_id,
        app_name: payload.session.app_name,
        app_package: payload.session.app_package,
        app_version: payload.session.app_version,
        device_model: payload.session.device_model,
        device_os_version: payload.session.device_os_version,
        chipset: payload.session.chipset,
        tags: payload.session.tags,
        project_id: payload.session.project_id,
        collection_id: payload.session.collection_id,
        notes: payload.session.notes,
        started_at,
        ended_at,
        duration_seconds: payload.session.duration_seconds,
        session_stats_str: serde_json::to_string(&empty_stats).unwrap_or_else(|_| "{}".to_string()),
        metric_samples_str,
        markers_str,
        detected_issues_str,
        screenshots: payload.session.screenshots.clone(),
        video_metadata_str,
        thumbnail_path: payload.session.thumbnail_path,
        is_uploaded: true,
        uploaded_by: Some(auth_user.user_id),
        uploaded_at: Some(now),
    };

    let inserted_session = session_queries::insert_session(&state.pool, &new_session)
        .await
        .map_err(|e| AppError::Internal(format!("Failed to insert session: {}", e)))?;

    // ── Save screenshot files to disk (D-14, D-21) ──
    if !screenshot_files.is_empty() {
        let screenshot_dir = format!("{}/{}", state.config.upload_dir, session_id);
        if let Err(e) = std::fs::create_dir_all(&screenshot_dir) {
            tracing::warn!(error = %e, directory = %screenshot_dir, "Failed to create screenshot directory");
        } else {
            for (filename, data) in &screenshot_files {
                let path = format!("{}/{}", screenshot_dir, filename);
                if let Err(e) = std::fs::write(&path, data) {
                    tracing::warn!(error = %e, path = %path, "Failed to save screenshot");
                }
            }
            tracing::info!(
                session_id = %session_id,
                screenshot_count = screenshot_files.len(),
                "Screenshots saved"
            );
        }
    }

    // ── Background recomputation of session_stats (D-10, D-18) ──
    let pool_clone = state.pool.clone();
    let config_clone = state.config.clone();
    let sid = session_id;
    let uploaded_samples = payload.samples.clone();
    let uploaded_markers = payload.markers.clone();

    tokio::spawn(async move {
        // Compute stats from raw samples
        let duration_ms = if uploaded_samples.len() >= 2 {
            uploaded_samples[uploaded_samples.len() - 1].timestamp - uploaded_samples[0].timestamp
        } else {
            0
        };

        let stats = analytics::compute_session_stats(
            &uploaded_samples,
            sid,
            duration_ms,
            &uploaded_markers,
        );

        // Serialize to JSON for storage
        let stats_json = serde_json::to_value(&stats).unwrap_or_default();

        // Update in database
        if let Err(e) = session_queries::update_session_stats(&pool_clone, sid, stats_json).await {
            tracing::error!(
                session_id = %sid,
                error = %e,
                "Failed to update session stats after recomputation"
            );
        }

        // ── Alert evaluation (D-14): Evaluate active alert rules against session_stats ──
        match alert_queries::list_active_alert_rules(&pool_clone).await {
            Ok(rules) => {
                for rule in rules {
                    let metric_value = extract_metric_value(&stats, &rule.metric_name);
                    if let Some(value) = metric_value {
                        let triggered = match rule.condition.as_str() {
                            "lt" => value < rule.threshold,
                            "gt" => value > rule.threshold,
                            "lte" => value <= rule.threshold,
                            "gte" => value >= rule.threshold,
                            _ => false,
                        };
                        if triggered {
                            // Create alert event
                            if let Ok(event) = alert_queries::create_alert_event(
                                &pool_clone,
                                rule.id,
                                Some(sid),
                                value,
                                rule.threshold,
                            )
                            .await
                            {
                                tracing::info!(
                                    rule_id = %rule.id,
                                    alert_event_id = %event.id,
                                    session_id = %sid,
                                    metric = %rule.metric_name,
                                    value = value,
                                    threshold = rule.threshold,
                                    "Alert rule triggered"
                                );

                                // TODO: Re-enable notification dispatch after fixing lettre API
                                // Notification dispatch disabled temporarily
                            }
                        }
                    }
                }
            }
            Err(e) => {
                tracing::error!(?e, session_id = %sid, "Failed to evaluate alert rules");
            }
        }
    });

    // ── Return 201 Created with session URL ──
    tracing::info!(
        session_id = %session_id,
        user_id = %auth_user.user_id,
        sample_count = payload.samples.len(),
        duration_ms = payload.samples.last()
            .map(|s| s.timestamp - payload.samples[0].timestamp)
            .unwrap_or(0),
        "session uploaded"
    );

    let response = serde_json::json!({
        "id": session_id,
        "url": format!("/api/v1/sessions/{}", session_id),
    });

    Ok((StatusCode::CREATED, Json(response)))
}

/// Parse an ISO 8601 timestamp string to NaiveDateTime.
/// Tries multiple common formats.
fn parse_timestamp(s: &str) -> Option<chrono::NaiveDateTime> {
    // Try with timezone info first (strip it)
    let cleaned = s
        .trim_end_matches('Z')
        .trim_end_matches("+00:00")
        .trim_end_matches("-00:00");

    // Try standard ISO 8601
    if let Ok(dt) = chrono::NaiveDateTime::parse_from_str(cleaned, "%Y-%m-%dT%H:%M:%S") {
        return Some(dt);
    }
    // Try with fractional seconds
    if let Ok(dt) = chrono::NaiveDateTime::parse_from_str(cleaned, "%Y-%m-%dT%H:%M:%S%.f") {
        return Some(dt);
    }
    // Try RFC 3339 via DateTime
    if let Ok(dt) = chrono::DateTime::parse_from_rfc3339(s) {
        return Some(dt.naive_utc());
    }
    // Try DateTime with Z
    if let Ok(dt) = chrono::DateTime::parse_from_str(s, "%Y-%m-%dT%H:%M:%SZ") {
        return Some(dt.naive_utc());
    }
    if let Ok(dt) = chrono::DateTime::parse_from_str(s, "%Y-%m-%dT%H:%M:%S%.fZ") {
        return Some(dt.naive_utc());
    }

    tracing::warn!(timestamp = %s, "Could not parse timestamp");
    None
}

/// Extract a metric value from computed SessionStats by name.
/// Maps alert rule metric_name strings to SessionStats fields.
fn extract_metric_value(
    stats: &models::session::SessionStats,
    metric_name: &str,
) -> Option<f64> {
    match metric_name {
        "fps_median" => stats.fps_median,
        "fps_stability" => stats.fps_stability,
        "fps_min" => stats.fps_min,
        "cpu_avg_pct" => stats.cpu_avg_pct,
        "cpu_peak_pct" => stats.cpu_peak_pct,
        "memory_avg_kb" => stats.memory_avg_kb.map(|v| v as f64),
        "memory_peak_kb" => stats.memory_peak_kb.map(|v| v as f64),
        "gpu_avg_pct" => stats.gpu_avg_pct,
        "battery_drain_pct" => stats.battery_drain_pct,
        "battery_temp_max_c" => stats.battery_temp_max_c,
        "jank_per_min" => stats.jank_per_min,
        "thermal_peak" => stats.thermal_peak.map(|v| v as f64),
        _ => None,
    }
}
