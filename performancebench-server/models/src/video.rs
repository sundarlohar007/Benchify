use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// VideoMetadata represents a screen recording associated with a session.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct VideoMetadata {
    pub id: Uuid,
    pub session_id: Uuid,
    pub file_path: String,
    #[serde(default)]
    pub chunk_index: i32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub codec: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub width: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub height: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fps: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub bitrate_kbps: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub duration_seconds: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub file_size_bytes: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub created_at: Option<String>,
}
