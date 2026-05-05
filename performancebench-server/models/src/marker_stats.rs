use serde::{Deserialize, Serialize};

/// MarkerStats contains per-marker computed analytics for a session.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
#[serde(rename_all = "camelCase")]
pub struct MarkerStats {
    pub marker_id: i64,
    pub session_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub duration_ms: Option<i64>,
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
    pub variability_index: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cpu_avg_pct: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cpu_avg_pct_freq_norm: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub memory_peak_kb: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mem_graphics_peak_kb: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub gpu_avg_pct: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub battery_drain_pct: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mah_consumed: Option<f64>,
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
}
