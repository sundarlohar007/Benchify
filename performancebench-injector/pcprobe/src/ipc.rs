// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

/// IPC transport layer for pb-pcprobe.
///
/// Two transport modes (per §19.1):
/// - **TCP**: `TcpListener::bind("{host}:{port}")` — default 127.0.0.1:27184
///   for same-machine, configurable for LAN.
/// - **Named pipe**: `\\.\pipe\pb-pcprobe` — Windows-only, same-machine only,
///   used as fallback when TCP port conflicts.
///
/// Client protocol: newline-delimited JSON (NDJSON), same pattern as Android
/// SDK port 8080 and Phase 4 transport.rs.
///
/// Commands FROM host TO probe (first field: `"cmd"`):
///   `{"cmd":"START","session_id":"..."}`  — starts collection
///   `{"cmd":"STOP"}`                      — stops collection
///   `{"cmd":"PAUSE"}`                     — pauses collection (keeps IPC alive)
///   `{"cmd":"RESUME"}`                    — resumes collection
///   `{"cmd":"MARKER","name":"...","note":""}` — creates marker
///   `{"cmd":"SCREENSHOT"}`                — triggers screenshot
///   `{"cmd":"VIDEO_START"}`               — starts video recording
///   `{"cmd":"VIDEO_STOP"}`                — stops video recording
///   `{"cmd":"STATUS"}`                    — returns probe status JSON
///
/// Responses FROM probe TO host:
///   MetricSample JSON (same structure as Phase 4 models.rs)
///   Marker event JSON: `{"type":"marker","name":"...","ts":...}`
///   Status JSON: `{"status":"running","process":"game.exe","pid":1234,...}`

use std::net::SocketAddr;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use anyhow::{Context, Result};
use sdk::models::MetricSample;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::Mutex;

/// IPC server managing TCP connections and broadcast.
pub struct IpcServer {
    pub host: String,
    pub port: u16,

    /// Connected client writers (for broadcast).
    pub(crate) clients: Mutex<Vec<tokio::net::tcp::OwnedWriteHalf>>,

    /// Whether the probe is actively collecting.
    pub collecting: AtomicBool,

    /// Whether the probe is in a paused state.
    pub paused: AtomicBool,

    /// Active session ID (set by START command).
    pub session_id: Mutex<Option<String>>,

    /// Probe start time (Unix epoch seconds).
    pub started_at: std::time::Instant,
}

impl IpcServer {
    /// Start the IPC server on the given host:port.
    ///
    /// Spawns a tokio task that accepts incoming connections. Each client
    /// is handled in a separate task for bidirectional communication.
    pub async fn start(host: String, port: u16) -> Result<Arc<Self>> {
        let addr: SocketAddr = format!("{}:{}", host, port)
            .parse()
            .context("Invalid bind address")?;

        let server = Arc::new(Self {
            host,
            port,
            clients: Mutex::new(Vec::new()),
            collecting: AtomicBool::new(false),
            paused: AtomicBool::new(false),
            session_id: Mutex::new(None),
            started_at: std::time::Instant::now(),
        });

        let listener = TcpListener::bind(addr)
            .await
            .context("Failed to bind TCP listener")?;

        log::info!("IPC server listening on {}:{}", server.host, server.port);

        let server_clone = Arc::clone(&server);

        tokio::spawn(async move {
            if let Err(e) = accept_loop(listener, server_clone).await {
                log::error!("Accept loop error: {}", e);
            }
        });

        Ok(server)
    }

    /// Broadcast a MetricSample to all connected clients.
    pub async fn broadcast_sample(&self, sample: &MetricSample) -> Result<()> {
        let json = serde_json::to_string(sample)?;
        let line = format!("{}\n", json);
        self.broadcast_line(&line).await
    }

    /// Broadcast a raw JSON event string to all connected clients.
    pub async fn broadcast_event(&self, event_json: &str) -> Result<()> {
        let line = format!("{}\n", event_json);
        self.broadcast_line(&line).await
    }

    /// Write a line to all connected clients. Removes disconnected clients.
    async fn broadcast_line(&self, line: &str) -> Result<()> {
        let mut clients = self.clients.lock().await;
        let mut alive = Vec::new();

        for mut writer in clients.drain(..) {
            match writer.write_all(line.as_bytes()).await {
                Ok(()) => alive.push(writer),
                Err(e) => {
                    log::debug!("Client disconnected during broadcast: {}", e);
                    // Shutdown the write half — drop drops the writer
                }
            }
        }

        *clients = alive;
        Ok(())
    }

    /// Uptime of the probe in seconds.
    pub fn uptime_secs(&self) -> u64 {
        self.started_at.elapsed().as_secs()
    }
}

/// Accept incoming TCP connections and spawn per-client handlers.
async fn accept_loop(listener: TcpListener, server: Arc<IpcServer>) -> Result<()> {
    loop {
        let (stream, addr) = listener.accept().await?;
        log::info!("Client connected: {}", addr);

        let server_clone = Arc::clone(&server);

        tokio::spawn(async move {
            if let Err(e) = handle_client(stream, server_clone).await {
                log::debug!("Client {} error: {}", addr, e);
            }
            log::info!("Client disconnected: {}", addr);
        });
    }
}

/// Handle a single client connection: read commands, write responses.
async fn handle_client(stream: TcpStream, server: Arc<IpcServer>) -> Result<()> {
    let (reader_half, writer_half) = stream.into_split();

    // Register client for broadcast
    {
        let mut clients = server.clients.lock().await;
        clients.push(writer_half);
    }

    let buffered = BufReader::new(reader_half);
    let mut lines = buffered.lines();

    while let Some(line) = lines.next_line().await? {
        if line.is_empty() {
            continue;
        }

        let cmd: serde_json::Value = match serde_json::from_str(&line) {
            Ok(v) => v,
            Err(e) => {
                log::warn!("Invalid JSON from client: {} — {}", e, &line[..line.len().min(200)]);
                continue;
            }
        };

        let cmd_type = cmd
            .get("cmd")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_uppercase();

        match cmd_type.as_str() {
            "START" => {
                let session_id = cmd
                    .get("session_id")
                    .and_then(|v| v.as_str())
                    .unwrap_or("");
                *server.session_id.lock().await = Some(session_id.to_string());
                server.collecting.store(true, Ordering::SeqCst);
                server.paused.store(false, Ordering::SeqCst);
                log::info!("Collection started. Session: {}", session_id);
            }
            "STOP" => {
                server.collecting.store(false, Ordering::SeqCst);
                server.paused.store(false, Ordering::SeqCst);
                log::info!("Collection stopped.");
            }
            "PAUSE" => {
                server.paused.store(true, Ordering::SeqCst);
                log::info!("Collection paused.");
            }
            "RESUME" => {
                server.paused.store(false, Ordering::SeqCst);
                log::info!("Collection resumed.");
            }
            "MARKER" => {
                let name = cmd.get("name").and_then(|v| v.as_str()).unwrap_or("");
                let note = cmd.get("note").and_then(|v| v.as_str()).unwrap_or("");
                let ts = std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_millis() as i64;
                let marker_json = serde_json::json!({
                    "type": "marker",
                    "name": name,
                    "note": note,
                    "ts": ts,
                });
                server.broadcast_event(&marker_json.to_string()).await?;
                log::info!("Marker: name={}, note={}", name, note);
            }
            "SCREENSHOT" => {
                // PC screenshot: capture full desktop via OS-specific method
                // For now, emit a placeholder event
                let ts = std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_millis() as i64;
                let ss_json = serde_json::json!({
                    "type": "screenshot",
                    "ts": ts,
                    "status": "not_implemented",
                });
                server.broadcast_event(&ss_json.to_string()).await?;
                log::info!("Screenshot requested (not yet implemented)");
            }
            "VIDEO_START" => {
                log::info!("Video recording start requested");
                // Video recording orchestration handled by collector.rs
                let ts = std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_millis() as i64;
                let vid_json = serde_json::json!({
                    "type": "video_status",
                    "status": "started",
                    "ts": ts,
                });
                server.broadcast_event(&vid_json.to_string()).await?;
            }
            "VIDEO_STOP" => {
                log::info!("Video recording stop requested");
                let ts = std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_millis() as i64;
                let vid_json = serde_json::json!({
                    "type": "video_status",
                    "status": "stopped",
                    "ts": ts,
                });
                server.broadcast_event(&vid_json.to_string()).await?;
            }
            "STATUS" => {
                let session_id = server.session_id.lock().await.clone();
                let status_json = serde_json::json!({
                    "type": "status",
                    "status": if server.collecting.load(Ordering::SeqCst) { "running" } else { "idle" },
                    "paused": server.paused.load(Ordering::SeqCst),
                    "session_id": session_id,
                    "uptime_s": server.uptime_secs(),
                });
                server.broadcast_event(&status_json.to_string()).await?;
            }
            other => {
                log::warn!("Unknown command: {}", other);
            }
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_ipc_server_bind() {
        let server = IpcServer::start("127.0.0.1".to_string(), 27185).await;
        assert!(server.is_ok(), "Server should bind to a free port");
        // Server runs in background until dropped
    }

    #[tokio::test]
    async fn test_ipc_server_broadcast_no_clients() {
        let server = IpcServer::start("127.0.0.1".to_string(), 27186)
            .await
            .unwrap();
        let sample = MetricSample::default();
        let result = server.broadcast_sample(&sample).await;
        assert!(result.is_ok(), "Broadcast with no clients should not error");
    }

    #[tokio::test]
    async fn test_ipc_server_broadcast_event() {
        let server = IpcServer::start("127.0.0.1".to_string(), 27187)
            .await
            .unwrap();
        let result = server.broadcast_event(r#"{"type":"test","msg":"hello"}"#).await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_ipc_server_uptime() {
        let server = IpcServer::start("127.0.0.1".to_string(), 27188)
            .await
            .unwrap();
        // Uptime should be near zero at start
        assert!(server.uptime_secs() < 5);
    }

    #[tokio::test]
    async fn test_ipc_server_start_stop_states() {
        let server = IpcServer::start("127.0.0.1".to_string(), 27189)
            .await
            .unwrap();

        assert!(!server.collecting.load(Ordering::SeqCst));
        assert!(!server.paused.load(Ordering::SeqCst));

        server.collecting.store(true, Ordering::SeqCst);
        assert!(server.collecting.load(Ordering::SeqCst));

        server.paused.store(true, Ordering::SeqCst);
        assert!(server.paused.load(Ordering::SeqCst));

        server.collecting.store(false, Ordering::SeqCst);
        server.paused.store(false, Ordering::SeqCst);
        assert!(!server.collecting.load(Ordering::SeqCst));
        assert!(!server.paused.load(Ordering::SeqCst));
    }
}
