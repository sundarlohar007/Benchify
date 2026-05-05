use serde::{Deserialize, Serialize};

/// MetricSample represents one data point during a profiling session.
/// Corresponds to the JSON objects stored in sessions.metric_samples JSONB array.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
#[serde(rename_all = "camelCase")]
pub struct MetricSample {
    pub timestamp: i64,

    // FPS / Jank
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fps: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub jank_count: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub jank_small_count: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub jank_big_count: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub jank_ratio_count: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub frametimes_json: Option<String>,

    // CPU
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cpu_system_pct: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cpu_app_pct: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cpu_app_pct_freq_norm: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cpu_cores: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cpu_core_states_json: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cpu_core_freqs_json: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cpu_threads_top_json: Option<String>,

    // Memory (PSS subsections)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub memory_pss_kb: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub memory_java_kb: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub memory_native_kb: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub memory_graphics_kb: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub memory_stack_kb: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub memory_code_kb: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub memory_system_kb: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub memory_webview_kb: Option<i64>,

    // Battery
    #[serde(skip_serializing_if = "Option::is_none")]
    pub battery_pct: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub battery_ma: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub battery_mv: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub battery_temp_c: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub charging: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub charging_source: Option<String>,

    // Network (cumulative bytes)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub net_tx_bytes: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub net_rx_bytes: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub net_wifi_tx_bytes: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub net_wifi_rx_bytes: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub net_cellular_tx_bytes: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub net_cellular_rx_bytes: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub net_other_tx_bytes: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub net_other_rx_bytes: Option<i64>,

    // Thermal / GPU / Disk
    #[serde(skip_serializing_if = "Option::is_none")]
    pub thermal_status: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub gpu_pct: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub gpu_freq_mhz: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub gpu_mem_kb: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub disk_read_kb: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub disk_write_kb: Option<f64>,

    // Environment
    #[serde(skip_serializing_if = "Option::is_none")]
    pub screen_brightness: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub volume_pct: Option<i64>,
}
