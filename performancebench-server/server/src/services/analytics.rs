/// Analytics engine — 1:1 port from Dart `analytics_service.dart`.
/// The server is the single source of truth for session statistics (D-18).
/// Every formula must match the Dart implementation exactly.
use models::marker::Marker;
use models::metric_sample::MetricSample;
use models::session::SessionStats;
use serde_json;
use uuid::Uuid;

/// FPS statistics container — matches Dart `FpsStats` class.
#[derive(Debug, Clone)]
struct FpsStats {
    median: f64,
    min: f64,
    max: f64,
    one_percent_low: f64,
    p95_frame_time_ms: f64,
    stability_pct: f64,
    histogram_json: String,
    variability_index: f64,
}

impl FpsStats {
    const ZERO: Self = Self {
        median: 0.0,
        min: 0.0,
        max: 0.0,
        one_percent_low: 0.0,
        p95_frame_time_ms: 0.0,
        stability_pct: 0.0,
        histogram_json: String::new(),
        variability_index: 0.0,
    };
}

/// Port of `FpsAnalytics.compute()` from `fps_analytics.dart`.
fn compute_fps_stats(samples: &[f64]) -> FpsStats {
    if samples.is_empty() {
        return FpsStats::ZERO;
    }

    let mut sorted: Vec<f64> = samples.to_vec();
    sorted.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));

    let n = sorted.len();

    // Median
    let median = median_of_sorted(&sorted);

    // Min / Max
    let min = sorted[0];
    let max = sorted[sorted.len() - 1];

    // 1% Low — matches Dart: ceil(n*0.01).clamp(1, n) then average
    let one_pct_count = ((n as f64 * 0.01).ceil() as usize).clamp(1, n);
    let one_percent_low: f64 = sorted[..one_pct_count].iter().sum::<f64>() / one_pct_count as f64;

    // 95th percentile frame time — matches Dart: 5th percentile FPS, then 1000/fps
    let p5_rank = ((n as f64 * 0.05).ceil() as usize).clamp(1, n);
    let p5_index = p5_rank - 1;
    let fps_5th = sorted[p5_index];
    let p95_frame_time_ms = if fps_5th > 0.0 { 1000.0 / fps_5th } else { 0.0 };

    // Stability % — Dart: count where fps between median*0.8 and median*1.2
    let lo = median * 0.8;
    let hi = median * 1.2;
    let stable_count = samples.iter().filter(|&&f| f >= lo && f <= hi).count();
    let stability_pct = (stable_count as f64 / samples.len() as f64) * 100.0;

    // Histogram (5 fps buckets) — matches Dart: (fps ~/ 5) * 5
    let mut histogram: std::collections::BTreeMap<i64, i64> = std::collections::BTreeMap::new();
    for &fps in samples {
        let key = (fps as i64 / 5) * 5;
        *histogram.entry(key).or_insert(0) += 1;
    }
    let histogram_json = serde_json::to_string(
        &histogram
            .iter()
            .map(|(k, v)| (k.to_string(), *v))
            .collect::<std::collections::HashMap<String, i64>>(),
    )
    .unwrap_or_else(|_| "{}".to_string());

    // Variability Index — Dart: sum of |adjacent diffs| / (n-1)
    let mut variability_index = 0.0;
    if samples.len() >= 2 {
        let sum_diffs: f64 = samples.windows(2).map(|w| (w[1] - w[0]).abs()).sum();
        variability_index = sum_diffs / (samples.len() - 1) as f64;
    }

    FpsStats {
        median,
        min,
        max,
        one_percent_low,
        p95_frame_time_ms,
        stability_pct,
        histogram_json,
        variability_index,
    }
}

/// Median of a sorted slice — matches Dart `_median()`.
fn median_of_sorted(sorted: &[f64]) -> f64 {
    let n = sorted.len();
    if n % 2 == 1 {
        sorted[n / 2]
    } else {
        (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0
    }
}

/// Mean of an iterator of f64 values.
fn mean(values: &[f64]) -> Option<f64> {
    if values.is_empty() {
        None
    } else {
        Some(values.iter().sum::<f64>() / values.len() as f64)
    }
}

/// Peak (max) of an iterator of f64 values.
fn peak_f64(values: &[f64]) -> Option<f64> {
    values
        .iter()
        .cloned()
        .max_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal))
}

/// Mean of i64 values (returns rounded i64).
fn mean_i64(values: &[i64]) -> Option<i64> {
    if values.is_empty() {
        None
    } else {
        let sum: i64 = values.iter().sum();
        Some(sum / values.len() as i64)
    }
}

/// Peak (max) of i64 values.
fn peak_i64(values: &[i64]) -> Option<i64> {
    values.iter().copied().max()
}

/// Sum of an optional i64 field across all samples (matches `_sumIntField`).
fn sum_i64_field<T: Fn(&MetricSample) -> Option<i64>>(
    samples: &[MetricSample],
    getter: T,
) -> Option<i64> {
    let mut has_any = false;
    let mut sum: i64 = 0;
    for s in samples {
        if let Some(v) = getter(s) {
            sum += v;
            has_any = true;
        }
    }
    if has_any { Some(sum) } else { None }
}

/// Delta of a cumulative field: (last - first) / 1024.0 for KB values.
fn net_delta<T: Fn(&MetricSample) -> Option<i64>>(
    samples: &[MetricSample],
    getter: T,
) -> Option<f64> {
    let vals: Vec<i64> = samples.iter().filter_map(|s| getter(s)).collect();
    if vals.len() < 2 {
        None
    } else {
        Some((vals[vals.len() - 1] - vals[0]) as f64 / 1024.0)
    }
}

/// Compute session-level statistics from raw metric samples.
/// This is a 1:1 port of `AnalyticsService.computeSessionStats()` from Dart.
/// All formulas produce identical output to the desktop analytics engine.
pub fn compute_session_stats(
    samples: &[MetricSample],
    session_id: Uuid,
    duration_ms: i64,
    markers: &[Marker],
) -> SessionStats {
    if samples.is_empty() {
        return SessionStats {
            session_id: session_id.to_string(),
            duration_ms: Some(duration_ms),
            fps_median: None,
            fps_min: None,
            fps_max: None,
            fps_1pct_low: None,
            fps_stability: None,
            frame_time_p95: None,
            fps_histogram: None,
            variability_index: None,
            frame_ratio_jank_total: None,
            cpu_avg_pct: None,
            cpu_peak_pct: None,
            cpu_avg_pct_freq_norm: None,
            cpu_peak_pct_freq_norm: None,
            memory_avg_kb: None,
            memory_peak_kb: None,
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
            gpu_avg_pct: None,
            gpu_peak_pct: None,
            battery_drain_pct: None,
            battery_drain_per_hour: None,
            battery_temp_max_c: None,
            mah_consumed: None,
            avg_power_mw: None,
            total_power_mwh: None,
            estimated_playtime_h: None,
            has_charging_period: None,
            jank_total: None,
            jank_small_total: None,
            jank_big_total: None,
            jank_ratio_total: None,
            jank_per_min: None,
            net_total_tx_kb: None,
            net_total_rx_kb: None,
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
    }

    // Duration
    let first_ts = samples[0].timestamp;
    let last_ts = samples[samples.len() - 1].timestamp;
    let duration_ms = last_ts - first_ts;

    // ── FPS (§6.1) ──
    let fps_values: Vec<f64> = samples.iter().filter_map(|s| s.fps).collect();
    let fps_stats = compute_fps_stats(&fps_values);

    // ── CPU (§6.2) ──
    let cpu_values: Vec<f64> = samples.iter().filter_map(|s| s.cpu_app_pct).collect();
    let cpu_avg = mean(&cpu_values);
    let cpu_peak = peak_f64(&cpu_values);
    let cpu_freq_norm_values: Vec<f64> = samples
        .iter()
        .filter_map(|s| s.cpu_app_pct_freq_norm)
        .collect();
    let cpu_avg_freq_norm = mean(&cpu_freq_norm_values);
    let cpu_peak_freq_norm = peak_f64(&cpu_freq_norm_values);

    // ── Memory (§6.4) ──
    let mem_values: Vec<i64> = samples.iter().filter_map(|s| s.memory_pss_kb).collect();
    let mem_avg = mean_i64(&mem_values);
    let mem_peak = peak_i64(&mem_values);
    let mem_growth = if mem_values.len() > 1 {
        Some(mem_values[mem_values.len() - 1] - mem_values[0])
    } else {
        None
    };

    // Memory subsections
    let mem_java_vals: Vec<i64> = samples.iter().filter_map(|s| s.memory_java_kb).collect();
    let mem_native_vals: Vec<i64> = samples.iter().filter_map(|s| s.memory_native_kb).collect();
    let mem_graphics_vals: Vec<i64> = samples
        .iter()
        .filter_map(|s| s.memory_graphics_kb)
        .collect();
    let mem_stack_vals: Vec<i64> = samples.iter().filter_map(|s| s.memory_stack_kb).collect();
    let mem_code_vals: Vec<i64> = samples.iter().filter_map(|s| s.memory_code_kb).collect();
    let mem_system_vals: Vec<i64> = samples.iter().filter_map(|s| s.memory_system_kb).collect();
    let mem_webview_vals: Vec<i64> = samples.iter().filter_map(|s| s.memory_webview_kb).collect();

    // Memory trend slope (linear regression on PSS vs time, KB/min)
    let mem_trend = if mem_values.len() >= 2 {
        let n = mem_values.len() as f64;
        let mut sum_x = 0.0f64;
        let mut sum_y = 0.0f64;
        let mut sum_xy = 0.0f64;
        let mut sum_x2 = 0.0f64;
        for i in 0..mem_values.len() {
            let x = (samples[i].timestamp - first_ts) as f64 / 1000.0; // seconds
            let y = mem_values[i] as f64;
            sum_x += x;
            sum_y += y;
            sum_xy += x * y;
            sum_x2 += x * x;
        }
        let denom = n * sum_x2 - sum_x * sum_x;
        if denom != 0.0 {
            let slope_kb_per_sec = (n * sum_xy - sum_x * sum_y) / denom;
            Some(slope_kb_per_sec * 60.0) // KB/min
        } else {
            None
        }
    } else {
        None
    };

    // ── GPU (§6.5) ──
    let gpu_values: Vec<f64> = samples.iter().filter_map(|s| s.gpu_pct).collect();
    let gpu_avg = mean(&gpu_values);
    let gpu_peak = peak_f64(&gpu_values);

    // ── Battery/Power (§6.6) ──
    // Filter non-charging samples
    let non_charging: Vec<&MetricSample> =
        samples.iter().filter(|s| s.charging != Some(1)).collect();
    let has_charging = samples.iter().any(|s| s.charging == Some(1));

    // Battery drain
    let bat_pct_values: Vec<i32> = non_charging.iter().filter_map(|s| s.battery_pct).collect();
    let battery_drain_pct = if bat_pct_values.len() >= 1 {
        let drain = (bat_pct_values[0] - bat_pct_values[bat_pct_values.len() - 1]) as f64;
        Some(drain.clamp(0.0, 100.0))
    } else {
        None
    };
    let battery_drain_per_hour = match battery_drain_pct {
        Some(drain) => {
            let hours = duration_ms as f64 / (1000.0 * 3600.0);
            if hours > 0.0 {
                Some(drain / hours)
            } else {
                Some(0.0)
            }
        }
        None => None,
    };

    // Temperature
    let temp_values: Vec<f64> = samples.iter().filter_map(|s| s.battery_temp_c).collect();
    let battery_temp_max = peak_f64(&temp_values);

    // Trapezoidal integration for mAh and mWh
    let mut mah_consumed: Option<f64> = None;
    let mut total_power_mwh: Option<f64> = None;
    let mut avg_power_mw: Option<f64> = None;
    let mut estimated_playtime_h: Option<f64> = None;

    if non_charging.len() >= 2 {
        let mut mah_sum = 0.0f64;
        let mut mwh_sum = 0.0f64;
        for i in 1..non_charging.len() {
            let dt = (non_charging[i].timestamp - non_charging[i - 1].timestamp) as f64 / 1000.0; // seconds
            let mA1 = (non_charging[i - 1].battery_ma.unwrap_or(0.0)).abs();
            let mA2 = (non_charging[i].battery_ma.unwrap_or(0.0)).abs();
            let mV1 = non_charging[i - 1].battery_mv.unwrap_or(0.0);
            let mV2 = non_charging[i].battery_mv.unwrap_or(0.0);

            // Trapezoidal integration: (val1 + val2) / 2 * dt
            mah_sum += (mA1 + mA2) / 2.0 * dt / 3600.0;
            mwh_sum += (mA1 * mV1 + mA2 * mV2) / 2.0 * dt / 3600.0 / 1000.0;
        }
        mah_consumed = Some(mah_sum);
        total_power_mwh = Some(mwh_sum);

        // Average power (mW)
        let total_dt = (non_charging[non_charging.len() - 1].timestamp - non_charging[0].timestamp)
            as f64
            / 1000.0;
        avg_power_mw = if total_dt > 0.0 {
            Some(mwh_sum * 1000.0 / (total_dt / 3600.0))
        } else {
            Some(0.0)
        };

        // Estimated playtime (4000 mAh battery)
        let avg_ma = if mah_sum > 0.0 && total_dt > 0.0 {
            mah_sum / (total_dt / 3600.0) * 1000.0
        } else {
            0.0
        };
        estimated_playtime_h = if avg_ma > 0.0 {
            Some(4000.0 / avg_ma)
        } else {
            None
        };
    }

    // ── Jank (§6.3) ──
    let jank_total = sum_i64_field(samples, |s| s.jank_count);
    let jank_small_total = sum_i64_field(samples, |s| s.jank_small_count);
    let jank_big_total = sum_i64_field(samples, |s| s.jank_big_count);
    let jank_ratio_total = sum_i64_field(samples, |s| s.jank_ratio_count);
    let duration_minutes = duration_ms as f64 / (1000.0 * 60.0);
    let jank_per_min = if duration_minutes > 0.0 {
        Some((jank_total.unwrap_or(0) as f64) / duration_minutes)
    } else {
        None
    };

    // ── Network (§6.8) ──
    let net_total_tx_kb = net_delta(samples, |s| s.net_tx_bytes);
    let net_total_rx_kb = net_delta(samples, |s| s.net_rx_bytes);
    let net_wifi_total_tx_kb = net_delta(samples, |s| s.net_wifi_tx_bytes);
    let net_wifi_total_rx_kb = net_delta(samples, |s| s.net_wifi_rx_bytes);
    let net_cellular_total_tx_kb = net_delta(samples, |s| s.net_cellular_tx_bytes);
    let net_cellular_total_rx_kb = net_delta(samples, |s| s.net_cellular_rx_bytes);
    let net_other_total_tx_kb = net_delta(samples, |s| s.net_other_tx_bytes);
    let net_other_total_rx_kb = net_delta(samples, |s| s.net_other_rx_bytes);

    let duration_sec = duration_ms as f64 / 1000.0;
    let net_wifi_avg_kbps = if duration_sec > 0.0 {
        Some(
            (net_wifi_total_tx_kb.unwrap_or(0.0) + net_wifi_total_rx_kb.unwrap_or(0.0))
                / duration_sec,
        )
    } else {
        None
    };
    let net_cellular_avg_kbps = if duration_sec > 0.0 {
        Some(
            (net_cellular_total_tx_kb.unwrap_or(0.0) + net_cellular_total_rx_kb.unwrap_or(0.0))
                / duration_sec,
        )
    } else {
        None
    };

    // ── Thermal (§6.7) ──
    let thermal_values: Vec<i64> = samples.iter().filter_map(|s| s.thermal_status).collect();
    let thermal_peak = peak_i64(&thermal_values);

    // ── Launch complete ──
    let launch_complete_ms = markers
        .iter()
        .find(|m| m.name == "launch")
        .map(|m| m.started_at - first_ts);

    SessionStats {
        session_id: session_id.to_string(),
        duration_ms: Some(duration_ms),
        fps_median: Some(fps_stats.median),
        fps_min: Some(fps_stats.min),
        fps_max: Some(fps_stats.max),
        fps_1pct_low: Some(fps_stats.one_percent_low),
        fps_stability: Some(fps_stats.stability_pct),
        frame_time_p95: Some(fps_stats.p95_frame_time_ms),
        fps_histogram: Some(fps_stats.histogram_json),
        variability_index: Some(fps_stats.variability_index),
        frame_ratio_jank_total: jank_ratio_total,
        cpu_avg_pct: cpu_avg,
        cpu_peak_pct: cpu_peak,
        cpu_avg_pct_freq_norm: cpu_avg_freq_norm,
        cpu_peak_pct_freq_norm: cpu_peak_freq_norm,
        memory_avg_kb: mem_avg,
        memory_peak_kb: mem_peak,
        mem_java_avg_kb: mean_i64(&mem_java_vals),
        mem_java_peak_kb: peak_i64(&mem_java_vals),
        mem_native_avg_kb: mean_i64(&mem_native_vals),
        mem_native_peak_kb: peak_i64(&mem_native_vals),
        mem_graphics_avg_kb: mean_i64(&mem_graphics_vals),
        mem_graphics_peak_kb: peak_i64(&mem_graphics_vals),
        mem_stack_avg_kb: mean_i64(&mem_stack_vals),
        mem_code_avg_kb: mean_i64(&mem_code_vals),
        mem_system_avg_kb: mean_i64(&mem_system_vals),
        mem_webview_avg_kb: mean_i64(&mem_webview_vals),
        mem_growth_kb: mem_growth,
        mem_trend_slope_kb_per_min: mem_trend,
        gpu_avg_pct: gpu_avg,
        gpu_peak_pct: gpu_peak,
        battery_drain_pct,
        battery_drain_per_hour,
        battery_temp_max_c: battery_temp_max,
        mah_consumed,
        avg_power_mw,
        total_power_mwh,
        estimated_playtime_h,
        has_charging_period: Some(if has_charging { 1 } else { 0 }),
        jank_total,
        jank_small_total,
        jank_big_total,
        jank_ratio_total,
        jank_per_min,
        net_total_tx_kb,
        net_total_rx_kb,
        net_wifi_total_tx_kb,
        net_wifi_total_rx_kb,
        net_cellular_total_tx_kb,
        net_cellular_total_rx_kb,
        net_other_total_tx_kb,
        net_other_total_rx_kb,
        net_wifi_avg_kbps,
        net_cellular_avg_kbps,
        thermal_peak,
        launch_complete_ms,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_median_odd() {
        let sorted = vec![1.0, 2.0, 3.0, 4.0, 5.0];
        assert!((median_of_sorted(&sorted) - 3.0).abs() < 0.001);
    }

    #[test]
    fn test_median_even() {
        let sorted = vec![1.0, 2.0, 3.0, 4.0];
        assert!((median_of_sorted(&sorted) - 2.5).abs() < 0.001);
    }

    #[test]
    fn test_fps_stats_empty() {
        let stats = compute_fps_stats(&[]);
        assert!((stats.median - 0.0).abs() < 0.001);
        assert_eq!(stats.histogram_json, "{}");
    }

    #[test]
    fn test_fps_stats_basic() {
        let samples = vec![30.0, 60.0, 45.0, 55.0, 50.0];
        let stats = compute_fps_stats(&samples);
        assert!((stats.median - 50.0).abs() < 0.001);
        assert!((stats.min - 30.0).abs() < 0.001);
        assert!((stats.max - 60.0).abs() < 0.001);
        assert!(stats.stability_pct >= 0.0); // >= 0
    }

    #[test]
    fn test_session_stats_basic() {
        let sid = Uuid::new_v4();
        let samples = vec![
            MetricSample {
                timestamp: 0,
                fps: Some(60.0),
                cpu_app_pct: Some(25.0),
                cpu_app_pct_freq_norm: Some(20.0),
                memory_pss_kb: Some(500000),
                memory_java_kb: Some(100000),
                memory_native_kb: Some(80000),
                memory_graphics_kb: Some(60000),
                memory_stack_kb: Some(5000),
                memory_code_kb: Some(20000),
                memory_system_kb: Some(15000),
                memory_webview_kb: None,
                gpu_pct: Some(40.0),
                battery_pct: Some(100),
                battery_ma: Some(500.0),
                battery_mv: Some(4000.0),
                battery_temp_c: Some(35.0),
                charging: Some(0),
                charging_source: None,
                net_tx_bytes: Some(0),
                net_rx_bytes: Some(0),
                net_wifi_tx_bytes: Some(0),
                net_wifi_rx_bytes: Some(0),
                net_cellular_tx_bytes: None,
                net_cellular_rx_bytes: None,
                net_other_tx_bytes: None,
                net_other_rx_bytes: None,
                jank_count: Some(0),
                jank_small_count: Some(0),
                jank_big_count: Some(0),
                jank_ratio_count: Some(0),
                thermal_status: Some(0),
                gpu_freq_mhz: None,
                gpu_mem_kb: None,
                disk_read_kb: None,
                disk_write_kb: None,
                screen_brightness: None,
                volume_pct: None,
                cpu_system_pct: None,
                cpu_cores: None,
                cpu_core_states_json: None,
                cpu_core_freqs_json: None,
                cpu_threads_top_json: None,
                frametimes_json: None,
            },
            MetricSample {
                timestamp: 1000,
                fps: Some(58.0),
                cpu_app_pct: Some(30.0),
                cpu_app_pct_freq_norm: Some(25.0),
                memory_pss_kb: Some(510000),
                memory_java_kb: Some(105000),
                memory_native_kb: Some(82000),
                memory_graphics_kb: Some(61000),
                memory_stack_kb: Some(5200),
                memory_code_kb: Some(20000),
                memory_system_kb: Some(15500),
                memory_webview_kb: None,
                gpu_pct: Some(42.0),
                battery_pct: Some(99),
                battery_ma: Some(480.0),
                battery_mv: Some(3950.0),
                battery_temp_c: Some(36.0),
                charging: Some(0),
                charging_source: None,
                net_tx_bytes: Some(1024),
                net_rx_bytes: Some(2048),
                net_wifi_tx_bytes: Some(1024),
                net_wifi_rx_bytes: Some(2048),
                net_cellular_tx_bytes: None,
                net_cellular_rx_bytes: None,
                net_other_tx_bytes: None,
                net_other_rx_bytes: None,
                jank_count: Some(1),
                jank_small_count: Some(1),
                jank_big_count: Some(0),
                jank_ratio_count: Some(0),
                thermal_status: Some(0),
                gpu_freq_mhz: None,
                gpu_mem_kb: None,
                disk_read_kb: None,
                disk_write_kb: None,
                screen_brightness: None,
                volume_pct: None,
                cpu_system_pct: None,
                cpu_cores: None,
                cpu_core_states_json: None,
                cpu_core_freqs_json: None,
                cpu_threads_top_json: None,
                frametimes_json: None,
            },
        ];
        let markers: Vec<Marker> = vec![];
        let stats = compute_session_stats(&samples, sid, 1000, &markers);

        assert_eq!(stats.session_id, sid.to_string());
        assert!(stats.duration_ms == Some(1000));
        assert!(stats.fps_median.is_some());
        assert!(stats.cpu_avg_pct.is_some());
        assert!(stats.memory_avg_kb.is_some());
        assert!(stats.jank_total == Some(1));
    }
}
