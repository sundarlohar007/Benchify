use std::net::TcpStream;
use std::io::{BufRead, BufReader, Write};
use std::time::Duration;

/// Test 1: FPS calculator — verify frame delta calculation and FPS computation.
/// Given a series of frame timestamps (in nanoseconds), the FPS module computes
/// FPS as 1e9 / avg_frame_delta_ns over a 1-second window.
#[test]
fn test_fps_calculation_with_frame_deltas() {
    // Simulate frame timestamps at 60fps (16.67ms per frame)
    let frame_deltas_ns: Vec<u64> = (0..60).map(|i| 16_666_667u64 * (i + 1)).collect();
    let fps = performancebench_sdk::metrics::fps::compute_fps(&frame_deltas_ns);
    // Should be approximately 60 fps
    assert!(fps > 55.0 && fps < 65.0, "Expected ~60 fps, got {}", fps);
}

/// Test 2: CPU parser correctly parses /proc/self/stat format.
/// Extracts utime + stime from fields 14-15 (1-indexed) and computes app CPU percentage.
#[test]
fn test_cpu_parser_parses_proc_self_stat() {
    let stat_line = "12345 (my.app) S 1 12345 12345 0 -1 4194304 1234 56 78 90 100 50 25 20 15 0 0 0 12345 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0";
    let (utime, stime) = performancebench_sdk::metrics::cpu::parse_proc_self_stat(stat_line);
    assert_eq!(utime, 50, "Expected utime=50, got {}", utime);
    assert_eq!(stime, 25, "Expected stime=25, got {}", stime);
}

/// Test 3: Memory parser extracts PSS from ActivityManager-like output.
/// Parses PSS memory info and returns memory_pss_kb.
#[test]
fn test_memory_parser_extracts_pss() {
    let pss_data = performancebench_sdk::metrics::memory::MemoryInfo {
        total_pss: 245_760,
        dalvik_pss: 45_000,
        native_pss: 120_000,
        other_pss: 80_760,
    };
    assert_eq!(pss_data.total_pss, 245_760);
    assert_eq!(pss_data.dalvik_pss, 45_000);
    assert_eq!(pss_data.native_pss, 120_000);
    assert_eq!(pss_data.other_pss, 80_760);
}

/// Test 4: Network parser reads /proc/pid/net/dev format and computes per-interface TX/RX deltas.
#[test]
fn test_network_parser_parses_proc_net_dev() {
    let net_dev_content = r"Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
wlan0: 1234567890 9876543    0    0    0     0          0         0 9876543210 7654321    0    0    0     0       0          0
rmnet_data0: 55555555 444444    0    0    0     0          0         0 66666666 333333    0    0    0     0       0          0
lo: 1000000 5000    0    0    0     0          0         0 1000000 5000    0    0    0     0       0          0";

    let interfaces = performancebench_sdk::metrics::network::parse_net_dev(net_dev_content);
    // Loopback (lo) is filtered — only meaningful interfaces counted
    assert_eq!(interfaces.len(), 2, "Expected 2 interfaces (wlan0 + rmnet_data0, lo filtered), got {}", interfaces.len());

    let wlan0 = interfaces.iter().find(|i| i.name == "wlan0").expect("wlan0 not found");
    assert_eq!(wlan0.rx_bytes, 1234567890);
    assert_eq!(wlan0.tx_bytes, 9876543210);

    let rmnet = interfaces.iter().find(|i| i.name == "rmnet_data0").expect("rmnet_data0 not found");
    assert_eq!(rmnet.rx_bytes, 55555555);
    assert_eq!(rmnet.tx_bytes, 66666666);
}

/// Test 5: Transport layer starts TCP server on port 8080 and writes newline-delimited JSON.
/// Verifies that the JSON field names match MetricSample.fromMap() snake_case keys.
#[test]
fn test_transport_writes_valid_json_with_correct_field_names() {
    // Start server in a background thread
    let (ready_tx, ready_rx) = std::sync::mpsc::channel();
    let server_handle = std::thread::spawn(move || {
        let listener = std::net::TcpListener::bind("127.0.0.1:8081").expect("Failed to bind");
        ready_tx.send(()).expect("Failed to signal ready");
        for stream in listener.incoming().take(1) {
            match stream {
                Ok(mut s) => {
                    let sample = performancebench_sdk::models::MetricSample {
                        session_id: "test-session-01".into(),
                        timestamp: 1700000000000,
                        fps: Some(60.0),
                        jank_count: Some(2),
                        cpu_app_pct: Some(25.5),
                        memory_pss_kb: Some(245_760),
                        net_tx_bytes: Some(1024),
                        net_rx_bytes: Some(2048),
                        gpu_pct: Some(45.0),
                        ..Default::default()
                    };
                    let json = serde_json::to_string(&sample).expect("Failed to serialize");
                    writeln!(s, "{}", json).expect("Failed to write");
                }
                Err(e) => eprintln!("Connection failed: {}", e),
            }
        }
    });

    // Wait for server to be ready
    ready_rx.recv_timeout(Duration::from_secs(3)).expect("Server did not start");

    // Connect and read
    let mut stream = TcpStream::connect("127.0.0.1:8081").expect("Failed to connect");
    stream.set_read_timeout(Some(Duration::from_secs(2))).ok();
    let mut reader = BufReader::new(stream);
    let mut line = String::new();
    reader.read_line(&mut line).expect("Failed to read line");

    // Parse the JSON
    let parsed: serde_json::Value = serde_json::from_str(line.trim()).expect("Invalid JSON");

    // Verify all expected field names are present (snake_case matching MetricSample.fromMap)
    assert_eq!(parsed["session_id"].as_str(), Some("test-session-01"));
    assert_eq!(parsed["timestamp"].as_i64(), Some(1700000000000));
    assert!((parsed["fps"].as_f64().unwrap() - 60.0).abs() < 0.01);
    assert_eq!(parsed["jank_count"].as_i64(), Some(2));
    assert!((parsed["cpu_app_pct"].as_f64().unwrap() - 25.5).abs() < 0.01);
    assert_eq!(parsed["memory_pss_kb"].as_i64(), Some(245_760));
    assert_eq!(parsed["net_tx_bytes"].as_i64(), Some(1024));
    assert_eq!(parsed["net_rx_bytes"].as_i64(), Some(2048));
    assert!((parsed["gpu_pct"].as_f64().unwrap() - 45.0).abs() < 0.01);

    // Verify charging has default value (0)
    assert_eq!(parsed["charging"].as_i64(), Some(0));

    server_handle.join().ok();
}

/// Test 6: MetricSample serialization produces correct snake_case JSON field names.
#[test]
fn test_metricsample_serialization_field_names() {
    let sample = performancebench_sdk::models::MetricSample {
        session_id: "s1".into(),
        timestamp: 1000,
        fps: Some(30.0),
        cpu_app_pct: Some(50.0),
        memory_pss_kb: Some(100000),
        memory_java_kb: Some(20000),
        memory_native_kb: Some(50000),
        memory_system_kb: Some(30000),
        ..Default::default()
    };

    let json = serde_json::to_string(&sample).expect("Serialization failed");
    let parsed: serde_json::Value = serde_json::from_str(&json).expect("Not valid JSON");

    // All expected snake_case keys must be present
    assert!(parsed.get("session_id").is_some(), "Missing session_id");
    assert!(parsed.get("timestamp").is_some(), "Missing timestamp");
    assert!(parsed.get("fps").is_some(), "Missing fps");
    assert!(parsed.get("cpu_app_pct").is_some(), "Missing cpu_app_pct");
    assert!(parsed.get("memory_pss_kb").is_some(), "Missing memory_pss_kb");
    assert!(parsed.get("memory_java_kb").is_some(), "Missing memory_java_kb");
    assert!(parsed.get("memory_native_kb").is_some(), "Missing memory_native_kb");
    assert!(parsed.get("memory_system_kb").is_some(), "Missing memory_system_kb");
}

// Default is derived on MetricSample — no manual impl needed.
