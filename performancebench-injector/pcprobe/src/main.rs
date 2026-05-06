// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

//! # pb-pcprobe — PerformanceBench PC Profiling Agent
//!
//! The pb-pcprobe binary is the PC equivalent of the Android SDK .so — a
//! lightweight agent that runs on the target PC, collects performance
//! metrics, and streams them to the PerformanceBench desktop host.
//!
//! ## Architecture (per §19.7, D-09)
//!
//! 1. CLI flag parsing (process name/PID, DXGI method, ETW, video, mDNS)
//! 2. mDNS/Bonjour auto-discovery advertisement
//! 3. TCP/pipe IPC server on 127.0.0.1:27184 (or custom host:port)
//! 4. 1Hz metric collection loop (wires Plan 05-03 PC modules)
//! 5. Graceful shutdown on Ctrl+C or IPC STOP command
//!
//! ## Threat Model
//!
//! - IPC binds to 127.0.0.1 by default — not routable (T-05-17)
//! - LAN mode is opt-in via --host 0.0.0.0 with warning (T-05-19)
//! - Probe runs as user process (no SYSTEM/admin unless ETW, T-05-20)
//! - mDNS advertisement is local network only — no internet exposure (T-05-16)

mod cli;
mod collector;
mod discovery;
mod ipc;

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use clap::Parser;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize logging (stderr, controlled by RUST_LOG env)
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info"))
        .format_timestamp_millis()
        .init();

    // Parse CLI arguments
    let args = cli::Args::parse();

    // Validate DXGI method early
    if let Err(e) = args.dxgi_method_enum() {
        log::error!("{}", e);
        std::process::exit(1);
    }

    // Validate process name is provided
    if args.process_name.is_empty() {
        log::error!("--process-name is required.");
        std::process::exit(1);
    }

    // LAN mode warning (per T-05-19)
    if args.host != "127.0.0.1" && args.host != "localhost" {
        log::warn!(
            "============================================================\n\
             WARNING: Exposing probe to LAN on {}:{}.\n\
             Ensure firewall rules restrict access to trusted hosts.\n\
             ============================================================",
            args.host,
            args.port
        );
    }

    // Build LAN warning for log
    let _ = args.host.clone(); // used above for LAN warning

    log::info!(
        "pb-pcprobe v{} starting for process '{}'. IPC on {}:{}.",
        env!("CARGO_PKG_VERSION"),
        args.process_name,
        args.host,
        args.port
    );

    // Shared shutdown signal
    let shutdown = Arc::new(AtomicBool::new(false));

    // Step 1: Start mDNS advertisement (if enabled)
    let _mdns_daemon = if args.mdns {
        match discovery::advertise_pcprobe(args.port) {
            Ok(daemon) => {
                log::info!("mDNS discovery enabled on port {}", args.port);
                Some(daemon)
            }
            Err(e) => {
                log::warn!("mDNS advertisement failed: {}. Continuing without auto-discovery. \
                            Use --host to connect manually.", e);
                None
            }
        }
    } else {
        None
    };

    // Step 2: Start IPC server
    let ipc = match ipc::IpcServer::start(args.host.clone(), args.port).await {
        Ok(server) => server,
        Err(e) => {
            log::error!("Failed to start IPC server: {}", e);
            // Try named pipe fallback on Windows
            #[cfg(windows)]
            {
                log::info!("Attempting named pipe fallback: \\\\.\\pipe\\pb-pcprobe");
                log::warn!("Named pipe fallback not yet implemented. Exiting.");
            }
            return Err(e);
        }
    };

    // Step 3: Start collector thread
    let collector_handle = match collector::run_collector(args, Arc::clone(&ipc), Arc::clone(&shutdown)) {
        Ok(handle) => {
            log::info!("Collector started at 1Hz.");
            Some(handle)
        }
        Err(e) => {
            log::error!("Failed to start collector: {}", e);
            return Err(e);
        }
    };

    log::info!(
        "pb-pcprobe ready. Stream JSON/TCP on {}:{}. Press Ctrl+C to stop.",
        ipc.host,
        ipc.port
    );

    // Step 4: Wait for shutdown signal (Ctrl+C)
    let shutdown_clone = Arc::clone(&shutdown);
    tokio::spawn(async move {
        tokio::signal::ctrl_c().await.ok();
        log::info!("Ctrl+C received. Shutting down...");
        shutdown_clone.store(true, Ordering::SeqCst);
    });

    // Main loop: wait for shutdown
    while !shutdown.load(Ordering::SeqCst) {
        tokio::time::sleep(tokio::time::Duration::from_millis(250)).await;
    }

    // Step 5: Graceful cleanup
    log::info!("Shutting down collector...");
    if let Some(handle) = collector_handle {
        let _ = handle.join();
    }

    // mDNS daemon will be dropped here (unregisters service)
    log::info!("pb-pcprobe stopped.");

    Ok(())
}
