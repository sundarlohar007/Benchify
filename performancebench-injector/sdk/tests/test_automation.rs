/// Integration tests for the ADB broadcast automation module.
/// GREEN phase: Tests call the real automation::handle_command function.
/// Validates all 7 command handlers produce correct JSON responses.

use serde_json::Value;

use performancebench_sdk::automation;

// ---------------------------------------------------------------------------
// Helper: parse JSON response string
// ---------------------------------------------------------------------------
fn parse_response(json_str: &str) -> Value {
    serde_json::from_str(json_str).expect("Response should be valid JSON")
}

// ============================================================
// TEST 1: START_SESSION — begins profiling
// ============================================================
#[test]
fn test_handle_start_session() {
    let payload = r#"{"session_id":"abc-123"}"#;
    let response = automation::handle_command("START_SESSION", payload);
    let json = parse_response(&response);

    assert_eq!(json["action"], "START_SESSION");
    assert_eq!(json["status"], "ok");
    assert_eq!(json["detail"], "Profiling started");
    assert_eq!(json["session_id"], "abc-123");
}

// ============================================================
// TEST 2: STOP_SESSION — stops profiling
// ============================================================
#[test]
fn test_handle_stop_session() {
    // Start first to set session state
    automation::handle_command("START_SESSION", r#"{"session_id":"abc-123"}"#);

    let payload = r#"{}"#;
    let response = automation::handle_command("STOP_SESSION", payload);
    let json = parse_response(&response);

    assert_eq!(json["action"], "STOP_SESSION");
    assert_eq!(json["status"], "ok");
    assert_eq!(json["detail"], "Profiling stopped");
}

// ============================================================
// TEST 3: PAUSE — pauses metric collection
// ============================================================
#[test]
fn test_handle_pause() {
    let payload = r#"{}"#;
    let response = automation::handle_command("PAUSE", payload);
    let json = parse_response(&response);

    assert_eq!(json["action"], "PAUSE");
    assert_eq!(json["status"], "ok");
}

// ============================================================
// TEST 4: RESUME — resumes metric collection
// ============================================================
#[test]
fn test_handle_resume() {
    let payload = r#"{}"#;
    let response = automation::handle_command("RESUME", payload);
    let json = parse_response(&response);

    assert_eq!(json["action"], "RESUME");
    assert_eq!(json["status"], "ok");
}

// ============================================================
// TEST 5: MARKER — inserts session marker
// ============================================================
#[test]
fn test_handle_marker() {
    // Need an active session for marker to succeed
    automation::handle_command("START_SESSION", r#"{"session_id":"test-session"}"#);

    let payload = r#"{"note":"boss fight start"}"#;
    let response = automation::handle_command("MARKER", payload);
    let json = parse_response(&response);

    assert_eq!(json["action"], "MARKER");
    assert_eq!(json["status"], "ok");
    assert!(json["marker_id"].is_number());
    assert_eq!(json["note"], "boss fight start");
    assert!(json["timestamp_ms"].is_number());
}

// ============================================================
// TEST 6: SCREENSHOT — captures screen
// ============================================================
#[test]
fn test_handle_screenshot() {
    let payload = r#"{"label":"death_screen"}"#;
    let response = automation::handle_command("SCREENSHOT", payload);
    let json = parse_response(&response);

    assert_eq!(json["action"], "SCREENSHOT");
    assert_eq!(json["status"], "ok");
    assert!(json["path"].is_string());
    let path = json["path"].as_str().unwrap();
    assert!(path.ends_with(".png"));
}

// ============================================================
// TEST 7: EXPORT — exports session data
// ============================================================
#[test]
fn test_handle_export() {
    let payload = r#"{}"#;
    let response = automation::handle_command("EXPORT", payload);
    let json = parse_response(&response);

    assert_eq!(json["action"], "EXPORT");
    assert_eq!(json["status"], "ok");
    assert!(json["path"].is_string());
    let path = json["path"].as_str().unwrap();
    assert!(path.ends_with("_export.json"));
    assert!(json["sample_count"].is_number());
}

// ============================================================
// TEST 8: Unknown action -> error response
// ============================================================
#[test]
fn test_handle_unknown_action() {
    let payload = r#"{}"#;
    let response = automation::handle_command("UNKNOWN_ACTION", payload);
    let json = parse_response(&response);

    assert_eq!(json["action"], "UNKNOWN_ACTION");
    assert_eq!(json["status"], "error");
    assert!(json["detail"].is_string());
    let detail = json["detail"].as_str().unwrap();
    assert!(detail.to_lowercase().contains("unknown"));
}

// ============================================================
// TEST 9: Malformed JSON payload -> error response
// ============================================================
#[test]
fn test_handle_malformed_payload() {
    let payload = r#"{not valid json"#;
    let response = automation::handle_command("START_SESSION", payload);
    let json = parse_response(&response);

    assert_eq!(json["status"], "error");
    assert!(json["detail"].is_string());
}
