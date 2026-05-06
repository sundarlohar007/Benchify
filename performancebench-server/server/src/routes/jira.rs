use axum::extract::{Path, State};
use axum::response::IntoResponse;
use axum::{Extension, Json};
use reqwest::StatusCode;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use db::session_queries;
use models::audit::{AuditEventCategory, AuditEventType};
use crate::error::AppError;
use crate::middleware::audit as audit_mw;
use crate::state::AppState;
use crate::utils::jwt::AuthUser;

// ── Request / Response types ──

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateJiraIssueRequest {
    pub project_key: String,
    #[serde(default = "default_issue_type")]
    pub issue_type: String,
    /// Auto-generated if empty — includes FPS avg, CPU avg, memory peak, duration.
    pub summary: Option<String>,
    #[serde(default)]
    pub labels: Vec<String>,
}

fn default_issue_type() -> String {
    "Bug".to_string()
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateJiraIssueResponse {
    pub issue_key: String,
    pub issue_url: String,
}

/// POST /api/v1/sessions/{session_id}/jira
///
/// Creates a Jira issue with pre-filled performance data from the session.
/// Requires Jira integration to be configured (JIRA_ENABLED=true + JIRA_BASE_URL/JIRA_EMAIL/JIRA_API_TOKEN).
/// Requires Operator role (session write access).
pub async fn create_jira_issue(
    State(state): State<AppState>,
    Path(session_id): Path<Uuid>,
    Extension(auth_user): Extension<AuthUser>,
    Json(body): Json<CreateJiraIssueRequest>,
) -> Result<impl IntoResponse, AppError> {
    // 1. Check Jira config
    if !state.config.jira_enabled
        || state.config.jira_base_url.is_none()
        || state.config.jira_email.is_none()
        || state.config.jira_api_token.is_none()
    {
        return Err(AppError::Validation(
            "Jira integration not configured. Set JIRA_ENABLED=true and configure JIRA_BASE_URL, JIRA_EMAIL, JIRA_API_TOKEN."
                .to_string(),
        ));
    }

    let jira_base_url = state.config.jira_base_url.as_ref().unwrap();
    let jira_email = state.config.jira_email.as_ref().unwrap();
    let jira_api_token = state.config.jira_api_token.as_ref().unwrap();

    // 2. Load session with stats
    let session = session_queries::get_session_by_id_and_user(
        &state.pool,
        session_id,
        auth_user.user_id,
    )
    .await
    .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?
    .ok_or_else(|| AppError::NotFound("Session".to_string()))?;

    // 3. Generate summary if not provided
    let summary = body.summary.clone().unwrap_or_else(|| {
        generate_summary(&session)
    });

    // 4. Build Jira ADF description
    let description = build_adf_description(&session);

    // 5. Build Jira API payload (v3 format)
    let jira_payload = serde_json::json!({
        "fields": {
            "project": { "key": body.project_key },
            "issuetype": { "name": body.issue_type },
            "summary": summary,
            "description": description,
            "labels": {
                let mut labels = body.labels.clone();
                if !labels.iter().any(|l| l == "performance") {
                    labels.push("performance".to_string());
                }
                if !labels.iter().any(|l| l == "benchify") {
                    labels.push("benchify".to_string());
                }
                labels
            }
        }
    });

    // 6. POST to Jira REST API v3
    let jira_url = format!("{}/rest/api/3/issue", jira_base_url.trim_end_matches('/'));
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(15))
        .build()
        .map_err(|e| AppError::Internal(format!("HTTP client error: {}", e)))?;

    let response = client
        .post(&jira_url)
        .basic_auth(jira_email, Some(jira_api_token))
        .json(&jira_payload)
        .send()
        .await
        .map_err(|e| {
            tracing::warn!(error = %e, "Jira API unreachable");
            AppError::Internal(format!(
                "Jira integration error: {}",
                e
            ))
        })?;

    let status = response.status();
    let response_body: serde_json::Value = response.json().await.map_err(|e| {
        AppError::Internal(format!("Jira response parse error: {}", e))
    })?;

    if !status.is_success() {
        let jira_error = response_body
            .get("errors")
            .and_then(|e| e.as_object())
            .map(|errors| {
                errors
                    .iter()
                    .map(|(k, v)| format!("{}: {}", k, v))
                    .collect::<Vec<_>>()
                    .join("; ")
            })
            .unwrap_or_else(|| {
                response_body
                    .get("errorMessages")
                    .and_then(|m| m.as_array())
                    .map(|msgs| {
                        msgs.iter()
                            .filter_map(|m| m.as_str())
                            .collect::<Vec<_>>()
                            .join("; ")
                    })
                    .unwrap_or_else(|| format!("HTTP {}", status.as_u16()))
            });

        tracing::warn!(
            status = %status,
            jira_error = %jira_error,
            "Jira API returned error"
        );
        return Err(AppError::Internal(format!(
            "Jira integration error: {}",
            jira_error
        )));
    }

    // 7. Extract issue key and build URL
    let issue_key = response_body["key"]
        .as_str()
        .ok_or_else(|| AppError::Internal("Jira response missing issue key".to_string()))?
        .to_string();
    let issue_url = format!(
        "{}/browse/{}",
        jira_base_url.trim_end_matches('/'),
        issue_key
    );

    // 8. Record audit event
    let _ = audit_mw::audit_session_event(
        &state.pool,
        &auth_user,
        AuditEventType::JiraIssueCreated,
        session_id,
        Some(serde_json::json!({
            "jira_issue_key": issue_key,
            "project_key": body.project_key,
            "issue_type": body.issue_type,
        })),
    ).await;

    Ok((
        axum::http::StatusCode::CREATED,
        Json(CreateJiraIssueResponse {
            issue_key,
            issue_url,
        }),
    ))
}

/// Auto-generate a Jira issue summary from session stats.
fn generate_summary(session: &models::session::Session) -> String {
    let app_name = &session.app_name;
    let stats: Option<models::session::SessionStats> =
        serde_json::from_value(session.session_stats.clone()).ok();

    let fps_avg = stats
        .as_ref()
        .and_then(|s| s.fps_median)
        .map(|v| format!("{:.0}", v))
        .unwrap_or_else(|| "N/A".to_string());
    let cpu_avg = stats
        .as_ref()
        .and_then(|s| s.cpu_avg_pct)
        .map(|v| format!("{:.1}%", v))
        .unwrap_or_else(|| "N/A".to_string());
    let mem_peak = stats
        .as_ref()
        .and_then(|s| s.memory_peak_kb)
        .map(|v| format!("{:.0}MB", v as f64 / 1024.0))
        .unwrap_or_else(|| "N/A".to_string());
    let duration = stats
        .as_ref()
        .and_then(|s| s.duration_ms)
        .map(|v| format!("{}s", v / 1000))
        .unwrap_or_else(|| "N/A".to_string());

    format!(
        "Performance: {} — FPS avg {} / CPU avg {} / Mem peak {} ({})",
        app_name, fps_avg, cpu_avg, mem_peak, duration
    )
}

/// Build Jira Atlassian Document Format (ADF) description from session data.
fn build_adf_description(session: &models::session::Session) -> serde_json::Value {
    let stats: Option<models::session::SessionStats> =
        serde_json::from_value(session.session_stats.clone()).ok();

    let fps_avg = fmt_opt(stats.as_ref().and_then(|s| s.fps_median));
    let fps_min = fmt_opt(stats.as_ref().and_then(|s| s.fps_min));
    let fps_max = fmt_opt(stats.as_ref().and_then(|s| s.fps_max));
    let fps_stability = fmt_opt(stats.as_ref().and_then(|s| s.fps_stability));
    let cpu_avg = fmt_opt(stats.as_ref().and_then(|s| s.cpu_avg_pct));
    let cpu_peak = fmt_opt(stats.as_ref().and_then(|s| s.cpu_peak_pct));
    let mem_avg = fmt_opt_kb(stats.as_ref().and_then(|s| s.memory_avg_kb));
    let mem_peak = fmt_opt_kb(stats.as_ref().and_then(|s| s.memory_peak_kb));
    let jank_count = fmt_opt(stats.as_ref().and_then(|s| s.jank_total));
    let big_jank = fmt_opt(stats.as_ref().and_then(|s| s.jank_big_total));
    let net_tx = fmt_opt_kb(stats.as_ref().and_then(|s| s.net_total_tx_kb));
    let net_rx = fmt_opt_kb(stats.as_ref().and_then(|s| s.net_total_rx_kb));
    let duration = session.duration_seconds.map(|s| format!("{}s", s)).unwrap_or_else(|| "N/A".to_string());

    let app_package = session.app_package.as_deref().unwrap_or("N/A");
    let device_model = session.device_model.as_deref().unwrap_or("Unknown");
    let chipset = session.chipset.as_deref().unwrap_or("Unknown");
    let os_version = session.device_os_version.as_deref().unwrap_or("Unknown");

    serde_json::json!({
        "type": "doc",
        "version": 1,
        "content": [
            {
                "type": "paragraph",
                "content": [
                    { "type": "text", "text": format!("Session: {} ({})", session.app_name, app_package) }
                ]
            },
            {
                "type": "paragraph",
                "content": [
                    { "type": "text", "text": format!("Device: {} / {} / {}", device_model, chipset, os_version) }
                ]
            },
            {
                "type": "paragraph",
                "content": [
                    { "type": "text", "text": format!("Duration: {}", duration) }
                ]
            },
            {
                "type": "heading", "attrs": { "level": 2 },
                "content": [
                    { "type": "text", "text": "Performance Metrics" }
                ]
            },
            {
                "type": "bulletList",
                "content": [
                    {
                        "type": "listItem",
                        "content": [
                            { "type": "paragraph", "content": [
                                { "type": "text", "text": format!("FPS: avg {} / min {} / max {}, stability {}%", fps_avg, fps_min, fps_max, fps_stability) }
                            ]}
                        ]
                    },
                    {
                        "type": "listItem",
                        "content": [
                            { "type": "paragraph", "content": [
                                { "type": "text", "text": format!("CPU: avg {}% / peak {}%", cpu_avg, cpu_peak) }
                            ]}
                        ]
                    },
                    {
                        "type": "listItem",
                        "content": [
                            { "type": "paragraph", "content": [
                                { "type": "text", "text": format!("Memory: avg {}MB / peak {}MB", mem_avg, mem_peak) }
                            ]}
                        ]
                    },
                    {
                        "type": "listItem",
                        "content": [
                            { "type": "paragraph", "content": [
                                { "type": "text", "text": format!("Jank: {} janks / {} big janks", jank_count, big_jank) }
                            ]}
                        ]
                    },
                    {
                        "type": "listItem",
                        "content": [
                            { "type": "paragraph", "content": [
                                { "type": "text", "text": format!("Network: TX {}MB / RX {}MB", net_tx, net_rx) }
                            ]}
                        ]
                    }
                ]
            },
            {
                "type": "paragraph",
                "content": [
                    { "type": "text", "text": format!("View full session: /sessions/{}", session.id) }
                ]
            }
        ]
    })
}

fn fmt_opt(val: Option<f64>) -> String {
    val.map(|v| format!("{:.1}", v)).unwrap_or_else(|| "N/A".to_string())
}

fn fmt_opt_kb(val: Option<f64>) -> String {
    val.map(|v| format!("{:.1}", v / 1024.0)).unwrap_or_else(|| "N/A".to_string())
}

// ── Tests ──

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::NaiveDateTime;
    use uuid::Uuid;

    fn make_test_session() -> models::session::Session {
        let stats = models::session::SessionStats {
            session_id: Uuid::new_v4().to_string(),
            duration_ms: Some(120000),
            fps_median: Some(58.5),
            fps_min: Some(42.0),
            fps_max: Some(60.0),
            fps_1pct_low: None,
            fps_stability: Some(95.0),
            frame_time_p95: None,
            fps_histogram: None,
            variability_index: None,
            frame_ratio_jank_total: None,
            cpu_avg_pct: Some(35.2),
            cpu_peak_pct: Some(78.1),
            cpu_avg_pct_freq_norm: None,
            cpu_peak_pct_freq_norm: None,
            memory_avg_kb: Some(512000),
            memory_peak_kb: Some(768000),
            mem_java_avg_kb: None,
            mem_java_peak_kb: None,
            mem_native_avg_kb: None,
            mem_native_peak_kb: None,
            mem_graphics_avg_kb: None,
            mem_graphics_peak_kb: None,
            mem_stack_avg_kb: None,
            mem_code_avg_kb: None,
            mem_system_avg_kb: None,
            mem_webview_avg_kb: None,
            mem_growth_kb: None,
            mem_trend_slope_kb_per_min: None,
            gpu_avg_pct: Some(45.0),
            gpu_peak_pct: Some(90.0),
            battery_drain_pct: None,
            battery_drain_per_hour: None,
            battery_temp_max_c: None,
            mah_consumed: None,
            avg_power_mw: None,
            total_power_mwh: None,
            estimated_playtime_h: None,
            has_charging_period: Some(0),
            jank_total: Some(15),
            jank_small_total: Some(10),
            jank_big_total: Some(5),
            jank_ratio_total: None,
            jank_per_min: None,
            net_total_tx_kb: Some(2500.0),
            net_total_rx_kb: Some(1800.0),
            net_wifi_total_tx_kb: None,
            net_wifi_total_rx_kb: None,
            net_cellular_total_tx_kb: None,
            net_cellular_total_rx_kb: None,
            net_other_total_tx_kb: None,
            net_other_total_rx_kb: None,
            net_wifi_avg_kbps: None,
            net_cellular_avg_kbps: None,
            thermal_peak: None,
            launch_complete_ms: None,
        };

        let now = NaiveDateTime::parse_from_str("2026-01-01T12:00:00", "%Y-%m-%dT%H:%M:%S").unwrap();
        models::session::Session {
            id: Uuid::new_v4(),
            user_id: Uuid::new_v4(),
            device_id: None,
            app_name: "TestGame".to_string(),
            app_package: Some("com.test.game".to_string()),
            app_version: Some("1.0.0".to_string()),
            device_model: Some("Pixel 7".to_string()),
            device_os_version: Some("Android 14".to_string()),
            chipset: Some("Tensor G2".to_string()),
            tags: vec![],
            project_id: None,
            collection_id: None,
            notes: None,
            started_at: now,
            ended_at: Some(now + chrono::Duration::seconds(120)),
            duration_seconds: Some(120),
            session_stats: serde_json::to_value(&stats).unwrap(),
            metric_samples: serde_json::Value::Array(vec![]),
            markers: serde_json::Value::Array(vec![]),
            detected_issues: serde_json::Value::Array(vec![]),
            screenshots: vec![],
            video_metadata: None,
            thumbnail_path: None,
            is_uploaded: true,
            uploaded_by: None,
            uploaded_at: None,
            team_project_id: None,
            created_at: now,
            updated_at: now,
        }
    }

    #[test]
    fn test_generate_summary_includes_fps_cpu_memory_duration() {
        let session = make_test_session();
        let summary = generate_summary(&session);

        assert!(summary.contains("TestGame"), "Summary should contain app name, got: {}", summary);
        assert!(summary.contains("FPS"), "Summary should mention FPS, got: {}", summary);
        assert!(summary.contains("58"), "Summary should include FPS avg 58, got: {}", summary);
        assert!(summary.contains("CPU"), "Summary should mention CPU, got: {}", summary);
        assert!(summary.contains("35.1%"), "Summary should include CPU avg, got: {}", summary);
        assert!(summary.contains("Mem"), "Summary should mention Memory, got: {}", summary);
        assert!(summary.contains("750MB"), "Summary should include mem peak 750MB, got: {}", summary);
        assert!(summary.contains("120s"), "Summary should include duration 120s, got: {}", summary);
    }

    #[test]
    fn test_build_adf_description_contains_all_metrics() {
        let session = make_test_session();
        let desc = build_adf_description(&session);

        let desc_str = serde_json::to_string(&desc).unwrap();

        // Test 2: Jira issue body includes FPS avg/min/max, CPU avg, memory peak, duration
        assert!(desc_str.contains("58.5"), "ADF should include FPS avg, got: {}", desc_str);
        assert!(desc_str.contains("42.0"), "ADF should include FPS min, got: {}", desc_str);
        assert!(desc_str.contains("60.0"), "ADF should include FPS max, got: {}", desc_str);
        assert!(desc_str.contains("35.2"), "ADF should include CPU avg, got: {}", desc_str);
        assert!(desc_str.contains("78.1"), "ADF should include CPU peak, got: {}", desc_str);
        assert!(desc_str.contains("750.0"), "ADF should include mem peak, got: {}", desc_str);
        assert!(desc_str.contains("120s"), "ADF should include duration, got: {}", desc_str);
        assert!(desc_str.contains("15"), "ADF should include jank count, got: {}", desc_str);
        assert!(desc_str.contains("Pixel 7"), "ADF should include device, got: {}", desc_str);
        assert!(desc_str.contains("Performance Metrics"), "ADF should have heading, got: {}", desc_str);
    }

    #[test]
    fn test_adf_has_bullet_list_structure() {
        let session = make_test_session();
        let desc = build_adf_description(&session);

        assert_eq!(desc["type"], "doc");
        assert_eq!(desc["version"], 1);
        let content = desc["content"].as_array().unwrap();
        assert!(content.iter().any(|c| c["type"] == "bulletList"));
        assert!(content.iter().any(|c| c["type"] == "heading"));
    }

    #[test]
    fn test_empty_stats_produces_sensible_summary() {
        let mut session = make_test_session();
        session.session_stats = serde_json::json!({});
        let summary = generate_summary(&session);
        assert!(summary.contains("N/A"), "Empty stats should show N/A, got: {}", summary);
    }

    #[test]
    fn test_default_issue_type_is_bug() {
        assert_eq!(default_issue_type(), "Bug");
    }

    #[test]
    fn test_jira_issue_created_audit_type_category() {
        assert_eq!(
            AuditEventType::JiraIssueCreated.category(),
            AuditEventCategory::Session
        );
    }
}
