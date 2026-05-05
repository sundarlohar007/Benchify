use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// Marker represents a named point or range in a profiling session.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Marker {
    pub id: Uuid,
    pub session_id: Uuid,
    pub name: String,
    #[serde(default = "default_marker_type")]
    pub marker_type: String,
    pub started_at: i64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ended_at: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub created_at: Option<String>,
}

fn default_marker_type() -> String {
    "range".to_string()
}
