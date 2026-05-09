// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

//! Cross-platform PC video recording library.
//!
//! Per-platform native capture (per D-10, §32.12):
//! - **Windows**: Windows.Graphics.Capture + Media Foundation -> H.264 MP4
//! - **macOS**: AVScreenCaptureKit + AVAssetWriter -> MP4
//! - **Linux**: ffmpeg subprocess (x11grab / kmsgrab) -> H.264 MP4
//!
//! All platforms use the same 5-minute chunk pattern as Android/iOS video
//! recording (per §32.3). Chunks are raw H.264 NALs, concatenated via ffmpeg
//! concat demuxer (no re-encode) post-capture.

pub mod chunk_manager;

#[cfg(windows)]
pub mod windows_capture;

#[cfg(target_os = "macos")]
pub mod mac_capture;

#[cfg(target_os = "linux")]
pub mod linux_capture;

use std::path::PathBuf;
use std::time::SystemTime;

/// Target platform for video capture.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PcPlatform {
    Windows,
    MacOS,
    Linux,
}

impl PcPlatform {
    /// Detect the current platform at runtime.
    pub fn current() -> Self {
        #[cfg(windows)] { PcPlatform::Windows }
        #[cfg(target_os = "macos")] { PcPlatform::MacOS }
        #[cfg(target_os = "linux")] { PcPlatform::Linux }
        #[cfg(not(any(windows, target_os = "macos", target_os = "linux")))]
        { PcPlatform::Windows } // Fallback
    }
}

/// Video recording configuration.
#[derive(Debug, Clone)]
pub struct VideoConfig {
    /// Output directory for video chunks.
    pub output_dir: PathBuf,

    /// Video width in pixels.
    pub width: u32,

    /// Video height in pixels.
    pub height: u32,

    /// Target FPS (15, 30, or 60).
    pub fps: u32,

    /// Encoding bitrate in Kbps (4000, 8000, 12000, 20000).
    pub bitrate_kbps: u32,

    /// Max duration per chunk in milliseconds (300000 = 5 min per §32.3).
    pub chunk_duration_ms: u64,

    /// What to capture — full display or specific window.
    pub capture_target: CaptureTarget,
}

impl Default for VideoConfig {
    fn default() -> Self {
        Self {
            output_dir: PathBuf::from("./pb_video"),
            width: 1920,
            height: 1080,
            fps: 30,
            bitrate_kbps: 8000,
            chunk_duration_ms: 300_000, // 5 minutes
            capture_target: CaptureTarget::FullScreen { display_index: 0 },
        }
    }
}

/// What to capture on screen.
#[derive(Debug, Clone)]
pub enum CaptureTarget {
    /// Full display (monitor index).
    FullScreen { display_index: u32 },
    /// A specific window by title.
    SpecificWindow { window_title: String },
}

/// Active video recording session.
#[derive(Debug)]
pub struct VideoSession {
    /// Target platform.
    pub platform: PcPlatform,

    /// Recording configuration.
    pub config: VideoConfig,

    /// Chunk manager for rotation.
    pub chunk_manager: chunk_manager::ChunkManager,

    /// Session start time.
    pub start_time: SystemTime,

    /// Currently active chunk path (if recording).
    pub current_chunk: Option<PathBuf>,
}

/// Metadata for a completed video recording (matches videos table schema).
#[derive(Debug, Clone)]
pub struct VideoMetadata {
    pub session_id: String,
    pub filepath: String,
    pub codec: String,
    pub container: String,
    pub width_px: u32,
    pub height_px: u32,
    pub target_fps: u32,
    pub actual_avg_fps: Option<f64>,
    pub bitrate_kbps: u32,
    pub duration_ms: u64,
    pub file_size_bytes: u64,
    pub chunks_json: String,
    pub gaps_json: Option<String>,
    pub has_audio: u8,
    pub recording_overhead_estimate_pct: f64,
    pub started_at: i64,
    pub ended_at: i64,
    pub created_at: i64,
    pub target_kind: String,
}

/// Concatenate H.264 raw chunks into a single MP4 file.
///
/// Uses ffmpeg concat demuxer with `-c copy` (no re-encode) per §32.3.
/// Adds `-movflags +faststart` for web-optimized playback.
///
/// # Arguments
/// * `session` - The video session with completed chunks.
/// * `output_path` - Path where the final MP4 should be written.
pub fn concat_chunks_to_mp4(session: &VideoSession, output_path: &std::path::Path) -> Result<PathBuf, String> {
    let concat_list = session.chunk_manager.build_concat_list();
    if concat_list.is_empty() {
        return Err("No chunks to concatenate".to_string());
    }

    // Write concat list to temp file
    let list_path = session.config.output_dir.join("concat_list.txt");
    std::fs::write(&list_path, &concat_list)
        .map_err(|e| format!("Failed to write concat list: {}", e))?;

    // Run ffmpeg concat (no re-encode), capture stderr for diagnostics
    let output = std::process::Command::new("ffmpeg")
        .args([
            "-f", "concat",
            "-safe", "0",
            "-i", list_path.to_str().unwrap_or("concat_list.txt"),
            "-c", "copy",
            "-movflags", "+faststart",
            "-y", // Overwrite output
        ])
        .arg(output_path)
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::piped())
        .output()
        .map_err(|e| format!("ffmpeg not found or failed to start: {}", e))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!(
            "ffmpeg concat failed (exit code: {:?}): {}",
            output.status.code(),
            stderr.chars().take(500).collect::<String>(),
        ));
    }

    // Clean up temp list
    let _ = std::fs::remove_file(&list_path);

    Ok(output_path.to_path_buf())
}

/// Generate video metadata matching the videos table schema.
///
/// Uses ffprobe to read actual duration, then builds a VideoMetadata
/// struct ready for database insertion.
pub fn generate_video_metadata(
    session: &VideoSession,
    output_path: &std::path::Path,
    session_id: &str,
) -> Result<VideoMetadata, String> {
    // Try to read actual duration via ffprobe
    let duration_ms = read_duration_via_ffprobe(output_path).unwrap_or_else(|_| {
        // Fallback: estimate from chunk records
        session.chunk_manager.chunks.iter().map(|c| c.duration_ms).sum()
    });

    // File size
    let file_size_bytes = std::fs::metadata(output_path)
        .map(|m| m.len())
        .unwrap_or(0);

    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64;

    let started_at = session.start_time
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64;

    let target_kind = match session.platform {
        PcPlatform::Windows => "windows_pc",
        PcPlatform::MacOS => "macos_pc",
        PcPlatform::Linux => "linux_pc",
    };

    Ok(VideoMetadata {
        session_id: session_id.to_string(),
        filepath: output_path.to_string_lossy().to_string(),
        codec: "h264".to_string(),
        container: "mp4".to_string(),
        width_px: session.config.width,
        height_px: session.config.height,
        target_fps: session.config.fps,
        actual_avg_fps: None,
        bitrate_kbps: session.config.bitrate_kbps,
        duration_ms,
        file_size_bytes,
        chunks_json: session.chunk_manager.get_chunks_json(),
        gaps_json: Some(session.chunk_manager.get_gaps_json()),
        has_audio: 0,
        recording_overhead_estimate_pct: 5.0,
        started_at,
        ended_at: now,
        created_at: now,
        target_kind: target_kind.to_string(),
    })
}

/// Read video duration in ms via ffprobe.
fn read_duration_via_ffprobe(path: &std::path::Path) -> Result<u64, String> {
    let output = std::process::Command::new("ffprobe")
        .args([
            "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
        ])
        .arg(path)
        .output()
        .map_err(|e| format!("ffprobe not found: {}", e))?;

    if !output.status.success() {
        return Err("ffprobe command failed".to_string());
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    let seconds: f64 = stdout.trim().parse().map_err(|e| format!("Parse duration: {}", e))?;
    Ok((seconds * 1000.0) as u64)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pc_platform_current() {
        let platform = PcPlatform::current();
        // Should return a valid platform on any host OS
        assert!(matches!(platform, PcPlatform::Windows | PcPlatform::MacOS | PcPlatform::Linux));
    }

    #[test]
    fn test_video_config_default() {
        let config = VideoConfig::default();
        assert_eq!(config.width, 1920);
        assert_eq!(config.height, 1080);
        assert_eq!(config.fps, 30);
        assert_eq!(config.bitrate_kbps, 8000);
        assert_eq!(config.chunk_duration_ms, 300_000);
    }

    #[test]
    fn test_video_metadata_target_kind() {
        let meta = VideoMetadata {
            session_id: "test".to_string(),
            filepath: "test.mp4".to_string(),
            codec: "h264".to_string(),
            container: "mp4".to_string(),
            width_px: 1920,
            height_px: 1080,
            target_fps: 30,
            actual_avg_fps: Some(29.97),
            bitrate_kbps: 8000,
            duration_ms: 300000,
            file_size_bytes: 1024000,
            chunks_json: "[]".to_string(),
            gaps_json: None,
            has_audio: 0,
            recording_overhead_estimate_pct: 5.0,
            started_at: 1000,
            ended_at: 301000,
            created_at: 301000,
            target_kind: "windows_pc".to_string(),
        };
        assert_eq!(meta.target_kind, "windows_pc");
        assert_eq!(meta.codec, "h264");
        assert_eq!(meta.container, "mp4");
    }
}
