use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::marker::Marker;
use crate::detected_issue::DetectedIssue;
use crate::metric_sample::MetricSample;
use crate::video::VideoMetadata;

/// Session represents a profiling session stored in the sessions table.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Session {
    pub id: Uuid,
    pub user_id: Uuid,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub device_id: Option<Uuid>,
    pub app_name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub app_package: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub app_version: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub device_model: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub device_os_version: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub chipset: Option<String>,
    #[serde(default)]
    pub tags: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub project_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub collection_id: Option<Uuid>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub notes: Option<String>,
    pub started_at: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ended_at: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub duration_seconds: Option<i32>,
    #[serde(default)]
    pub session_stats: serde_json::Value,
    #[serde(default)]
    pub metric_samples: Vec<MetricSample>,
    #[serde(default)]
    pub markers: Vec<Marker>,
    #[serde(default)]
    pub detected_issues: Vec<DetectedIssue>,
    #[serde(default)]
    pub screenshots: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub video_metadata: Option<VideoMetadata>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub thumbnail_path: Option<String>,
    #[serde(default = "default_true")]
    pub is_uploaded: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub uploaded_by: Option<Uuid>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub uploaded_at: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub created_at: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub updated_at: Option<String>,
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
