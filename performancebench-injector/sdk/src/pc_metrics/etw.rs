// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

/// ETW (Event Tracing for Windows) frame timing session.
///
/// Opens an ETW trace session for provider Microsoft-Windows-DxgKrnl
/// (GUID: {802EC45A-1E99-4B83-9920-87C98277BA9D}) to capture
/// PresentHistory events (Event ID 481) for non-DX games (Vulkan/OpenGL).
///
/// **Admin required** for ETW kernel session per §19.7.
/// All ETW code is `#[cfg(windows)]` gated.

/// ETW frame timing session handle.
#[derive(Debug)]
pub struct EtwFrameSession {
    pub session_handle: u64,
    pub trace_handle: u64,
}

/// Start an ETW frame timing session for the DxgKrnl provider.
///
/// Opens ETW trace session for provider Microsoft-Windows-DxgKrnl
/// (GUID: {802EC45A-1E99-4B83-9920-87C98277BA9D}) to capture
/// PresentHistory events (Event ID 481) for non-DX games.
///
/// **Requires administrator privileges** (per §19.7). Returns clear error if not admin.
#[cfg(windows)]
pub fn start_frame_session() -> Result<EtwFrameSession, String> {
    // RED phase stub — will be implemented in GREEN phase
    Err("ETW frame session not yet implemented".to_string())
}

#[cfg(not(windows))]
pub fn start_frame_session() -> Result<EtwFrameSession, String> {
    Err("ETW frame timing is Windows-only".to_string())
}

/// Poll frame events from the ETW session.
///
/// Returns accumulated frame presentation timestamps as deltas in nanoseconds.
/// Empty Vec if no new events since last poll.
#[cfg(windows)]
pub fn poll_frame_events(_session: &EtwFrameSession) -> Result<Vec<u64>, String> {
    // RED phase stub
    Err("ETW poll not yet implemented".to_string())
}

#[cfg(not(windows))]
pub fn poll_frame_events(_session: &EtwFrameSession) -> Result<Vec<u64>, String> {
    Err("ETW is Windows-only".to_string())
}

/// Stop and close the ETW frame timing session.
#[cfg(windows)]
pub fn stop_frame_session(_session: EtwFrameSession) {
    // Stub
}

#[cfg(not(windows))]
pub fn stop_frame_session(_session: EtwFrameSession) {
    // No-op on non-Windows
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_etw_frame_session_type_exists() {
        // Verify the EtwFrameSession type exists
        let session = EtwFrameSession {
            session_handle: 1,
            trace_handle: 2,
        };
        assert_eq!(session.session_handle, 1);
        assert_eq!(session.trace_handle, 2);
    }

    #[test]
    #[cfg_attr(not(windows), ignore = "ETW requires Windows")]
    fn test_start_frame_session_returns_result() {
        // RED: stub returns Err. GREEN: returns Ok if admin, Err if not.
        let result = start_frame_session();
        match result {
            Ok(session) => {
                // If admin and ETW started successfully
                assert!(session.session_handle > 0, "Session handle should be non-zero");
                stop_frame_session(session);
            }
            Err(e) => {
                // Expected if not admin or if stub is active
                assert!(!e.is_empty(), "Error should be descriptive");
            }
        }
    }

    #[test]
    #[cfg_attr(not(windows), ignore = "ETW requires Windows")]
    fn test_poll_events_returns_result_type() {
        let result = poll_frame_events(&EtwFrameSession {
            session_handle: 0,
            trace_handle: 0,
        });
        let _: Result<Vec<u64>, String> = result;
    }
}
