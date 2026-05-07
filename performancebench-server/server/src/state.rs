use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::{Mutex, broadcast};
use uuid::Uuid;

use db::connection::DbPool;
use models::metric_sample::MetricSample;

use crate::config::AppConfig;

#[derive(Clone)]
pub struct AppState {
    pub pool: DbPool,
    pub config: AppConfig,
    /// Per-session broadcast channels for WebSocket live overlay.
    /// Maps session_id -> broadcast sender (ring buffer of 1024 samples).
    /// Uses tokio::sync::Mutex to avoid blocking tokio worker threads.
    pub live_sessions: Arc<Mutex<HashMap<Uuid, broadcast::Sender<MetricSample>>>>,
}

impl AppState {
    pub fn new(pool: DbPool, config: AppConfig) -> Self {
        Self {
            pool,
            config,
            live_sessions: Arc::new(Mutex::new(HashMap::new())),
        }
    }
}
