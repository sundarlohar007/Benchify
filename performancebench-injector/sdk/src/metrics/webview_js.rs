//! WebView JavaScript memory collection via addJavascriptInterface bridge.
//!
//! Per D-15: WebView JS collection via WebView.addJavascriptInterface().
//! Periodically calls window.performance.memory, reports usedJSHeapSize.
//!
//! Architecture:
//!   Java WebViewBridge calls nativeReportJsHeap(int) via JNI ->
//!   Rust report_js_heap(i32) stores value in AtomicI32 ->
//!   On each 1Hz tick, get_webview_memory() reads the atomic and
//!   the value is included in MetricSample.memory_webview_kb.
//!
//! Per T-04-17: JNI callback runs on binder thread — use AtomicI32
//! (lock-free) for stats. No allocations or blocking operations.
//! Per T-04-14: Only exposes reportMemory(int) — validated input.
//! Single method, no file access, no shell commands exposed to JS.

use std::sync::atomic::{AtomicI32, Ordering};

/// Stores the latest usedJSHeapSize in KB reported by WebView JS bridge.
/// Uses AtomicI32 for lock-free access from JNI binder thread.
static WEBVIEW_HEAP_KB: AtomicI32 = AtomicI32::new(-1);

/// Report JS heap size from Java WebView JNI bridge.
///
/// Called by Java_dev_benchify_WebViewBridge_nativeReportJsHeap.
/// Validates that the input is a non-negative value.
/// Thread-safe — can be called from any thread (typically binder thread).
///
/// # Arguments
/// * `heap_kb` - usedJSHeapSize in kilobytes
pub fn report_js_heap(heap_kb: i32) {
    // Validate: only accept non-negative values (per T-04-14 mitigation)
    if heap_kb < 0 {
        log::warn!("WebView JS memory: ignoring negative value {}", heap_kb);
        return;
    }
    // Cap at 1GB to prevent unreasonable values
    if heap_kb > 1_048_576 {
        log::warn!("WebView JS memory: capping excessive value {} at 1GB", heap_kb);
        WEBVIEW_HEAP_KB.store(1_048_576, Ordering::Relaxed);
        return;
    }
    WEBVIEW_HEAP_KB.store(heap_kb, Ordering::Relaxed);
}

/// Get the latest WebView JS heap memory value.
///
/// Returns None if no data has been reported yet (sentinel value -1).
/// Thread-safe — can be called from metric collection thread.
pub fn get_webview_memory() -> Option<i32> {
    let value = WEBVIEW_HEAP_KB.load(Ordering::Relaxed);
    if value < 0 {
        None
    } else {
        Some(value)
    }
}

/// Reset the stored WebView memory value.
///
/// Useful for testing and for session resets.
pub fn reset_webview_memory() {
    WEBVIEW_HEAP_KB.store(-1, Ordering::Relaxed);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_report_and_read() {
        reset_webview_memory();
        report_js_heap(45000);
        assert_eq!(get_webview_memory(), Some(45000));
    }

    #[test]
    fn test_overwrite() {
        reset_webview_memory();
        report_js_heap(10000);
        report_js_heap(25000);
        assert_eq!(get_webview_memory(), Some(25000));
    }

    #[test]
    fn test_no_data_returns_none() {
        reset_webview_memory();
        assert_eq!(get_webview_memory(), None);
    }

    #[test]
    fn test_negative_value_rejected() {
        reset_webview_memory();
        report_js_heap(1000);
        report_js_heap(-500);
        // Should keep the previous valid value
        assert_eq!(get_webview_memory(), Some(1000));
    }

    #[test]
    fn test_excessive_value_capped() {
        reset_webview_memory();
        // 2GB — should be capped at 1GB
        report_js_heap(2_097_152);
        assert_eq!(get_webview_memory(), Some(1_048_576));
    }

    #[test]
    fn test_zero_is_valid() {
        reset_webview_memory();
        report_js_heap(0);
        assert_eq!(get_webview_memory(), Some(0));
    }
}
