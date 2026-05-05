use diesel::prelude::*;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// Session represents a profiling session stored in the sessions table.
/// For Diesel queries, JSONB columns are stored as serde_json::Value strings.
/// Timestamps use chrono::NaiveDateTime (serde serializes as ISO 8601 strings).
#[derive(Debug, Clone, Serialize, Deserialize, Queryable, Selectable)]
#[diesel(table_name = crate::schema::sessions)]
#[diesel(check_for_backend(diesel::pg::Pg))]
#[serde(rename_all = "camelCase")]
pub struct Session {
    pub id: Uuid,
    pub user_id: Uuid,
    pub device_id: Option<Uuid>,
    pub app_name: String,
    pub app_package: Option<String>,
    pub app_version: Option<String>,
    pub device_model: Option<String>,
    pub device_os_version: Option<String>,
    pub chipset: Option<String>,
    #[serde(default)]
    pub tags: Vec<String>,
    pub project_id: Option<String>,
    pub collection_id: Option<Uuid>,
    pub notes: Option<String>,
    pub started_at: chrono::NaiveDateTime,
    pub ended_at: Option<chrono::NaiveDateTime>,
    pub duration_seconds: Option<i32>,
    #[serde(default)]
    pub session_stats: serde_json::Value,
    #[serde(default)]
    pub metric_samples: serde_json::Value,
    #[serde(default)]
    pub markers: serde_json::Value,
    #[serde(default)]
    pub detected_issues: serde_json::Value,
    #[serde(default)]
    pub screenshots: Vec<String>,
    pub video_metadata: Option<serde_json::Value>,
    pub thumbnail_path: Option<String>,
    #[serde(default = "default_true")]
    pub is_uploaded: bool,
    pub uploaded_by: Option<Uuid>,
    pub uploaded_at: Option<chrono::NaiveDateTime>,
    pub created_at: chrono::NaiveDateTime,
    pub updated_at: chrono::NaiveDateTime,
}

fn default_true() -> bool {
    true
}

/// SessionStats contains computed analytics for a session.
/// Stored as JSONB in sessions.session_stats column.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
#[serde(rename_all = "camelCase")]
pub struct SessionStats {
    pub session_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub duration_ms: Option<i64>,

    // FPS
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fps_median: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fps_min: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fps_max: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fps_1pct_low: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fps_stability: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub frame_time_p95: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fps_histogram: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub variability_index: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub frame_ratio_jank_total: Option<i64>,

    // CPU
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cpu_avg_pct: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cpu_peak_pct: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cpu_avg_pct_freq_norm: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cpu_peak_pct_freq_norm: Option<f64>,

    // Memory
    #[serde(skip_serializing_if = "Option::is_none")]
    pub memory_avg_kb: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub memory_peak_kb: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mem_java_avg_kb: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mem_java_peak_kb: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mem_native_avg_kb: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mem_native_peak_kb: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mem_graphics_avg_kb: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mem_graphics_peak_kb: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mem_stack_avg_kb: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mem_code_avg_kb: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mem_system_avg_kb: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mem_webview_avg_kb: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mem_growth_kb: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mem_trend_slope_kb_per_min: Option<f64>,

    // GPU
    #[serde(skip_serializing_if = "Option::is_none")]
    pub gpu_avg_pct: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub gpu_peak_pct: Option<f64>,

    // Battery + Power
    #[serde(skip_serializing_if = "Option::is_none")]
    pub battery_drain_pct: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub battery_drain_per_hour: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub battery_temp_max_c: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mah_consumed: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub avg_power_mw: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub total_power_mwh: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub estimated_playtime_h: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub has_charging_period: Option<i64>,

    // Jank
    #[serde(skip_serializing_if = "Option::is_none")]
    pub jank_total: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub jank_small_total: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub jank_big_total: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub jank_ratio_total: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub jank_per_min: Option<f64>,

    // Network per-interface
    #[serde(skip_serializing_if = "Option::is_none")]
    pub net_total_tx_kb: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub net_total_rx_kb: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub net_wifi_total_tx_kb: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub net_wifi_total_rx_kb: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub net_cellular_total_tx_kb: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub net_cellular_total_rx_kb: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub net_other_total_tx_kb: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub net_other_total_rx_kb: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub net_wifi_avg_kbps: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub net_cellular_avg_kbps: Option<f64>,

    // Thermal
    #[serde(skip_serializing_if = "Option::is_none")]
    pub thermal_peak: Option<i64>,

    // Timing
    #[serde(skip_serializing_if = "Option::is_none")]
    pub launch_complete_ms: Option<i64>,
}
