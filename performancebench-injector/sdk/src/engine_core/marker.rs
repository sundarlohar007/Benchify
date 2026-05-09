//! Scoped marker state machine for game engine profiling.
//!
//! Per D-01: Shared Rust core library — BeginMarker/EndMarker API.
//! Per D-02: Scoped marker pattern (start at creation, end on scope exit).
//! Thread-safe via Mutex for concurrent use from engine main threads.
//!
//! MIT License — Copyright (c) 2026 Benchify

use std::time::{SystemTime, UNIX_EPOCH};
use std::sync::Mutex;

/// Escape a string for safe embedding in a JSON string literal.
/// Handles: backslash, double-quote, newline, carriage-return, tab.
fn escape_json_string(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => {
                // Other control characters: \uXXXX
                out.push_str(&format!("\\u{:04x}", c as u32));
            }
            _ => out.push(c),
        }
    }
    out
}

/// A scoped performance marker recording start and optional end time.
#[derive(Debug, Clone)]
pub struct ScopedMarker {
    pub name: String,
    pub start_ts: i64,
    pub end_ts: Option<i64>,
    pub scene_name: Option<String>,
}

/// Thread-safe marker history for engine plugins.
static MARKER_HISTORY: once_cell::sync::Lazy<Mutex<Vec<ScopedMarker>>> =
    once_cell::sync::Lazy::new(|| Mutex::new(Vec::new()));

/// Create and start a scoped marker with the given name.
/// Records the current system time as start_ts.
pub fn begin_marker(name: &str) -> ScopedMarker {
    let now_ms = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64;

    let marker = ScopedMarker {
        name: name.to_string(),
        start_ts: now_ms,
        end_ts: None,
        scene_name: None,
    };

    // Push a copy to history (thread-safe).
    if let Ok(mut history) = MARKER_HISTORY.lock() {
        history.push(marker.clone());
        // Keep history bounded to 10,000 markers.
        let n = history.len();
        if n > 10_000 {
            history.drain(0..n - 10_000);
        }
    }

    marker
}

/// Begin a marker associated with a scene load.
pub fn begin_scene_marker(scene_name: &str) -> ScopedMarker {
    let now_ms = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64;

    let marker = ScopedMarker {
        name: format!("Scene:{}", scene_name),
        start_ts: now_ms,
        end_ts: None,
        scene_name: Some(scene_name.to_string()),
    };

    if let Ok(mut history) = MARKER_HISTORY.lock() {
        history.push(marker.clone());
        let n = history.len();
        if n > 10_000 {
            history.drain(0..n - 10_000);
        }
    }

    marker
}

/// Finalize a scoped marker — sets end_ts to current time.
/// This is typically called when the marker goes out of scope.
pub fn end_marker(marker: &mut ScopedMarker) {
    if marker.end_ts.is_none() {
        marker.end_ts = Some(
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap_or_default()
                .as_millis() as i64,
        );
    }
}

/// Get the duration of a completed marker in milliseconds.
pub fn marker_duration_ms(marker: &ScopedMarker) -> Option<i64> {
    marker.end_ts.map(|end| end.saturating_sub(marker.start_ts))
}

/// Serialize a marker to JSON for TCP streaming.
/// Format: {"type":"marker","name":"...","start_ms":...,"duration_ms":...}
/// All string fields are JSON-escaped to prevent injection.
pub fn marker_event_json(marker: &ScopedMarker) -> String {
    let duration = marker_duration_ms(marker);
    let escaped_name = escape_json_string(&marker.name);
    let scene_field = marker
        .scene_name
        .as_ref()
        .map(|s| format!(r#","scene":"{}""#, escape_json_string(s)))
        .unwrap_or_default();

    match duration {
        Some(d) => format!(
            r#"{{"type":"marker","name":"{}","start_ms":{},"duration_ms":{}{}}}"#,
            escaped_name, marker.start_ts, d, scene_field
        ),
        None => format!(
            r#"{{"type":"marker","name":"{}","start_ms":{},"duration_ms":null{}}}"#,
            escaped_name, marker.start_ts, scene_field
        ),
    }
}

/// Push a marker event JSON to the TCP transport queue.
/// Reuses the existing transport::push_event_json function.
pub fn queue_marker_event(marker: &ScopedMarker) {
    let json = marker_event_json(marker);
    crate::transport::push_event_json(&json);
}

/// Get the total marker count from history.
pub fn marker_count() -> usize {
    MARKER_HISTORY.lock().map(|h| h.len()).unwrap_or(0)
}

/// Clear marker history.
pub fn clear_markers() {
    if let Ok(mut history) = MARKER_HISTORY.lock() {
        history.clear();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::thread;
    use std::time::Duration;

    #[test]
    fn test_begin_marker_creates_entry_with_name() {
        let marker = begin_marker("test_marker");
        assert_eq!(marker.name, "test_marker");
        assert!(marker.start_ts > 0);
        assert!(marker.end_ts.is_none());
    }

    #[test]
    fn test_end_marker_finalizes_with_duration() {
        let mut marker = begin_marker("profiled_op");
        let start = marker.start_ts;

        // Simulate some work
        thread::sleep(Duration::from_millis(10));

        end_marker(&mut marker);

        assert!(marker.end_ts.is_some());
        assert!(marker.end_ts.unwrap() >= start);

        let duration = marker_duration_ms(&marker);
        assert!(duration.is_some());
        assert!(duration.unwrap() >= 10);
    }

    #[test]
    fn test_marker_event_json_format() {
        let mut marker = begin_marker("combat_start");
        marker.end_ts = Some(marker.start_ts + 42);

        let json = marker_event_json(&marker);

        assert!(json.contains(r#""type":"marker""#));
        assert!(json.contains(r#""name":"combat_start""#));
        assert!(json.contains(r#""duration_ms":42"#));
    }

    #[test]
    fn test_marker_event_json_incomplete() {
        let marker = begin_marker("incomplete");

        let json = marker_event_json(&marker);
        assert!(json.contains(r#""duration_ms":null"#));
    }

    #[test]
    fn test_marker_history_tracks_markers() {
        clear_markers();
        assert_eq!(marker_count(), 0);

        begin_marker("first");
        assert_eq!(marker_count(), 1);

        begin_marker("second");
        assert_eq!(marker_count(), 2);

        let mut third = begin_marker("third");
        end_marker(&mut third);
        assert_eq!(marker_count(), 3);
    }

    #[test]
    fn test_scene_marker_has_scene_name() {
        let marker = begin_scene_marker("MainMenu");

        assert!(marker.name.contains("MainMenu"));
        assert_eq!(marker.scene_name, Some("MainMenu".to_string()));

        let json = marker_event_json(&marker);
        assert!(json.contains(r#""scene":"MainMenu""#));
    }

    #[test]
    fn test_end_marker_idempotent() {
        let mut marker = begin_marker("idem_test");
        let first_end = marker.start_ts + 100;
        marker.end_ts = Some(first_end);

        // Calling end_marker again should not change end_ts.
        end_marker(&mut marker);
        assert_eq!(marker.end_ts, Some(first_end));
    }

    #[test]
    fn test_marker_json_escaping() {
        // Names with quotes, backslashes, newlines must be escaped
        let marker = ScopedMarker {
            name: "boss\"fight\\n".to_string(),
            start_ts: 1000,
            end_ts: Some(2000),
            scene_name: Some("Level\t1".to_string()),
        };

        let json = marker_event_json(&marker);
        // The JSON must be parseable by serde
        let parsed: serde_json::Value = serde_json::from_str(&json)
            .expect("Marker JSON with special chars should be valid");
        assert_eq!(parsed["name"], "boss\"fight\\n");
        assert_eq!(parsed["scene"], "Level\t1");
        assert_eq!(parsed["duration_ms"], 1000);
    }
}
