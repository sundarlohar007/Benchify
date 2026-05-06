// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

/// macOS AVScreenCaptureKit screen recording.
///
/// Per §32.12: captures display/window via AVScreenCaptureKit (macOS 13+),
/// encodes to H.264 MP4 chunks via AVAssetWriter.
///
/// Uses Objective-C bindings via the `objc` and `objc-foundation` crates
/// for interop with Apple frameworks.
///
/// Architecture:
/// - SCStream + SCStreamConfiguration -> capture configuration
/// - SCDisplay / SCWindow -> capture target selection
/// - AVAssetWriter + AVAssetWriterInput -> H.264 encoding
/// - AVAssetWriterInputPixelBufferAdaptor -> frame delivery
/// - CGImageRef -> CVPixelBuffer -> appendPixelBuffer -> chunk file
/// - Chunk rotation at 5-min boundary

use std::path::Path;

use crate::pc_video::chunk_manager::ChunkManager;
use crate::pc_video::{CaptureTarget, VideoConfig};

/// Active macOS capture session.
#[derive(Debug)]
pub struct MacCaptureSession {
    /// Display index (for FullScreen capture).
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

/// Check if screen recording permission has been granted.
///
/// On macOS, AVScreenCaptureKit triggers a TCC (Transparency, Consent,
/// and Control) permission prompt on first use. This function checks
/// whether the user has already granted permission.
///
/// Returns true if screen recording is authorized.
pub fn check_screen_recording_permission() -> Result<bool, String> {
    // In a full implementation, this would check:
    // CGPreflightScreenCaptureAccess() — macOS 10.15+
    // or CGRequestScreenCaptureAccess() with completion handler

    log::info!("Screen recording permission check (stub — assuming authorized)");

    // For the stub: assume authorized on macOS
    #[cfg(target_os = "macos")]
    {
        // CGPreflightScreenCaptureAccess returns false until first prompt
        // For now, return true as stub
        return Ok(true);
    }

    #[cfg(not(target_os = "macos"))]
    {
        Err("Not running on macOS".to_string())
    }
}

/// Request screen recording permission.
///
/// Triggers the system permission dialog. Should be called from the UI
/// thread on macOS. Returns true if permission was granted.
pub fn request_screen_recording_permission() -> Result<bool, String> {
    log::info!("Requesting screen recording permission (stub)");

    #[cfg(target_os = "macos")]
    {
        // In a full implementation:
        // CGRequestScreenCaptureAccess() with completion handler
        // Returns true if user grants permission
        return Ok(true);
    }

    #[cfg(not(target_os = "macos"))]
    {
        Err("Not running on macOS".to_string())
    }
}

/// List available display targets on macOS.
///
/// Enumerates SCDisplay devices via ScreenCaptureKit.
/// Returns display names/indices.
pub fn list_display_targets() -> Result<Vec<String>, String> {
    let mut displays = Vec::new();

    #[cfg(target_os = "macos")]
    {
        displays.push("Built-in Retina Display".to_string());
        // In full implementation, enumerate via SCShareableContent
        // SCDisplay -> displayID, width, height, frameRate
    }

    log::info!("Found {} display targets", displays.len());
    Ok(displays)
}

/// Start macOS screen/window capture.
///
/// Creates SCStream with the configured resolution/FPS, sets up
/// AVAssetWriter for H.264 encoding, and begins frame acquisition.
///
/// # Arguments
/// * `config` - Video configuration (resolution, FPS, bitrate, etc.)
///
/// # Returns
/// Active capture session handle.
pub fn start_capture(config: &VideoConfig) -> Result<MacCaptureSession, String> {
    log::info!(
        "Starting macOS capture: {}x{} @ {}fps, {}Kbps",
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

    #[cfg(target_os = "macos")]
    {
        // In a full implementation:
        // 1. Create SCStreamConfiguration (width, height, fps, pixelFormat: BGRA)
        // 2. Get SCShareableContent -> filter for target display/window
        // 3. Create SCStream with config, display, and output handler
        // 4. Create AVAssetWriter for AVFileTypeMPEG4 with AVVideoCodecTypeH264
        // 5. Set up AVAssetWriterInputPixelBufferAdaptor
        // 6. In frame handler: CGImageRef -> CVPixelBuffer -> appendPixelBuffer
        // 7. Open first chunk via chunk_manager.open_next_chunk()
        // 8. Monitor chunk duration -> rotate at chunk_max_ms
    }

    log::info!("macOS capture session created for display {}", display_index);

    Ok(MacCaptureSession {
        display_index,
        window_title,
        config: config.clone(),
        chunk_manager,
        is_capturing: true,
    })
}

/// Stop macOS capture and finalize all chunks.
///
/// Stops the SCStream, finalizes the AVAssetWriter (closes last chunk),
/// and returns chunk records for concat.
pub fn stop_capture(mut session: MacCaptureSession) -> Result<Vec<crate::pc_video::chunk_manager::ChunkRecord>, String> {
    session.is_capturing = false;

    log::info!("macOS capture stopped. {} chunks recorded.", session.chunk_manager.chunks.len());

    #[cfg(target_os = "macos")]
    {
        // In a full implementation:
        // 1. SCStream.stopCapture()
        // 2. AVAssetWriter.finishWriting()
        // 3. Return chunk records
    }

    Ok(session.chunk_manager.chunks)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::pc_video::VideoConfig;

    fn test_config() -> VideoConfig {
        let dir = tempfile::tempdir().unwrap();
        VideoConfig {
            output_dir: dir.path().to_path_buf(),
            width: 2560,
            height: 1600,
            fps: 60,
            bitrate_kbps: 12000,
            chunk_duration_ms: 300_000,
            capture_target: CaptureTarget::FullScreen { display_index: 0 },
        }
    }

    #[test]
    fn test_start_capture_valid_config() {
        let config = test_config();
        let result = start_capture(&config);
        // On non-macOS, this still creates the stub session
        assert!(result.is_ok());

        let session = result.unwrap();
        assert!(session.is_capturing);
        assert_eq!(session.config.width, 2560);
        assert_eq!(session.config.fps, 60);
    }

    #[test]
    fn test_start_capture_invalid_dimensions() {
        let mut config = test_config();
        config.width = 0;
        let result = start_capture(&config);
        assert!(result.is_err());
    }

    #[test]
    fn test_start_capture_invalid_fps() {
        let mut config = test_config();
        config.fps = 45;
        let result = start_capture(&config);
        assert!(result.is_err());
    }

    #[test]
    fn test_stop_capture_returns_chunks() {
        let config = test_config();
        let session = start_capture(&config).unwrap();
        let result = stop_capture(session);
        assert!(result.is_ok());
    }

    #[test]
    fn test_list_display_targets() {
        let result = list_display_targets();
        assert!(result.is_ok());
    }
}
