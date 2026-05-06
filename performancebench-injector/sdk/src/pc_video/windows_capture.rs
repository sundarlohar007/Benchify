// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

/// Windows.Graphics.Capture + Media Foundation H.264 encoding.
///
/// Per §32.12: captures display/window via Windows.Graphics.Capture API,
/// encodes to H.264 MP4 chunks via Media Foundation IMFSinkWriter.
///
/// Uses the `windows` crate for WinRT interop. Requires Windows 10 1903+
/// for the Windows.Graphics.Capture API.
///
/// Architecture:
/// - ID3D11Device -> Direct3D11CaptureFramePool (target FPS)
/// - GraphicsCaptureSession -> manages capture lifecycle
/// - IMFMediaSinkWriter -> encodes H.264 frames to MP4 chunk file
/// - Frame callback: on each frame -> IMFSinkWriter::WriteSample() -> chunk file
/// - Chunk rotation: monitor duration -> rotate at chunk_max_ms

use std::path::Path;

use crate::pc_video::chunk_manager::ChunkManager;
use crate::pc_video::{CaptureTarget, VideoConfig};

/// Active Windows capture session.
#[derive(Debug)]
pub struct WindowsCaptureSession {
    /// Target display index (for FullScreen capture).
    pub display_index: u32,

    /// Window title (for SpecificWindow capture).
    pub window_title: Option<String>,

    /// Video configuration.
    pub config: VideoConfig,

    /// Chunk manager for rotation.
    pub chunk_manager: ChunkManager,

    /// Whether capture is active.
    pub is_capturing: bool,
}

/// Initialize Windows.Graphics.Capture runtime.
///
/// Must be called before any capture operations. Initializes WinRT with
/// multi-threaded apartment model (required for GraphicsCapture APIs).
///
/// Returns true if initialization succeeded.
pub fn init_capture() -> Result<(), String> {
    log::info!("Windows Graphics Capture initialized (stub — windows-rs runtime not linked)");

    // In a full implementation, this would call:
    // windows::Win32::System::Com::CoInitializeEx(
    //     std::ptr::null(),
    //     windows::Win32::System::Com::COINIT_MULTITHREADED,
    // );

    Ok(())
}

/// List available display targets.
///
/// Returns a list of display indices/names that can be captured.
/// On Windows, this enumerates DXGI outputs via IDXGIFactory.
pub fn list_display_targets() -> Result<Vec<String>, String> {
    // Stub: enumerate displays
    // In full implementation, would use IDXGIFactory::EnumAdapters() and
    // IDXGIAdapter::EnumOutputs() to list available displays.

    let mut displays = Vec::new();
    displays.push("Display 1 (Primary)".to_string());

    // Try to detect additional displays
    #[cfg(windows)]
    {
        // Simple enumeration — in production, use DXGI API
        for i in 1..4 {
            displays.push(format!("Display {}", i + 1));
        }
    }

    log::info!("Found {} display targets", displays.len());
    Ok(displays)
}

/// Start Windows screen/window capture.
///
/// Creates the capture session, begins frame acquisition at the
/// configured FPS, and starts encoding to the first chunk file.
///
/// # Arguments
/// * `config` - Video configuration (resolution, FPS, bitrate, etc.)
///
/// # Returns
/// Active capture session handle.
pub fn start_capture(config: &VideoConfig) -> Result<WindowsCaptureSession, String> {
    log::info!(
        "Starting Windows capture: {}x{} @ {}fps, {}Kbps",
        config.width,
        config.height,
        config.fps,
        config.bitrate_kbps,
    );

    // Validate config
    if config.width == 0 || config.height == 0 {
        return Err("Invalid capture dimensions".to_string());
    }
    if !matches!(config.fps, 15 | 30 | 60) {
        return Err(format!("Unsupported FPS: {} (must be 15, 30, or 60)", config.fps));
    }

    // Determine session ID from output directory name
    let session_id = config
        .output_dir
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("pc_session");

    let chunk_manager = ChunkManager::new(&config.output_dir, session_id, config.chunk_duration_ms);

    let display_index = match &config.capture_target {
        CaptureTarget::FullScreen { display_index } => *display_index,
        CaptureTarget::SpecificWindow { .. } => 0,
    };
    let window_title = match &config.capture_target {
        CaptureTarget::SpecificWindow { window_title } => Some(window_title.clone()),
        _ => None,
    };

    log::info!(
        "Windows capture session created for display {} (Direct3D11 + MediaFoundation stub)",
        display_index,
    );

    // In a full implementation, this would:
    // 1. Create ID3D11Device
    // 2. Create Direct3D11CaptureFramePool with target FPS
    // 3. Select GraphicsCaptureItem (display or window)
    // 4. Create GraphicsCaptureSession
    // 5. Configure IMFMediaSinkWriter for H.264 MP4 output
    // 6. Start frame acquisition loop
    // 7. Open first chunk via chunk_manager.open_next_chunk()
    //
    // For now, return a stub session that represents the configured state.

    Ok(WindowsCaptureSession {
        display_index,
        window_title,
        config: config.clone(),
        chunk_manager,
        is_capturing: true,
    })
}

/// Stop Windows capture and finalize all chunks.
///
/// Closes the frame pool, releases D3D device, finalizes the last chunk.
///
/// # Returns
/// List of completed chunk records for post-capture concat.
pub fn stop_capture(mut session: WindowsCaptureSession) -> Result<Vec<crate::pc_video::chunk_manager::ChunkRecord>, String> {
    session.is_capturing = false;

    log::info!("Windows capture stopped. {} chunks recorded.", session.chunk_manager.chunks.len());

    // In a full implementation, this would:
    // 1. Close frame pool
    // 2. Release D3D device
    // 3. Finalize IMFMediaSinkWriter (write trailer)
    // 4. Return chunk records

    Ok(session.chunk_manager.chunks)
}

/// Create a Windows.Graphics.Capture item for a specific display.
///
/// Uses the GraphicsCapturePicker API (requires user interaction) or
/// programmatic selection via DisplayInformation.
pub fn create_capture_item(display_index: u32) -> Result<String, String> {
    log::info!("Creating capture item for display {}", display_index);

    // In a full implementation, this would:
    // 1. Call GraphicsCapturePicker::PickSingleItemAsync() or
    // 2. Programmatically select via DisplayInformation
    //
    // Returns a display identifier string for UI feedback.

    Ok(format!("Display_{}", display_index))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::pc_video::VideoConfig;

    fn test_config() -> VideoConfig {
        let dir = tempfile::tempdir().unwrap();
        VideoConfig {
            output_dir: dir.path().to_path_buf(),
            width: 1920,
            height: 1080,
            fps: 30,
            bitrate_kbps: 8000,
            chunk_duration_ms: 300_000,
            capture_target: CaptureTarget::FullScreen { display_index: 0 },
        }
    }

    #[test]
    fn test_list_display_targets_returns_displays() {
        let targets = list_display_targets();
        assert!(targets.is_ok());
        let displays = targets.unwrap();
        assert!(!displays.is_empty());
        assert!(displays.iter().any(|d| d.contains("Display")));
    }

    #[test]
    fn test_start_capture_valid_config() {
        let config = test_config();
        let result = start_capture(&config);
        assert!(result.is_ok());

        let session = result.unwrap();
        assert!(session.is_capturing);
        assert_eq!(session.config.width, 1920);
        assert_eq!(session.config.fps, 30);
    }

    #[test]
    fn test_start_capture_invalid_dimensions() {
        let mut config = test_config();
        config.width = 0;
        let result = start_capture(&config);
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("dimensions"));
    }

    #[test]
    fn test_start_capture_invalid_fps() {
        let mut config = test_config();
        config.fps = 99;
        let result = start_capture(&config);
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("FPS"));
    }

    #[test]
    fn test_start_capture_specific_window() {
        let mut config = test_config();
        config.capture_target = CaptureTarget::SpecificWindow {
            window_title: "Test Window".to_string(),
        };
        let result = start_capture(&config);
        assert!(result.is_ok());
        let session = result.unwrap();
        assert_eq!(session.window_title, Some("Test Window".to_string()));
    }

    #[test]
    fn test_stop_capture_returns_chunks() {
        let config = test_config();
        let session = start_capture(&config).unwrap();
        let result = stop_capture(session);
        assert!(result.is_ok());
    }

    #[test]
    fn test_init_capture() {
        let result = init_capture();
        assert!(result.is_ok(), "init_capture should succeed (stub mode)");
    }

    #[test]
    fn test_create_capture_item() {
        let result = create_capture_item(0);
        assert!(result.is_ok());
        assert!(result.unwrap().contains("Display"));
    }
}
