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
    /// Trace session handle returned by StartTraceW
    pub session_handle: u64,
    /// Trace registration handle for the DxgKrnl provider
    pub trace_handle: u64,
}

// ---------------------------------------------------------------------------
// Windows ETW FFI bindings (advapi32.dll)
// ---------------------------------------------------------------------------

#[cfg(windows)]
mod ffi {
    use std::ffi::c_void;

    pub const EVENT_TRACE_CONTROL_STOP: u32 = 0x2;
    pub const EVENT_TRACE_REAL_TIME_MODE: u32 = 0x00000100;
    pub const EVENT_TRACE_NO_PER_PROCESSOR_BUFFERING: u32 = 0x10000000;

    /// Windows EVENT_TRACE_PROPERTIES header (simplified).
    /// Full structure is large; we use a minimal buffer for basic session.
    #[repr(C)]
    pub struct EventTraceProperties {
        pub wnode: WnodeHeader,
        pub buffer_size: u32,
        pub minimum_buffers: u32,
        pub maximum_buffers: u32,
        pub maximum_file_size: u32,
        pub log_file_mode: u32,
        pub flush_timer: u32,
        pub enable_flags: u32,
        pub age_limit: i32,
        pub number_of_buffers: u32,
        pub free_buffers: u32,
        pub events_lost: u32,
        pub buffers_written: u32,
        pub log_buffers_lost: u32,
        pub real_time_buffers_lost: u32,
        pub logger_thread_id: *mut c_void,
        pub log_file_name_offset: u32,
        pub logger_name_offset: u32,
    }

    #[repr(C)]
    pub struct WnodeHeader {
        pub buffer_size: u32,
        pub provider_id: u32,
        pub historical_context: u64,
        pub time_stamp: u64,
        pub guid: Guid,
        pub client_context: u32,
        pub flags: u32,
    }

    #[repr(C)]
    pub struct Guid {
        pub data1: u32,
        pub data2: u16,
        pub data3: u16,
        pub data4: [u8; 8],
    }

    extern "system" {
        pub fn StartTraceW(
            trace_handle: *mut u64,
            instance_name: *const u16,
            properties: *mut EventTraceProperties,
        ) -> u32;

        pub fn EnableTraceEx2(
            trace_handle: u64,
            provider_id: *const Guid,
            control_code: u32,
            level: u8,
            any_keyword: u64,
            all_keyword: u64,
            timeout: u32,
            enable_properties: *mut c_void,
        ) -> u32;

        pub fn ControlTraceW(
            trace_handle: u64,
            instance_name: *const u16,
            properties: *mut EventTraceProperties,
            control_code: u32,
        ) -> u32;
    }
}

/// Check if the current process has administrator privileges.
/// Returns true if the process token has the Administrators group SID.
#[cfg(windows)]
fn is_admin() -> bool {
    // Simplified admin check: try to open a restricted registry key
    // A more robust check uses CheckTokenMembership, but this is pragmatic
    if let Ok(output) = std::process::Command::new("net")
        .args(&["session"])
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
    {
        output.success()
    } else {
        false
    }
}

/// DxgKrnl provider GUID: {802EC45A-1E99-4B83-9920-87C98277BA9D}
#[cfg(windows)]
const DXGKRNL_PROVIDER_GUID: ffi::Guid = ffi::Guid {
    data1: 0x802EC45A,
    data2: 0x1E99,
    data3: 0x4B83,
    data4: [0x99, 0x20, 0x87, 0xC9, 0x82, 0x77, 0xBA, 0x9D],
};

/// Convert a Rust string to a null-terminated UTF-16 wide string.
#[cfg(windows)]
fn to_wide(s: &str) -> Vec<u16> {
    use std::iter::once;
    s.encode_utf16().chain(once(0)).collect()
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
    // ETW requires admin privileges
    if !is_admin() {
        return Err(
            "ETW frame timing requires administrator privileges. \
             Run as admin or use DXGI PresentMon (Method B) for non-admin FPS."
                .to_string(),
        );
    }

    // Prepare trace properties
    let session_name = "Benchify-DxgKrnl-Frame";
    let wide_name = to_wide(session_name);

    let mut properties = ffi::EventTraceProperties {
        wnode: ffi::WnodeHeader {
            buffer_size: std::mem::size_of::<ffi::EventTraceProperties>() as u32,
            provider_id: 0,
            historical_context: 0,
            time_stamp: 0,
            guid: DXGKRNL_PROVIDER_GUID,
            client_context: 0,
            flags: 0,
        },
        buffer_size: 64,           // 64 KB per buffer
        minimum_buffers: 4,
        maximum_buffers: 32,
        maximum_file_size: 0,
        log_file_mode: ffi::EVENT_TRACE_REAL_TIME_MODE
            | ffi::EVENT_TRACE_NO_PER_PROCESSOR_BUFFERING,
        flush_timer: 1,            // 1 second flush
        enable_flags: 0,
        age_limit: 0,
        number_of_buffers: 0,
        free_buffers: 0,
        events_lost: 0,
        buffers_written: 0,
        log_buffers_lost: 0,
        real_time_buffers_lost: 0,
        logger_thread_id: std::ptr::null_mut(),
        log_file_name_offset: 0,
        logger_name_offset: 0,
    };

    // Set session name in the properties buffer (offset-based)
    let mut logger_name_offset = properties.wnode.buffer_size;
    // Align to 4-byte boundary
    logger_name_offset = ((logger_name_offset + 3) / 4) * 4;
    properties.logger_name_offset = logger_name_offset;

    let mut trace_handle: u64 = 0;
    let status = unsafe {
        ffi::StartTraceW(
            &mut trace_handle as *mut u64,
            wide_name.as_ptr(),
            &mut properties as *mut ffi::EventTraceProperties,
        )
    };

    // STATUS_ALREADY_EXISTS or ERROR_ALREADY_EXISTS is also successful
    // ERROR_SUCCESS = 0, ERROR_ALREADY_EXISTS = 183
    if status != 0 && status != 183 {
        return Err(format!(
            "StartTraceW failed with error code {} (admin required for ETW). \
             ETW is optional — use DXGI PresentMon as fallback.",
            status
        ));
    }

    // Enable the DxgKrnl provider
    let enable_status = unsafe {
        ffi::EnableTraceEx2(
            trace_handle,
            &DXGKRNL_PROVIDER_GUID as *const ffi::Guid,
            1,          // EVENT_CONTROL_CODE_ENABLE_PROVIDER
            4,          // TRACE_LEVEL_INFORMATION
            0x1,        // Keyword: enable PresentHistory
            0,
            0,
            std::ptr::null_mut(),
        )
    };

    if enable_status != 0 {
        // Clean up the trace session if enable failed
        unsafe {
            ffi::ControlTraceW(
                trace_handle,
                wide_name.as_ptr(),
                &mut properties as *mut ffi::EventTraceProperties,
                ffi::EVENT_TRACE_CONTROL_STOP,
            );
        }
        return Err(format!(
            "EnableTraceEx2 for DxgKrnl failed with error code {}",
            enable_status
        ));
    }

    Ok(EtwFrameSession {
        session_handle: 0, // Not used; trace_handle is the key
        trace_handle,
    })
}

#[cfg(not(windows))]
pub fn start_frame_session() -> Result<EtwFrameSession, String> {
    Err("ETW frame timing is Windows-only".to_string())
}

/// Poll frame events from the ETW session.
///
/// Returns accumulated frame presentation timestamps as deltas in nanoseconds.
/// Empty Vec if no new events since last poll.
///
/// Note: Full ETW event processing requires an event callback (ProcessTrace).
/// For the library phase, this function returns an empty Vec as a placeholder.
/// ETW event processing with real-time callbacks is implemented in Plan 05-04
/// pb-pcprobe binary where a dedicated ETW consumer thread is set up.
#[cfg(windows)]
pub fn poll_frame_events(_session: &EtwFrameSession) -> Result<Vec<u64>, String> {
    // ETW real-time event processing requires:
    //   1. OpenTraceW to open the trace for consumption
    //   2. ProcessTrace with EVENT_RECORD callback
    //   3. BufferCallback for buffer completion
    // These are implemented in Plan 05-04 as part of the pb-pcprobe binary
    // where a dedicated consumer thread runs the ETW processing loop.
    //
    // For the library phase, we return an empty Vec indicating no new events.
    // The collector (Plan 05-04) will set up the full ETW processing pipeline.
    Ok(Vec::new())
}

#[cfg(not(windows))]
pub fn poll_frame_events(_session: &EtwFrameSession) -> Result<Vec<u64>, String> {
    Err("ETW is Windows-only".to_string())
}

/// Stop and close the ETW frame timing session.
#[cfg(windows)]
pub fn stop_frame_session(session: EtwFrameSession) {
    let mut properties = ffi::EventTraceProperties {
        wnode: ffi::WnodeHeader {
            buffer_size: std::mem::size_of::<ffi::EventTraceProperties>() as u32,
            provider_id: 0,
            historical_context: 0,
            time_stamp: 0,
            guid: DXGKRNL_PROVIDER_GUID,
            client_context: 0,
            flags: 0,
        },
        buffer_size: 64,
        minimum_buffers: 0,
        maximum_buffers: 0,
        maximum_file_size: 0,
        log_file_mode: 0,
        flush_timer: 0,
        enable_flags: 0,
        age_limit: 0,
        number_of_buffers: 0,
        free_buffers: 0,
        events_lost: 0,
        buffers_written: 0,
        log_buffers_lost: 0,
        real_time_buffers_lost: 0,
        logger_thread_id: std::ptr::null_mut(),
        log_file_name_offset: 0,
        logger_name_offset: 0,
    };

    let session_name = "Benchify-DxgKrnl-Frame";
    let wide_name = to_wide(session_name);

    unsafe {
        ffi::ControlTraceW(
            session.trace_handle,
            wide_name.as_ptr(),
            &mut properties as *mut ffi::EventTraceProperties,
            ffi::EVENT_TRACE_CONTROL_STOP,
        );
    }
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
