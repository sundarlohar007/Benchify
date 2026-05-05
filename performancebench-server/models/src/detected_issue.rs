use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// DetectedIssue represents an auto-detected performance issue during a session.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DetectedIssue {
    pub id: Uuid,
    pub session_id: Uuid,
    pub rule_id: String,
    pub category: String,
    pub severity: String,
    pub message: String,
    #[serde(default)]
    pub details: serde_json::Value,
    pub timestamp: i64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub created_at: Option<String>,
}
