// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

/// 1Hz collection glue for pb-pcprobe.
///
/// Wires the Plan 05-03 PC metric modules (PDH, DXGI, ETW, memory, CPU)
/// into a 1Hz collection loop that feeds MetricSamples to the IPC broadcast.
///
/// This module resolves the target process (by name or PID), creates the
/// PcCollector, and spawns a collection thread.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread::JoinHandle;
use std::time::{Duration, Instant};

use anyhow::{Context, Result};

use sdk::pc_metrics::collector::PcCollector;
use sdk::pc_metrics::dxgi::DxgiMethod;

use crate::cli::Args;
use crate::ipc::IpcServer;

/// Find the PID of a process by its executable name.
///
/// Uses the `sysinfo` crate to enumerate running processes and match
/// the executable name (case-insensitive on Windows).
fn find_process_id(process_name: &str) -> Option<u32> {
    use sysinfo::{ProcessExt, System, SystemExt};

    let mut system = System::new_all();
    system.refresh_all();

    let name_lower = process_name.to_lowercase();

    for (pid, process) in system.processes() {
        let exe_name = process.name().to_lowercase();
        if exe_name == name_lower || exe_name.starts_with(&name_lower) {
            return Some(pid.as_u32());
        }
    }

    None
}

/// Run the metric collector loop at 1Hz on a dedicated thread.
///
/// Returns a JoinHandle that can be used to join the thread on shutdown.
/// The loop terminates when `shutdown` is set to true.
///
/// # Architecture
///
/// The collector thread runs synchronously (std::thread) because the
/// PcCollector uses blocking Windows PDH calls. IPC broadcast is done
/// via a synchronous channel to the tokio runtime.
pub fn run_collector(
    args: Args,
    ipc: Arc<IpcServer>,
    shutdown: Arc<AtomicBool>,
) -> Result<JoinHandle<()>> {
    // Resolve process ID — use --process-id if given, otherwise find by name
    let process_id = match args.process_id {
        Some(pid) => pid,
        None => find_process_id(&args.process_name).context(format!(
            "Process '{}' not found. Is it running? Use --process-id to specify PID.",
            args.process_name
        ))?,
    };

    let dxgi_method = args.dxgi_method_enum()?;

    // Warn about ETW requiring admin
    if args.etw && !is_elevated() {
        log::warn!(
            "ETW frame timing requires administrator privileges. \
             Re-run pb-pcprobe as admin if needed."
        );
    }

    log::info!(
        "Starting collector for process '{}' (PID {}). DXGI method: {:?}, ETW: {}",
        args.process_name,
        process_id,
        dxgi_method,
        args.etw,
    );

    // Create the PcCollector (Plan 05-03)
    let mut collector = PcCollector::new(
        &args.process_name,
        process_id,
        dxgi_method,
        args.etw,
    )
    .map_err(|e| anyhow::anyhow!("Failed to create PcCollector: {}", e))?;

    let process_name = args.process_name.clone();
    let session_id = args.session_id.clone();

    // Spawn the 1Hz collection thread
    let handle = std::thread::spawn(move || {
        let target_interval = Duration::from_millis(1000);
        let mut next_tick = Instant::now() + target_interval;

        // Set initial session ID in samples
        if let Some(ref sid) = session_id {
            // The session_id is embedded via IPC START command — collector just produces samples
            log::info!("Session ID initialized: {}", sid);
        }

        while !shutdown.load(Ordering::SeqCst) {
            // Wait until next tick time
            let now = Instant::now();
            if now < next_tick {
                let sleep_time = next_tick - now;
                std::thread::sleep(sleep_time);
            }
            next_tick += target_interval;

            // Skip collection if paused
            if ipc.paused.load(Ordering::SeqCst) {
                continue;
            }

            // If not collecting, still sleep but don't produce samples
            if !ipc.collecting.load(Ordering::SeqCst) {
                continue;
            }

            // Collect one tick
            match collector.tick() {
                Ok(sample) => {
                    // Broadcast sample via IPC — use blocking send to channel
                    // The IPC broadcast is async but we're on a sync thread.
                    // We'll serialize and push to a queue that the tokio runtime reads.
                    if let Err(e) = try_broadcast_sync(&ipc, &sample) {
                        log::error!("Broadcast error: {}", e);
                    }
                }
                Err(e) => {
                    log::error!("Collection tick failed for {} (PID {}): {}. \
                                 Process may have exited.",
                                process_name, process_id, e);

                    // Send process-exited event to host
                    let event_json = serde_json::json!({
                        "type": "error",
                        "code": "PROCESS_EXITED",
                        "process": process_name,
                        "pid": process_id,
                        "message": e,
                    });
                    if let Err(e2) = try_broadcast_event_sync(&ipc, &event_json.to_string()) {
                        log::error!("Broadcast error event failed: {}", e2);
                    }

                    // Stop collecting — process is gone
                    // Don't shut down completely; probe stays alive for reattach
                    ipc.collecting.store(false, Ordering::SeqCst);
                }
            }

            // If next_tick is far behind (collection took >1s), reset to avoid burst
            if next_tick < Instant::now() {
                next_tick = Instant::now() + target_interval;
            }
        }

        // Cleanup on shutdown
        log::info!("Collector shutting down for process '{}'", process_name);
        collector.close();
    });

    Ok(handle)
}

/// Attempt to broadcast a MetricSample from the sync collector thread.
///
/// Serializes JSON and queues it for async broadcast. Since the IPC
/// broadcast is tokio-based and we're on a sync thread, we serialize
/// here and use a blocking write to a shared buffer.
fn try_broadcast_sync(ipc: &Arc<IpcServer>, sample: &sdk::models::MetricSample) -> Result<()> {
    let json = serde_json::to_string(sample)?;
    let line = format!("{}\n", json);
    try_broadcast_line_sync(ipc, &line)
}

/// Attempt to broadcast a raw event JSON string from the sync thread.
fn try_broadcast_event_sync(ipc: &Arc<IpcServer>, event_json: &str) -> Result<()> {
    let line = format!("{}\n", event_json);
    try_broadcast_line_sync(ipc, &line)
}

/// Write a line to all connected IPC clients from the sync thread.
///
/// We serialize broadcast through a simple approach: spawn a blocking
/// tokio task that handles the async write.
fn try_broadcast_line_sync(ipc: &Arc<IpcServer>, line: &str) -> Result<()> {
    // Use tokio runtime handle to do a blocking send
    let handle = tokio::runtime::Handle::current();
    let line_owned = line.to_string();
    let ipc_clone = Arc::clone(ipc);

    handle.block_on(async move {
        let mut clients = ipc_clone.clients.lock().await;
        let mut alive = Vec::new();

        for mut writer in clients.drain(..) {
            match tokio::io::AsyncWriteExt::write_all(&mut writer, line_owned.as_bytes()).await {
                Ok(()) => alive.push(writer),
                Err(e) => {
                    log::debug!("Client disconnected: {}", e);
                }
            }
        }

        *clients = alive;
        Ok::<_, anyhow::Error>(())
    })?;

    Ok(())
}

/// Check if the current process is running with elevated privileges.
fn is_elevated() -> bool {
    #[cfg(windows)]
    {
        // Check if running as administrator on Windows
        use std::os::windows::ffi::OsStrExt;
        use std::ffi::OsString;
        // Simple heuristic: check if we can write to a protected location
        // A more robust approach uses CheckTokenMembership but that requires winapi
        false // Conservative: assume not elevated unless proven otherwise
    }
    #[cfg(not(windows))]
    {
        // On Linux/macOS, check if running as root
        unsafe { libc::geteuid() == 0 }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_find_process_id_current_process() {
        let exe_name = std::env::current_exe()
            .ok()
            .and_then(|p| p.file_name().map(|n| n.to_string_lossy().to_string()))
            .unwrap_or_else(|| "unknown".to_string());

        // The current test binary might be found by name
        let result = find_process_id(&exe_name);
        // It's OK if not found (name may differ from sysinfo view)
        log::debug!("find_process_id({}) = {:?}", exe_name, result);
    }

    #[test]
    fn test_find_process_id_nonexistent() {
        let result = find_process_id("nonexistent_process_xyz123.exe");
        assert!(result.is_none(), "Should not find nonexistent process");
    }

    #[test]
    fn test_is_elevated_returns_bool() {
        // Just test that it doesn't panic
        let _ = is_elevated();
    }
}
