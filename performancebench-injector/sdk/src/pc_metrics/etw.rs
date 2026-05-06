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
/// Requires administrator privileges. Returns Err with clear message if not admin.
#[cfg(windows)]
pub fn start_frame_session() -> Result<EtwFrameSession, String> {
    // RED phase stub — will be implemented in GREEN phase (Task 2)
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
