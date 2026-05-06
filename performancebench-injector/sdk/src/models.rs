use serde::{Deserialize, Serialize};
use crate::pc_metrics::pdh::PcMetricsSnapshot;

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

    // -----------------------------------------------------------------------
    // PC-specific fields (V30-06, §19.6) — all Option for mobile compat
    // -----------------------------------------------------------------------
    /// Handle count (Windows only) — per T-05-13, aggregate system metric
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pc_handle_count: Option<i32>,

    /// Thread count (Windows only)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pc_thread_count: Option<i32>,

    /// Page faults per second (Windows only)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pc_page_faults_per_s: Option<f64>,

    /// GPU dedicated memory in KB (Windows only, from PDH GPU Process Memory)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pc_gpu_dedicated_mem_kb: Option<i32>,

    /// GPU shared memory in KB (Windows only)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pc_gpu_shared_mem_kb: Option<i32>,

    /// JSON array of per-core CPU % (e.g., [12.5, 8.3, 45.2, 3.1, ...])
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pc_per_core_cpu_json: Option<String>,

    /// JSON array of per-thread CPU data:
    /// [{"tid": 123, "name": "UnityMain", "cpu_pct": 18.2}, ...]
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pc_thread_cpu_json: Option<String>,
}

impl MetricSample {
    /// Convert a PC metrics snapshot to a MetricSample.
    ///
    /// Maps PDH snapshot fields to the appropriate MetricSample fields.
    /// Mobile-specific fields (battery, cellular, thermal) remain None per D-11
    /// (not forced mobile parity).
    pub fn from_pc_snapshot(snapshot: &PcMetricsSnapshot) -> Self {
        let per_core_json = snapshot.cpu_per_core_pct.as_ref().map(|cores| {
            serde_json::to_string(cores).unwrap_or_else(|_| "[]".to_string())
        });

        MetricSample {
            session_id: String::new(), // Set by caller (collector)
            timestamp: snapshot.timestamp,

            // FPS / Jank (filled by dxgi module, not PDH)
            fps: snapshot.fps,
            frametimes_json: snapshot.frametimes_json.clone(),

            // CPU: per-process CPU % from PDH
            cpu_app_pct: snapshot.cpu_process_pct,
            // CPU: per-core states as JSON
            cpu_core_states_json: per_core_json.clone(),
            // CPU: per-thread data (filled by cpu.rs separately)
            cpu_threads_top_json: None,

            // Memory: working set + private bytes map to existing fields
            memory_pss_kb: snapshot.working_set_kb.map(|v| v as i32),
            memory_native_kb: snapshot.private_bytes_kb.map(|v| v as i32),

            // GPU
            gpu_pct: snapshot.gpu_usage_pct,
            gpu_mem_kb: snapshot.gpu_dedicated_mem_kb.map(|v| v as i32),

            // Disk: cumulative bytes → KB rate (set by collector's tick)
            disk_read_kb: snapshot.disk_read_bytes_per_s.map(|v| (v as f64) / 1024.0),
            disk_write_kb: snapshot.disk_write_bytes_per_s.map(|v| (v as f64) / 1024.0),

            // Network: cumulative bytes (set by collector's tick)
            net_rx_bytes: snapshot.net_rx_bytes_per_s.map(|v| v as i32),
            net_tx_bytes: snapshot.net_tx_bytes_per_s.map(|v| v as i32),

            // -----------------------------------------------------------------------
            // PC-specific fields
            // -----------------------------------------------------------------------
            pc_handle_count: snapshot.handle_count,
            pc_thread_count: snapshot.thread_count,
            pc_page_faults_per_s: snapshot.page_faults_per_s,
            pc_gpu_dedicated_mem_kb: snapshot.gpu_dedicated_mem_kb.map(|v| v as i32),
            pc_gpu_shared_mem_kb: snapshot.gpu_shared_mem_kb.map(|v| v as i32),
            pc_per_core_cpu_json: per_core_json,
            pc_thread_cpu_json: None, // Filled separately by cpu.rs

            // Mobile-specific: remain None (D-11 compliance)
            ..Default::default()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_metric_sample_default_has_none_pc_fields() {
        let sample = MetricSample::default();
        assert!(sample.pc_handle_count.is_none());
        assert!(sample.pc_thread_count.is_none());
        assert!(sample.pc_page_faults_per_s.is_none());
        assert!(sample.pc_gpu_dedicated_mem_kb.is_none());
        assert!(sample.pc_gpu_shared_mem_kb.is_none());
        assert!(sample.pc_per_core_cpu_json.is_none());
        assert!(sample.pc_thread_cpu_json.is_none());
    }

    #[test]
    fn test_from_pc_snapshot_maps_fields() {
        let snap = PcMetricsSnapshot {
            timestamp: 1234567890,
            cpu_process_pct: Some(25.5),
            cpu_per_core_pct: Some(vec![30.0, 20.0, 25.0, 28.0]),
            working_set_kb: Some(102400),
            private_bytes_kb: Some(51200),
            page_faults_per_s: Some(150.0),
            thread_count: Some(42),
            handle_count: Some(512),
            gpu_usage_pct: Some(75.0),
            gpu_dedicated_mem_kb: Some(2048000),
            gpu_shared_mem_kb: Some(256000),
            fps: Some(60.0),
            frametimes_json: Some("[16.6,16.7,16.6]".to_string()),
            disk_read_bytes_per_s: Some(1024000),
            disk_write_bytes_per_s: Some(512000),
            ..Default::default()
        };

        let sample = MetricSample::from_pc_snapshot(&snap);

        assert_eq!(sample.timestamp, 1234567890);
        assert!((sample.cpu_app_pct.unwrap() - 25.5).abs() < 0.01);
        assert_eq!(sample.memory_pss_kb, Some(102400));
        assert_eq!(sample.memory_native_kb, Some(51200));
        assert_eq!(sample.pc_handle_count, Some(512));
        assert_eq!(sample.pc_thread_count, Some(42));
        assert!((sample.pc_page_faults_per_s.unwrap() - 150.0).abs() < 0.01);
        assert_eq!(sample.pc_gpu_dedicated_mem_kb, Some(2048000));
        assert_eq!(sample.pc_gpu_shared_mem_kb, Some(256000));
        assert!(sample.pc_per_core_cpu_json.is_some());
        assert!((sample.gpu_pct.unwrap() - 75.0).abs() < 0.01);
        assert!((sample.fps.unwrap() - 60.0).abs() < 0.01);

        // Mobile-specific fields should remain None (D-11: no forced parity)
        assert!(sample.battery_pct.is_none());
        assert!(sample.battery_ma.is_none());
        assert!(sample.thermal_status.is_none());
        assert!(sample.net_cellular_tx_bytes.is_none());
    }

    #[test]
    fn test_from_pc_snapshot_json_serialization_includes_pc_fields() {
        let snap = PcMetricsSnapshot {
            timestamp: 1000,
            working_set_kb: Some(50000),
            handle_count: Some(256),
            thread_count: Some(32),
            page_faults_per_s: Some(10.0),
            gpu_dedicated_mem_kb: Some(1024000),
            gpu_shared_mem_kb: Some(128000),
            cpu_per_core_pct: Some(vec![10.0, 20.0, 15.0, 12.0]),
            ..Default::default()
        };

        let sample = MetricSample::from_pc_snapshot(&snap);
        let json = serde_json::to_string(&sample).unwrap();

        // Verify PC-specific fields appear in JSON
        assert!(json.contains("pc_handle_count"));
        assert!(json.contains("pc_thread_count"));
        assert!(json.contains("pc_page_faults_per_s"));
        assert!(json.contains("pc_gpu_dedicated_mem_kb"));
        assert!(json.contains("pc_gpu_shared_mem_kb"));
        assert!(json.contains("pc_per_core_cpu_json"));
        assert!(json.contains("pc_thread_cpu_json"));

        // Verify mobile-only fields are absent (D-11)
        assert!(!json.contains("battery_pct"));
        assert!(!json.contains("net_cellular_tx_bytes"));
    }

    #[test]
    fn test_from_pc_snapshot_empty_no_panic() {
        let snap = PcMetricsSnapshot::default();
        let sample = MetricSample::from_pc_snapshot(&snap);
        assert_eq!(sample.timestamp, 0);
        assert!(sample.fps.is_none());
        assert!(sample.pc_handle_count.is_none());
    }
}
