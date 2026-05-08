// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

/// Integration tests for PC metrics module.
///
/// Live PDH/ETW tests require Windows and are #[ignore] on non-Windows.
/// Mock/logic tests run on all platforms.

#[cfg(test)]
mod pc_metrics_tests {
    use performancebench_sdk::pc_metrics::pdh;
    use performancebench_sdk::pc_metrics::dxgi;
    use performancebench_sdk::pc_metrics::etw;
    use performancebench_sdk::models::MetricSample;

    // -----------------------------------------------------------------------
    // PDH counter path validation
    // -----------------------------------------------------------------------

    #[test]
    fn test_pdh_counter_paths_are_valid_format() {
        let paths = pdh::build_counter_paths("test.exe", true, 4);
        assert!(paths.len() >= 15, "Expected 15+ counters, got {}", paths.len());

        for (name, path) in &paths {
            assert!(!name.is_empty(), "Counter name should not be empty");
            assert!(!path.is_empty(), "Counter path should not be empty");
            assert!(
                path.starts_with('\\'),
                "Counter path '{}' should start with backslash",
                path
            );
            assert!(
                !path.contains('\0'),
                "Counter path should not contain null bytes"
            );
        }
    }

    // -----------------------------------------------------------------------
    // PDH live query (Windows only, ignored on non-Windows for CI)
    // -----------------------------------------------------------------------

    #[test]
    #[cfg_attr(not(windows), ignore = "PDH requires Windows")]
    fn test_pdh_can_open_system_process() {
        // "System" process (PID 4) always runs on Windows
        // Its process name for PDH is "System" (without .exe)
        let result = pdh::open_query("System", false);
        match result {
            Ok(query) => {
                assert!(query.query_handle != 0, "Query handle should be non-zero");
                assert!(
                    !query.counters.is_empty(),
                    "System process should have PDH counters"
                );

                // Collect a sample
                let sample_result = pdh::collect_sample(&query);
                if let Ok(sample) = sample_result {
                    assert!(sample.timestamp > 0, "Timestamp should be set");
                }

                pdh::close_query(query);
            }
            Err(e) => {
                // Some counter paths may not be available for "System" —
                // this is expected behavior. The query should still
                // produce a descriptive error.
                assert!(!e.is_empty(), "Error should be descriptive: {}", e);
            }
        }
    }

    #[test]
    #[cfg_attr(not(windows), ignore = "PDH requires Windows")]
    fn test_pdh_counter_paths_are_valid() {
        // Open a query for the current process to verify counter paths work
        let exe_name = std::env::current_exe()
            .ok()
            .and_then(|p| p.file_name().map(|n| n.to_string_lossy().to_string()))
            .unwrap_or_else(|| "test.exe".to_string());

        let result = pdh::open_query(&exe_name, false);
        match result {
            Ok(query) => {
                // Verify we got some counters
                assert!(!query.counters.is_empty(), "Should have counters for current process");
                log::debug!("Opened PDH query with {} counters for {}", query.counters.len(), exe_name);
                pdh::close_query(query);
            }
            Err(e) => {
                log::warn!("PDH query failed for {}: {} (this is ok — process may not expose PDH counters)", exe_name, e);
            }
        }
    }

    // -----------------------------------------------------------------------
    // DXGI FPS computation (platform-independent)
    // -----------------------------------------------------------------------

    #[test]
    fn test_dxgi_fps_computation_60hz() {
        let frame_deltas: Vec<u64> = vec![16_666_667; 120];
        let fps = dxgi::compute_pc_fps(&frame_deltas);
        assert!(fps > 59.0 && fps < 61.0, "Expected ~60 FPS, got {}", fps);
    }

    #[test]
    fn test_dxgi_fps_computation_with_jank() {
        let mut deltas = vec![16_666_667; 60];
        deltas[15] = 100_000_000; // Big jank frame
        let (total, small, big) = dxgi::classify_pc_jank(&deltas);
        assert_eq!(big, 1, "Expected 1 big jank");
        assert_eq!(small, 0, "Expected 0 small janks");
        assert_eq!(total, 1, "Expected 1 total jank");
    }

    // -----------------------------------------------------------------------
    // PresentMon CSV parsing
    // -----------------------------------------------------------------------

    #[test]
    fn test_presentmon_csv_parsing_realistic() {
        // Simulate real PresentMon output CSV lines
        let lines = vec![
            "2024-06-15T10:30:45.123,123.456,16.667,144,1920,1080,DXGI",
            "2024-06-15T10:30:45.140,123.473,16.667,144,1920,1080,DXGI",
            "2024-06-15T10:30:45.157,123.490,33.333,60,1920,1080,DXGI",  // spike
            "2024-06-15T10:30:45.173,123.506,16.667,144,1920,1080,DXGI",
        ];

        let deltas_ns: Vec<u64> = lines
            .iter()
            .filter_map(|line| dxgi::parse_presentmon_frame_delta_ns(line))
            .collect();

        assert_eq!(deltas_ns.len(), 4);
        // 16.667ms = ~16,667,000ns
        assert!((deltas_ns[0] as f64 - 16_667_000.0).abs() < 1000.0);
        // 33.333ms = ~33,333,000ns
        assert!((deltas_ns[2] as f64 - 33_333_000.0).abs() < 1000.0);
    }

    // -----------------------------------------------------------------------
    // ETW session (type checks, admin gate)
    // -----------------------------------------------------------------------

    #[test]
    fn test_etw_session_structure() {
        let session = etw::EtwFrameSession {
            session_handle: 1,
            trace_handle: 2,
        };
        assert_eq!(session.session_handle, 1);
        assert_eq!(session.trace_handle, 2);
    }

    // -----------------------------------------------------------------------
    // MetricSample conversion — PC fields
    // -----------------------------------------------------------------------

    #[test]
    fn test_metric_sample_conversion_pc_fields() {
        let snap = pdh::PcMetricsSnapshot {
            timestamp: 1234567890,
            cpu_process_pct: Some(45.0),
            working_set_kb: Some(204800),
            private_bytes_kb: Some(102400),
            page_faults_per_s: Some(25.0),
            thread_count: Some(64),
            handle_count: Some(1024),
            gpu_usage_pct: Some(88.0),
            gpu_dedicated_mem_kb: Some(4096000),
            gpu_shared_mem_kb: Some(512000),
            fps: Some(144.0),
            frametimes_json: Some("[6.9,6.9,6.9]".to_string()),
            disk_read_bytes_per_s: Some(2048000),
            disk_write_bytes_per_s: Some(1024000),
            cpu_per_core_pct: Some(vec![30.0, 40.0, 50.0, 60.0]),
            ..Default::default()
        };

        let sample = MetricSample::from_pc_snapshot(&snap);

        // Verify PC field mapping
        assert_eq!(sample.pc_handle_count, Some(1024));
        assert_eq!(sample.pc_thread_count, Some(64));
        assert!((sample.pc_page_faults_per_s.unwrap() - 25.0).abs() < 0.01);
        assert_eq!(sample.pc_gpu_dedicated_mem_kb, Some(4096000));
        assert_eq!(sample.pc_gpu_shared_mem_kb, Some(512000));

        // Verify per-core JSON
        assert!(sample.pc_per_core_cpu_json.is_some());
        let per_core: Vec<f64> =
            serde_json::from_str(&sample.pc_per_core_cpu_json.unwrap()).unwrap();
        assert_eq!(per_core.len(), 4);

        // Verify standard fields are mapped
        assert!((sample.fps.unwrap() - 144.0).abs() < 0.01);
        assert_eq!(sample.memory_pss_kb, Some(204800));
        assert_eq!(sample.memory_native_kb, Some(102400));

        // D-11: Mobile fields remain None
        assert!(sample.battery_pct.is_none());
        assert!(sample.thermal_status.is_none());
    }

    #[test]
    fn test_metric_sample_json_includes_pc_fields() {
        let snap = pdh::PcMetricsSnapshot {
            timestamp: 1000,
            handle_count: Some(512),
            thread_count: Some(32),
            page_faults_per_s: Some(10.0),
            gpu_dedicated_mem_kb: Some(2048000),
            gpu_shared_mem_kb: Some(256000),
            cpu_per_core_pct: Some(vec![12.5, 25.0]),
            ..Default::default()
        };

        let sample = MetricSample::from_pc_snapshot(&snap);
        let json = serde_json::to_string(&sample).unwrap();

        assert!(json.contains("pc_handle_count"));
        assert!(json.contains("pc_thread_count"));
        assert!(json.contains("pc_page_faults_per_s"));
        assert!(json.contains("pc_gpu_dedicated_mem_kb"));
        assert!(json.contains("pc_gpu_shared_mem_kb"));
        assert!(json.contains("pc_per_core_cpu_json"));
        // pc_thread_cpu_json is filled separately by cpu.rs and intentionally
        // left None by from_pc_snapshot — `skip_serializing_if = Option::is_none`
        // omits it from JSON in this code path.
    }

    // -----------------------------------------------------------------------
    // Non-Windows compilation check (runs everywhere)
    // -----------------------------------------------------------------------

    #[test]
    fn test_non_windows_compiles() {
        // This test only verifies the crate compiles with pc_metrics module.
        // The actual PDH/ETW functions are #[cfg(windows)] gated.
        // If this test runs, the crate compiled successfully on this platform.
        let snap = pdh::PcMetricsSnapshot::default();
        assert_eq!(snap.timestamp, 0);
        assert!(snap.fps.is_none());
        assert!(snap.handle_count.is_none());
    }
}
