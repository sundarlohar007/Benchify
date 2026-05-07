use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::{Extension, Json, Path, State};
use axum::http::StatusCode;
use axum::response::IntoResponse;
use futures_util::{SinkExt, StreamExt};
use serde::Deserialize;
use uuid::Uuid;

use models::metric_sample::MetricSample;
use crate::error::AppError;
use crate::state::AppState;
use crate::utils::jwt::AuthUser;

/// WebSocket upgrade handler for /ws/live/:session_id (D-47, V20-17).
/// Browser clients connect to receive real-time metric samples.
pub async fn ws_handler(
    ws: WebSocketUpgrade,
    State(state): State<AppState>,
    Path(session_id): Path<Uuid>,
) -> impl IntoResponse {
    ws.on_upgrade(move |socket| handle_socket(socket, state, session_id))
}

/// Handle WebSocket connection lifecycle.
async fn handle_socket(socket: WebSocket, state: AppState, session_id: Uuid) {
    let (mut sender, mut receiver) = socket.split();

    // Get or create broadcast channel for this session
    let rx = {
        let mut sessions = state.live_sessions.lock().await;
        let tx = sessions.entry(session_id).or_insert_with(|| {
            let (tx, _) = tokio::sync::broadcast::channel(1024);
            tx
        });
        tx.subscribe()
    };

    // Forward broadcast messages to WebSocket client
    let mut send_task = tokio::spawn(async move {
        let mut rx = rx;
        while let Ok(sample) = rx.recv().await {
            let json = serde_json::to_string(&sample).unwrap_or_default();
            if sender
                .send(Message::Text(json.into()))
                .await
                .is_err()
            {
                break; // client disconnected
            }
        }
    });

    // Handle incoming messages (close, ping)
    let recv_task = tokio::spawn(async move {
        while let Some(Ok(msg)) = receiver.next().await {
            match msg {
                Message::Close(_) => break,
                Message::Ping(_) => { /* axum handles pong automatically */ }
                _ => {}
            }
        }
    });

    // Wait for either task to finish
    let send_abort = send_task.abort_handle();
    let recv_abort = recv_task.abort_handle();
    tokio::select! {
        _ = send_task => { recv_abort.abort(); },
        _ = recv_task => { send_abort.abort(); },
    };

    tracing::info!(session_id = %session_id, "WebSocket client disconnected");

    // Clean up broadcast senders with no active receivers (WR-08)
    // Prevents unbounded HashMap growth as sessions come and go
    {
        let mut sessions = state.live_sessions.lock().await;
        sessions.retain(|_, tx| tx.receiver_count() > 0);
    }
}

/// Batch push endpoint: desktop sends multiple MetricSamples every ~5 seconds.
/// POST /api/v1/sessions/:session_id/live/batch (API token auth)
/// Body: {"samples": [MetricSample, ...]}
#[derive(Debug, Deserialize)]
pub struct LiveBatchBody {
    pub samples: Vec<MetricSample>,
}

pub async fn push_live_batch(
    State(state): State<AppState>,
    Path(session_id): Path<Uuid>,
    Extension(auth_user): Extension<AuthUser>,
    Json(body): Json<LiveBatchBody>,
) -> Result<impl IntoResponse, AppError> {
    // Scope check — reject read-only API tokens (WR-07)
    if auth_user.role != "write" && auth_user.role != "admin" {
        return Err(AppError::Forbidden);
    }

    // Get or create broadcast channel
    let tx = {
        let mut sessions = state.live_sessions.lock().await;
        // Clean up dead entries with no active receivers (WR-08)
        sessions.retain(|_, tx| tx.receiver_count() > 0);
        sessions
            .entry(session_id)
            .or_insert_with(|| {
                let (tx, _) = tokio::sync::broadcast::channel(1024);
                tx
            })
            .clone()
    };

    let mut sent = 0u64;
    let batch_size = body.samples.len();
    for sample in body.samples {
        if tx.send(sample).is_ok() {
            sent += 1;
        }
    }

    tracing::debug!(
        session_id = %session_id,
        batch_size = batch_size,
        sent = sent,
        "Live batch pushed"
    );

    Ok((StatusCode::OK, Json(serde_json::json!({ "sent": sent }))))
}
