use chrono::NaiveDateTime;
use diesel::prelude::*;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, Queryable, Selectable)]
#[diesel(table_name = crate::schema::alert_rules)]
#[diesel(check_for_backend(diesel::pg::Pg))]
#[serde(rename_all = "camelCase")]
pub struct AlertRule {
    pub id: Uuid,
    pub user_id: Uuid,
    pub name: String,
    pub metric_name: String,
    pub condition: String,
    pub threshold: f64,
    #[serde(default = "default_duration")]
    pub duration_seconds: i32,
    #[serde(default)]
    pub channels: serde_json::Value,
    #[serde(default = "default_true")]
    pub is_active: bool,
    #[serde(skip_serializing)]
    pub created_at: NaiveDateTime,
    #[serde(skip_serializing)]
    pub updated_at: NaiveDateTime,
}

#[derive(Debug, Clone, Serialize, Deserialize, Queryable, Selectable)]
#[diesel(table_name = crate::schema::alert_events)]
#[diesel(check_for_backend(diesel::pg::Pg))]
#[serde(rename_all = "camelCase")]
pub struct AlertEvent {
    pub id: Uuid,
    pub rule_id: Uuid,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub session_id: Option<Uuid>,
    pub metric_value: f64,
    pub threshold: f64,
    #[serde(skip_serializing)]
    pub fired_at: NaiveDateTime,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub acknowledged_at: Option<NaiveDateTime>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub acknowledged_by: Option<Uuid>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Queryable, Selectable)]
#[diesel(table_name = crate::schema::lenses)]
#[diesel(check_for_backend(diesel::pg::Pg))]
#[serde(rename_all = "camelCase")]
pub struct Lens {
    pub id: Uuid,
    pub user_id: Uuid,
    pub name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    #[serde(default)]
    pub filters: serde_json::Value,
    #[serde(default)]
    pub chart_config: serde_json::Value,
    #[serde(default)]
    pub is_public: bool,
    #[serde(skip_serializing)]
    pub created_at: NaiveDateTime,
    #[serde(skip_serializing)]
    pub updated_at: NaiveDateTime,
}

#[derive(Debug, Clone, Serialize, Deserialize, Queryable, Selectable)]
#[diesel(table_name = crate::schema::webhook_configs)]
#[diesel(check_for_backend(diesel::pg::Pg))]
#[serde(rename_all = "camelCase")]
pub struct WebhookConfig {
    pub id: Uuid,
    pub user_id: Uuid,
    pub name: String,
    pub url: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub secret: Option<String>,
    #[serde(default = "default_webhook_events")]
    pub events: Vec<String>,
    #[serde(default = "default_true")]
    pub is_active: bool,
    #[serde(skip_serializing)]
    pub created_at: NaiveDateTime,
    #[serde(skip_serializing)]
    pub updated_at: NaiveDateTime,
}

fn default_duration() -> i32 {
    30
}

fn default_true() -> bool {
    true
}

fn default_webhook_events() -> Vec<String> {
    vec!["session_end".to_string(), "alert_fired".to_string()]
}
