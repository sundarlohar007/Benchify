//! ADB broadcast automation — 7 command handlers for CI/CD workflows.
//!
//! Per D-22: Full command set via ADB broadcast:
//!   START_SESSION, STOP_SESSION, PAUSE, RESUME, MARKER, SCREENSHOT, EXPORT
//!
//! Per D-23: Intent extras + JSON payload format. Command via com.benchify.COMMAND,
//! payload via extras. SDK responds with JSON status.
//!
//! Threat mitigations (T-04-19):
//! - Command handlers validate input: action string checked against known 7 commands,
//!   payload JSON parsed with error handling. Malformed JSON returns error status,
//!   does not crash.

use std::sync::Mutex;
use std::time::{SystemTime, UNIX_EPOCH};

use serde_json::{json, Value};

use crate::transport;

/// Automation state: tracks current session and marker count.
struct AutomationState {
    session_id: Option<String>,
    marker_counter: u64,
    profiling_active: bool,
    paused: bool,
}

static AUTOMATION_STATE: once_cell::sync::Lazy<Mutex<AutomationState>> =
    once_cell::sync::Lazy::new(|| {
        Mutex::new(AutomationState {
            session_id: None,
            marker_counter: 0,
            profiling_active: false,
            paused: false,
        })
    });

/// The 7 supported broadcast actions per D-22.
pub const SUPPORTED_ACTIONS: &[&str] = &[
    "START_SESSION",
    "STOP_SESSION",
    "PAUSE",
    "RESUME",
    "MARKER",
    "SCREENSHOT",
    "EXPORT",
];

/// Handle an automation command from the BroadcastReceiver.
///
/// Dispatches on `action` string and returns a JSON response string.
/// All handlers return `{"action":"...","status":"ok|error",...}` per D-23.
pub fn handle_command(action: &str, payload_json: &str) -> String {
    // Validate action is known (T-04-19)
    if !SUPPORTED_ACTIONS.contains(&action) {
        return json!({
            "action": action,
            "status": "error",
            "detail": format!("Unknown action: {}", action)
        })
        .to_string();
    }

    // Parse payload JSON with error handling (T-04-19)
    let payload: Value = match serde_json::from_str(payload_json) {
        Ok(v) => v,
        Err(e) => {
            return json!({
                "action": action,
                "status": "error",
                "detail": format!("Invalid JSON payload: {}", e)
            })
            .to_string();
        }
    };

    // Dispatch to handler
    match action {
        "START_SESSION" => handle_start_session(&payload),
        "STOP_SESSION" => handle_stop_session(&payload),
        "PAUSE" => handle_pause(&payload),
        "RESUME" => handle_resume(&payload),
        "MARKER" => handle_marker(&payload),
        "SCREENSHOT" => handle_screenshot(&payload),
        "EXPORT" => handle_export(&payload),
        _ => unreachable!(), // Already validated above
    }
}

// ============================================================
// START_SESSION — Begins metric collection + TCP streaming
// ============================================================
fn handle_start_session(payload: &Value) -> String {
    let session_id = payload
        .get("session_id")
        .and_then(|v| v.as_str())
        .unwrap_or("unknown");

    let mut state = AUTOMATION_STATE.lock().unwrap_or_else(|e| e.into_inner());

    // Set session ID in transport layer
    transport::set_session_id(session_id);

    // Start streaming if not already active.
    // start_metric_collection() runs an infinite collect-loop, so it must
    // run on a dedicated thread — calling it inline would block the caller
    // (and, since we still hold AUTOMATION_STATE, every other handler too).
    if !state.profiling_active {
        std::thread::spawn(|| {
            transport::start_metric_collection();
        });
        transport::resume_streaming();
        state.profiling_active = true;
        state.paused = false;
    }

    state.session_id = Some(session_id.to_string());
    state.marker_counter = 0;

    json!({
        "action": "START_SESSION",
        "status": "ok",
        "detail": "Profiling started",
        "session_id": session_id
    })
    .to_string()
}

// ============================================================
// STOP_SESSION — Stops metric collection, closes TCP connections
// ============================================================
fn handle_stop_session(_payload: &Value) -> String {
    let mut state = AUTOMATION_STATE.lock().unwrap_or_else(|e| e.into_inner());

    let session_id = state.session_id.clone().unwrap_or_else(|| "unknown".into());

    transport::stop_streaming();
    state.profiling_active = false;
    state.paused = false;
    state.session_id = None;

    json!({
        "action": "STOP_SESSION",
        "status": "ok",
        "detail": "Profiling stopped",
        "session_id": session_id
    })
    .to_string()
}

// ============================================================
// PAUSE — Pauses metric collection (TCP remains open, no new samples)
// ============================================================
fn handle_pause(_payload: &Value) -> String {
    let mut state = AUTOMATION_STATE.lock().unwrap_or_else(|e| e.into_inner());

    if state.profiling_active && !state.paused {
        transport::pause_streaming();
        state.paused = true;
    }

    json!({
        "action": "PAUSE",
        "status": "ok"
    })
    .to_string()
}

// ============================================================
// RESUME — Resumes paused metric collection
// ============================================================
fn handle_resume(_payload: &Value) -> String {
    let mut state = AUTOMATION_STATE.lock().unwrap_or_else(|e| e.into_inner());

    if state.profiling_active && state.paused {
        transport::resume_streaming();
        state.paused = false;
    }

    json!({
        "action": "RESUME",
        "status": "ok"
    })
    .to_string()
}

// ============================================================
// MARKER — Inserts session marker at current timestamp
// ============================================================
fn handle_marker(payload: &Value) -> String {
    let note = payload
        .get("note")
        .and_then(|v| v.as_str())
        .unwrap_or("");

    let mut state = AUTOMATION_STATE.lock().unwrap_or_else(|e| e.into_inner());

    if !state.profiling_active {
        return json!({
            "action": "MARKER",
            "status": "error",
            "detail": "No active profiling session"
        })
        .to_string();
    }

    state.marker_counter += 1;
    let marker_id = state.marker_counter;
    let timestamp_ms = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64;

    // Push a marker into the metric stream (inject special sample or log)
    // For now, we log the marker and it will be included in the EXPORT
    log::info!(
        "Marker #{}: '{}' at {}ms",
        marker_id,
        note,
        timestamp_ms
    );

    // Also push marker as a sample with marker metadata
    let marker_sample = json!({
        "session_id": state.session_id.clone().unwrap_or_default(),
        "timestamp": timestamp_ms,
        "marker_id": marker_id,
        "marker_note": note,
        "is_marker": true
    });
    transport::push_event_json(&marker_sample.to_string());

    json!({
        "action": "MARKER",
        "status": "ok",
        "marker_id": marker_id,
        "note": note,
        "timestamp_ms": timestamp_ms
    })
    .to_string()
}

// ============================================================
// SCREENSHOT — Captures screen to PNG on device storage
// ============================================================
fn handle_screenshot(payload: &Value) -> String {
    let label = payload
        .get("label")
        .and_then(|v| v.as_str())
        .unwrap_or("screenshot");

    let state = AUTOMATION_STATE.lock().unwrap_or_else(|e| e.into_inner());
    let session_id = state.session_id.clone().unwrap_or_else(|| "unknown".into());

    let filename = format!("{}_{}.png", session_id, label);
    let path = format!("/sdcard/benchify/{}", filename);

    // On Android, use SurfaceControl / screencap
    #[cfg(target_os = "android")]
    {
        use std::process::Command;
        match Command::new("/system/bin/screencap")
            .arg("-p")
            .arg(&path)
            .output()
        {
            Ok(out) if out.status.success() => {
                log::info!("Screenshot saved: {}", path);
            }
            Ok(out) => {
                let err = String::from_utf8_lossy(&out.stderr);
                return json!({
                    "action": "SCREENSHOT",
                    "status": "error",
                    "detail": format!("screencap failed: {}", err)
                })
                .to_string();
            }
            Err(e) => {
                return json!({
                    "action": "SCREENSHOT",
                    "status": "error",
                    "detail": format!("screencap command failed: {}", e)
                })
                .to_string();
            }
        }
    }

    // Non-Android: Screenshot not supported at compile-time.
    // On device (hot path), this returns the actual result.
    #[cfg(not(target_os = "android"))]
    {
        // In test/desktop builds, return a simulated path
        log::info!("Screenshot (simulated): {}", path);
    }

    json!({
        "action": "SCREENSHOT",
        "status": "ok",
        "path": path
    })
    .to_string()
}

// ============================================================
// EXPORT — Writes accumulated MetricSample data to JSON file
// ============================================================
fn handle_export(_payload: &Value) -> String {
    let state = AUTOMATION_STATE.lock().unwrap_or_else(|e| e.into_inner());
    let session_id = state.session_id.clone().unwrap_or_else(|| "unknown".into());

    let filename = format!("{}_export.json", session_id);
    let path = format!("/sdcard/benchify/{}", filename);

    // Get accumulated samples from transport layer
    let samples = transport::get_buffered_samples();
    let sample_count = samples.len();

    // Serialize to JSON array
    let export_json = match serde_json::to_string_pretty(&samples) {
        Ok(s) => s,
        Err(e) => {
            return json!({
                "action": "EXPORT",
                "status": "error",
                "detail": format!("Serialization failed: {}", e)
            })
            .to_string();
        }
    };

    // On Android: write to device storage
    #[cfg(target_os = "android")]
    {
        match std::fs::write(&path, &export_json) {
            Ok(()) => {
                log::info!("Exported {} samples to {}", sample_count, path);
            }
            Err(e) => {
                return json!({
                    "action": "EXPORT",
                    "status": "error",
                    "detail": format!("Write failed: {}", e)
                })
                .to_string();
            }
        }
    }

    // Non-Android: log the export
    #[cfg(not(target_os = "android"))]
    {
        log::info!(
            "Exported {} samples to {} ({} bytes)",
            sample_count,
            path,
            export_json.len()
        );
    }

    json!({
        "action": "EXPORT",
        "status": "ok",
        "path": path,
        "sample_count": sample_count
    })
    .to_string()
}

// ============================================================
// Test helpers
// ============================================================

#[cfg(test)]
mod tests {
    use super::*;

    /// Helper: parse response string into JSON Value
    fn parse_response(json_str: &str) -> Value {
        serde_json::from_str(json_str).expect("Response should be valid JSON")
    }

    #[test]
    fn test_all_supported_actions_handled() {
        for action in SUPPORTED_ACTIONS {
            let response = handle_command(action, "{}");
            let json = parse_response(&response);
            let action_str: &str = action;
            assert_eq!(json["action"].as_str().unwrap_or(""), action_str);
            assert!(json["status"].as_str().map_or(false, |s| s == "ok" || s == "error"),
                "Action {} returned status: {:?}", action, json["status"]);
        }
    }

    #[test]
    fn test_start_session() {
        let response = handle_command("START_SESSION", r#"{"session_id":"abc-123"}"#);
        let json = parse_response(&response);
        assert_eq!(json["action"], "START_SESSION");
        assert_eq!(json["status"], "ok");
        assert_eq!(json["detail"], "Profiling started");
        assert_eq!(json["session_id"], "abc-123");
    }

    #[test]
    fn test_stop_session() {
        // Start first
        handle_command("START_SESSION", r#"{"session_id":"abc-123"}"#);
        // Then stop
        let response = handle_command("STOP_SESSION", "{}");
        let json = parse_response(&response);
        assert_eq!(json["action"], "STOP_SESSION");
        assert_eq!(json["status"], "ok");
    }

    #[test]
    fn test_pause_resume() {
        handle_command("START_SESSION", r#"{"session_id":"test"}"#);

        let pause_resp = handle_command("PAUSE", "{}");
        let pause_json = parse_response(&pause_resp);
        assert_eq!(pause_json["status"], "ok");

        let resume_resp = handle_command("RESUME", "{}");
        let resume_json = parse_response(&resume_resp);
        assert_eq!(resume_json["status"], "ok");
    }

    #[test]
    fn test_marker() {
        handle_command("START_SESSION", r#"{"session_id":"test"}"#);

        let response = handle_command("MARKER", r#"{"note":"boss fight start"}"#);
        let json = parse_response(&response);
        assert_eq!(json["action"], "MARKER");
        assert_eq!(json["status"], "ok");
        assert!(json["marker_id"].is_number());
        assert_eq!(json["note"], "boss fight start");
        assert!(json["timestamp_ms"].is_number());
    }

    #[test]
    fn test_marker_without_session() {
        // AUTOMATION_STATE is shared across parallel tests via lazy_static;
        // ensure profiling is inactive before asserting MARKER fails.
        handle_command("STOP_SESSION", "{}");
        let response = handle_command("MARKER", r#"{"note":"test"}"#);
        let json = parse_response(&response);
        assert_eq!(json["status"], "error");
    }

    #[test]
    fn test_screenshot() {
        let response = handle_command("SCREENSHOT", r#"{"label":"death_screen"}"#);
        let json = parse_response(&response);
        assert_eq!(json["status"], "ok");
        assert!(json["path"].as_str().unwrap().ends_with(".png"));
    }

    #[test]
    fn test_export() {
        let response = handle_command("EXPORT", "{}");
        let json = parse_response(&response);
        assert_eq!(json["action"], "EXPORT");
        assert_eq!(json["status"], "ok");
        assert!(json["path"].as_str().unwrap().ends_with("_export.json"));
        assert!(json["sample_count"].is_number());
    }

    #[test]
    fn test_unknown_action() {
        let response = handle_command("UNKNOWN_ACTION", "{}");
        let json = parse_response(&response);
        assert_eq!(json["status"], "error");
        assert!(json["detail"].as_str().unwrap().contains("Unknown"));
    }

    #[test]
    fn test_malformed_json() {
        let response = handle_command("START_SESSION", "{not valid json");
        let json = parse_response(&response);
        assert_eq!(json["status"], "error");
        assert!(json["detail"].as_str().unwrap().contains("Invalid JSON"));
    }
}
