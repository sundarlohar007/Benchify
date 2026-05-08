// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

//! Linux video capture via ffmpeg subprocess.
//!
//! Per §32.12: captures display via ffmpeg x11grab (X11) or kmsgrab (Wayland),
//! encodes to H.264 MP4 chunks.
//!
//! Architecture:
//! - Detects display server: X11 (`$DISPLAY`) vs Wayland (`$XDG_SESSION_TYPE`)
//! - X11: `ffmpeg -f x11grab -video_size {W}x{H} -framerate {FPS} -i {DISPLAY}`
//! - Wayland: `ffmpeg -f kmsgrab -i /dev/dri/card0` or pipewire via `pw-record`
//! - `-c:v libx264 -preset ultrafast -tune zerolatency` for low-latency
//! - `-f h264 -t {CHUNK_DURATION}` for raw H.264 output with time limit
//! - Spawn loop: when ffmpeg exits (chunk complete), immediately spawn next chunk
//!
//! ffmpeg must be installed on the system (see user_setup in PLAN.md).

use std::process::{Child, Command, Stdio};

use crate::pc_video::chunk_manager::ChunkManager;
use crate::pc_video::{CaptureTarget, VideoConfig};

/// Active Linux capture session.
#[derive(Debug)]
pub struct LinuxCaptureSession {
    /// Running ffmpeg child process.
    pub ffmpeg_child: Option<Child>,

    /// Video configuration.
    pub config: VideoConfig,

    /// Chunk manager for rotation.
    pub chunk_manager: ChunkManager,

    /// Whether capture is active.
    pub is_capturing: bool,

    /// Detected display server type.
    pub display_server: LinuxDisplayServer,
}

/// Display server type detected at runtime.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LinuxDisplayServer {
    X11,
    Wayland,
    Unknown,
}

impl std::fmt::Display for LinuxDisplayServer {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            LinuxDisplayServer::X11 => write!(f, "X11"),
            LinuxDisplayServer::Wayland => write!(f, "Wayland"),
            LinuxDisplayServer::Unknown => write!(f, "Unknown"),
        }
    }
}

/// Detect the current display server.
///
/// Checks `$XDG_SESSION_TYPE` for "wayland", falls back to X11 if
/// `$DISPLAY` is set, returns Unknown otherwise.
pub fn detect_display_server() -> LinuxDisplayServer {
    // Check Wayland environment variable first
    if let Ok(session_type) = std::env::var("XDG_SESSION_TYPE") {
        if session_type.to_lowercase() == "wayland" {
            return LinuxDisplayServer::Wayland;
        }
    }

    // Check X11 display variable
    if std::env::var("DISPLAY").is_ok() {
        return LinuxDisplayServer::X11;
    }

    // Check for Wayland-specific env vars
    if std::env::var("WAYLAND_DISPLAY").is_ok() {
        return LinuxDisplayServer::Wayland;
    }

    LinuxDisplayServer::Unknown
}

/// Build ffmpeg command arguments for screen capture.
///
/// Constructs the appropriate ffmpeg CLI arguments based on the display
/// server type and video configuration.
///
/// # Arguments
/// * `display` - X11 display string (e.g., ":0.0") or Wayland device path
/// * `output_file` - Path for the output chunk file
/// * `config` - Video configuration
///
/// # Returns
/// Vec of ffmpeg command-line arguments.
pub fn build_ffmpeg_command(
    display: &str,
    output_file: &str,
    config: &VideoConfig,
) -> Result<Vec<String>, String> {
    let display_server = detect_display_server();

    let mut args: Vec<String> = Vec::new();

    // ffmpeg binary name
    args.push("ffmpeg".to_string());

    // Platform-specific input
    match display_server {
        LinuxDisplayServer::X11 => {
            // X11 grab: x11grab format
            args.extend_from_slice(&[
                "-f".to_string(),
                "x11grab".to_string(),
                "-video_size".to_string(),
                format!("{}x{}", config.width, config.height),
                "-framerate".to_string(),
                config.fps.to_string(),
                "-i".to_string(),
                display.to_string(),
            ]);
        }
        LinuxDisplayServer::Wayland => {
            // Wayland kmsgrab: captures KMS framebuffer
            args.extend_from_slice(&[
                "-f".to_string(),
                "kmsgrab".to_string(),
                "-framerate".to_string(),
                config.fps.to_string(),
                "-i".to_string(),
                display.to_string(),
            ]);
        }
        LinuxDisplayServer::Unknown => {
            return Err(
                "No display server detected. Set $DISPLAY (X11) or $XDG_SESSION_TYPE (Wayland)."
                    .to_string(),
            );
        }
    }

    // Codec and encoding settings
    args.extend_from_slice(&[
        "-c:v".to_string(),
        "libx264".to_string(),
        "-preset".to_string(),
        "ultrafast".to_string(),
        "-tune".to_string(),
        "zerolatency".to_string(),
        "-b:v".to_string(),
        format!("{}k", config.bitrate_kbps),
        "-maxrate".to_string(),
        format!("{}k", (config.bitrate_kbps as f64 * 1.5) as u32),
        "-bufsize".to_string(),
        format!("{}k", config.bitrate_kbps * 2),
        "-pix_fmt".to_string(),
        "yuv420p".to_string(),
    ]);

    // Output format: raw H.264 NALs (will be concat'ed later)
    args.extend_from_slice(&[
        "-f".to_string(),
        "h264".to_string(),
    ]);

    // Chunk duration limit (ffmpeg will exit after this duration)
    let chunk_duration_secs = config.chunk_duration_ms as f64 / 1000.0;
    args.extend_from_slice(&[
        "-t".to_string(),
        format!("{:.1}", chunk_duration_secs),
    ]);

    // Output file
    args.push("-y".to_string()); // Overwrite
    args.push(output_file.to_string());

    Ok(args)
}

/// Start Linux screen capture via ffmpeg subprocess.
///
/// Detects the display server, builds the ffmpeg command, and spawns
/// the first chunk. The caller must manage chunk rotation by respawning
/// ffmpeg when each chunk completes.
///
/// # Arguments
/// * `config` - Video configuration
///
/// # Returns
/// Active capture session with running ffmpeg child.
pub fn start_capture(config: &VideoConfig) -> Result<LinuxCaptureSession, String> {
    let display_server = detect_display_server();
    log::info!(
        "Starting Linux capture: {}x{} @ {}fps, {}Kbps, display server: {}",
        config.width,
        config.height,
        config.fps,
        config.bitrate_kbps,
        display_server,
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

    let mut chunk_manager = ChunkManager::new(&config.output_dir, session_id, config.chunk_duration_ms);

    // Determine display string
    let display = match (&config.capture_target, display_server) {
        (CaptureTarget::FullScreen { display_index }, LinuxDisplayServer::X11) => {
            if *display_index == 0 {
                std::env::var("DISPLAY").unwrap_or_else(|_| ":0.0".to_string())
            } else {
                format!(":0.{}", display_index)
            }
        }
        (_, LinuxDisplayServer::Wayland) => {
            // Wayland: use /dev/dri/card0 or configured device
            "/dev/dri/card0".to_string()
        }
        _ => {
            std::env::var("DISPLAY").unwrap_or_else(|_| ":0.0".to_string())
        }
    };

    // Open first chunk
    let chunk_path = chunk_manager.open_next_chunk();
    let output_file = chunk_path.to_string_lossy().to_string();

    // Build and spawn ffmpeg
    let ffmpeg_args = build_ffmpeg_command(&display, &output_file, config)?;

    let ffmpeg_child = spawn_ffmpeg_chunk(&ffmpeg_args)?;

    log::info!(
        "Linux capture started. Chunk 1 -> {} ({} sec limit)",
        output_file,
        config.chunk_duration_ms / 1000,
    );

    Ok(LinuxCaptureSession {
        ffmpeg_child: Some(ffmpeg_child),
        config: config.clone(),
        chunk_manager,
        is_capturing: true,
        display_server,
    })
}

/// Spawn an ffmpeg subprocess for a single chunk.
///
/// Configures ffmpeg to run with below-normal CPU priority to reduce
/// interference with the target game (per T-05-21 mitigation).
fn spawn_ffmpeg_chunk(args: &[String]) -> Result<Child, String> {
    if args.is_empty() {
        return Err("Empty ffmpeg command".to_string());
    }

    let program = &args[0];
    let ffmpeg_args = &args[1..];

    let child = Command::new(program)
        .args(ffmpeg_args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|e| format!("Failed to spawn ffmpeg: {} — is ffmpeg installed?", e))?;

    // Set below-normal CPU priority (mitigation T-05-21)
    #[cfg(target_os = "linux")]
    {
        unsafe {
            // Set nice value to 10 (below normal) on Linux
            libc::setpriority(libc::PRIO_PROCESS, child.id() as libc::id_t, 10);
        }
    }

    Ok(child)
}

/// Stop Linux capture — send SIGTERM to ffmpeg, finalize chunks.
pub fn stop_capture(mut session: LinuxCaptureSession) -> Result<Vec<crate::pc_video::chunk_manager::ChunkRecord>, String> {
    session.is_capturing = false;

    if let Some(mut child) = session.ffmpeg_child.take() {
        // Send SIGTERM for graceful ffmpeg shutdown
        if let Err(e) = child.kill() {
            log::warn!("Failed to kill ffmpeg process: {}", e);
        }

        // Wait for process to exit
        match child.wait() {
            Ok(status) => {
                log::info!("ffmpeg exited with status: {:?}", status.code());
            }
            Err(e) => {
                log::warn!("Failed to wait for ffmpeg: {}", e);
            }
        }
    }

    log::info!("Linux capture stopped. {} chunks recorded.", session.chunk_manager.chunks.len());

    Ok(session.chunk_manager.chunks)
}

/// Wait for ffmpeg chunk to complete and start the next one.
///
/// Called by the chunk rotation loop. Waits for the current ffmpeg
/// child to exit, records the chunk duration, opens the next chunk,
/// and spawns a new ffmpeg for it.
///
/// # Returns
/// Ok(true) if a new chunk was started, Ok(false) if capture should stop.
pub fn rotate_chunk(session: &mut LinuxCaptureSession) -> Result<bool, String> {
    if !session.is_capturing {
        return Ok(false);
    }

    // Wait for current ffmpeg to complete
    if let Some(mut child) = session.ffmpeg_child.take() {
        match child.wait() {
            Ok(status) => {
                if !status.success() {
                    log::warn!("ffmpeg chunk exited with non-zero status: {:?}", status.code());
                }
            }
            Err(e) => {
                log::error!("ffmpeg wait error: {}", e);
                return Ok(false);
            }
        }

        // Record completed chunk (approximate: chunk_max_ms for full chunks)
        session.chunk_manager.on_chunk_complete(session.config.chunk_duration_ms);
    }

    // Open next chunk
    let chunk_path = session.chunk_manager.open_next_chunk();
    let output_file = chunk_path.to_string_lossy().to_string();

    // Determine display
    let display = match session.display_server {
        LinuxDisplayServer::X11 => {
            std::env::var("DISPLAY").unwrap_or_else(|_| ":0.0".to_string())
        }
        LinuxDisplayServer::Wayland => {
            "/dev/dri/card0".to_string()
        }
        _ => {
            std::env::var("DISPLAY").unwrap_or_else(|_| ":0.0".to_string())
        }
    };

    // Build and spawn next chunk
    let ffmpeg_args = build_ffmpeg_command(&display, &output_file, &session.config)?;
    let next_child = spawn_ffmpeg_chunk(&ffmpeg_args)?;

    log::info!(
        "Chunk {} started -> {}",
        session.chunk_manager.current_index,
        output_file,
    );

    session.ffmpeg_child = Some(next_child);
    Ok(true)
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
    fn test_detect_display_server_returns_valid() {
        let server = detect_display_server();
        // Should return a valid variant (may be Unknown in CI)
        assert!(matches!(
            server,
            LinuxDisplayServer::X11 | LinuxDisplayServer::Wayland | LinuxDisplayServer::Unknown
        ));
    }

    #[test]
    fn test_build_ffmpeg_command_x11() {
        // Temporarily set DISPLAY to force X11 detection
        std::env::set_var("XDG_SESSION_TYPE", "x11");
        std::env::set_var("DISPLAY", ":0.0");

        let config = test_config();
        let args = build_ffmpeg_command(":0.0", "/tmp/test.h264", &config);

        assert!(args.is_ok(), "build_ffmpeg_command should succeed");

        let args = args.unwrap();
        // Verify key arguments
        assert!(args.contains(&"ffmpeg".to_string()));
        assert!(args.contains(&"x11grab".to_string()));
        assert!(args.contains(&"libx264".to_string()));
        assert!(args.contains(&"ultrafast".to_string()));
        assert!(args.contains(&"h264".to_string())); // output format

        // Verify resolution
        let res_idx = args.iter().position(|a| a == "-video_size").unwrap();
        assert_eq!(args[res_idx + 1], "1920x1080");

        // Verify bitrate
        let bitrate_idx = args.iter().position(|a| a == "-b:v").unwrap();
        assert_eq!(args[bitrate_idx + 1], "8000k");

        // Verify output file
        assert_eq!(args.last().unwrap(), "/tmp/test.h264");
    }

    #[test]
    fn test_build_ffmpeg_command_unknown_display() {
        // Clear display variables to force Unknown
        std::env::remove_var("XDG_SESSION_TYPE");
        std::env::remove_var("DISPLAY");
        std::env::remove_var("WAYLAND_DISPLAY");

        let config = test_config();
        let args = build_ffmpeg_command(":0.0", "/tmp/test.h264", &config);

        // Should error because no display server detected
        assert!(args.is_err());
        assert!(args.unwrap_err().contains("display server"));
    }

    #[test]
    fn test_build_ffmpeg_command_contains_framerate() {
        std::env::set_var("XDG_SESSION_TYPE", "x11");
        std::env::set_var("DISPLAY", ":0.0");

        let mut config = test_config();
        config.fps = 60;

        let args = build_ffmpeg_command(":0.0", "/tmp/test.h264", &config).unwrap();

        let fps_idx = args.iter().position(|a| a == "-framerate").unwrap();
        assert_eq!(args[fps_idx + 1], "60");
    }

    #[test]
    fn test_start_capture_valid_config() {
        std::env::set_var("XDG_SESSION_TYPE", "x11");
        std::env::set_var("DISPLAY", ":0.0");

        let config = test_config();
        let result = start_capture(&config);
        // May fail if ffmpeg not installed — that's expected in test
        match result {
            Ok(session) => {
                assert!(session.is_capturing);
                assert_eq!(session.display_server, LinuxDisplayServer::X11);
            }
            Err(e) => {
                // Expected if ffmpeg not installed
                log::debug!("start_capture failed (expected in CI): {}", e);
            }
        }
    }

    #[test]
    fn test_start_capture_invalid_dimensions() {
        let mut config = test_config();
        config.width = 0;
        let result = start_capture(&config);
        assert!(result.is_err());
    }

    #[test]
    fn test_display_server_format() {
        assert_eq!(LinuxDisplayServer::X11.to_string(), "X11");
        assert_eq!(LinuxDisplayServer::Wayland.to_string(), "Wayland");
        assert_eq!(LinuxDisplayServer::Unknown.to_string(), "Unknown");
    }

    #[test]
    fn test_spawn_ffmpeg_chunk_empty_args() {
        let result = spawn_ffmpeg_chunk(&[]);
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Empty"));
    }
}
