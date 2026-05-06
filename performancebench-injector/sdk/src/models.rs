use serde::{Deserialize, Serialize};

/// MetricSample model matching Dart MetricSample.toMap() field names exactly.
/// All fields use snake_case for JSON serialization to match MetricSample.fromMap().
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub struct MetricSample {
    pub session_id: String,
    pub timestamp: i64,

    // FPS / Jank
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fps: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub jank_count: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub jank_small_count: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub jank_big_count: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub jank_ratio_count: Option<i32>,
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
    pub cpu_cores: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cpu_core_states_json: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cpu_core_freqs_json: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cpu_threads_top_json: Option<String>,

    // Memory (PSS subsections)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub memory_pss_kb: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub memory_java_kb: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub memory_native_kb: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub memory_graphics_kb: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub memory_stack_kb: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub memory_code_kb: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub memory_system_kb: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub memory_webview_kb: Option<i32>,

    // Battery
    #[serde(skip_serializing_if = "Option::is_none")]
    pub battery_pct: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub battery_ma: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub battery_mv: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub battery_temp_c: Option<f64>,
    #[serde(default)]
    pub charging: i32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub charging_source: Option<String>,

    // Connectivity
    #[serde(skip_serializing_if = "Option::is_none")]
    pub wifi_active: Option<i32>,

    // Network (cumulative bytes)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub net_tx_bytes: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub net_rx_bytes: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub net_wifi_tx_bytes: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub net_wifi_rx_bytes: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub net_cellular_tx_bytes: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub net_cellular_rx_bytes: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub net_other_tx_bytes: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub net_other_rx_bytes: Option<i32>,

    // Thermal / GPU / Disk
    #[serde(skip_serializing_if = "Option::is_none")]
    pub thermal_status: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub gpu_pct: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub gpu_freq_mhz: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub gpu_mem_kb: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub disk_read_kb: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub disk_write_kb: Option<f64>,

    // Environment
    #[serde(skip_serializing_if = "Option::is_none")]
    pub screen_brightness: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub volume_pct: Option<i32>,
}
