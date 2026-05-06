/// TDD tests for WebView JS memory collection — RED phase.
///
/// Test 1: webview_js atomic operations (report + read).
/// Test 2: JNI function signature matches Java class.
/// Test 3: memory_webview_kb appears in MetricSample.

use performancebench_sdk;

#[test]
fn test_report_js_heap_stores_value() {
    // Report a heap value via the JNI callback path
    performancebench_sdk::metrics::webview_js::report_js_heap(45000);
    let value = performancebench_sdk::metrics::webview_js::get_webview_memory();
    assert_eq!(value, Some(45000), "Expected 45000 kB, got {:?}", value);
}

#[test]
fn test_report_js_heap_overwrites_previous() {
    // Multiple reports should overwrite the stored value
    performancebench_sdk::metrics::webview_js::report_js_heap(10000);
    performancebench_sdk::metrics::webview_js::report_js_heap(25000);
    let value = performancebench_sdk::metrics::webview_js::get_webview_memory();
    assert_eq!(value, Some(25000), "Expected 25000 kB (latest), got {:?}", value);
}

#[test]
fn test_get_webview_memory_returns_none_when_no_data() {
    // Reset to ensure clean state
    performancebench_sdk::metrics::webview_js::reset_webview_memory();
    let value = performancebench_sdk::metrics::webview_js::get_webview_memory();
    assert_eq!(value, None, "Expected None when no data reported");
}

#[test]
fn test_webview_memory_in_metricsample() {
    use performancebench_sdk::models::MetricSample;

    performancebench_sdk::metrics::webview_js::report_js_heap(32000);

    let sample = MetricSample {
        session_id: "test".into(),
        timestamp: 1000,
        memory_webview_kb: performancebench_sdk::metrics::webview_js::get_webview_memory(),
        ..Default::default()
    };

    assert_eq!(sample.memory_webview_kb, Some(32000));
}

#[test]
fn test_webview_memory_serialization() {
    use performancebench_sdk::models::MetricSample;

    performancebench_sdk::metrics::webview_js::report_js_heap(16000);

    let sample = MetricSample {
        session_id: "s1".into(),
        timestamp: 5000,
        memory_webview_kb: performancebench_sdk::metrics::webview_js::get_webview_memory(),
        ..Default::default()
    };

    let json = serde_json::to_string(&sample).expect("Serialization failed");
    assert!(json.contains("memory_webview_kb"), "JSON missing memory_webview_kb: {}", json);
    assert!(json.contains("16000"), "JSON missing value 16000: {}", json);
}
