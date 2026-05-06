use hmac::{Hmac, Mac};
use reqwest::Client;
use serde::Serialize;
use sha2::Sha256;
use uuid::Uuid;

use crate::config::AppConfig;

type HmacSha256 = Hmac<Sha256>;

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct NotificationPayload {
    pub event_type: String,
    pub title: String,
    pub message: String,
    pub session_id: Option<Uuid>,
    pub alert_rule_id: Option<Uuid>,
    pub metric_value: Option<f64>,
    pub threshold: Option<f64>,
    pub timestamp: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Clone, Serialize, serde::Deserialize)]
#[serde(tag = "type", rename_all = "lowercase")]
pub enum NotificationChannel {
    Email { to: String },
    Slack { webhook_url: String },
    Webhook { url: String, secret: Option<String> },
}

/// Dispatch notification to all configured channels.
/// Called via tokio::spawn — fire and forget, log failures.
pub async fn dispatch_notification(
    config: &AppConfig,
    channels: &[NotificationChannel],
    payload: &NotificationPayload,
) {
    for channel in channels {
        match channel {
            NotificationChannel::Email { to } => {
                if let Err(e) = send_email(config, to, payload).await {
                    tracing::error!(?e, recipient = %to, event = %payload.event_type,
                        "Failed to send email notification");
                }
            }
            NotificationChannel::Slack { webhook_url } => {
                if let Err(e) = send_slack(webhook_url, payload).await {
                    tracing::error!(?e, webhook_url = %webhook_url, event = %payload.event_type,
                        "Failed to send Slack notification");
                }
            }
            NotificationChannel::Webhook { url, secret } => {
                if let Err(e) = send_webhook(url, secret, payload).await {
                    tracing::error!(?e, url = %url, event = %payload.event_type,
                        "Failed to send webhook notification");
                }
            }
        }
    }
    tracing::info!(
        event = %payload.event_type,
        channel_count = channels.len(),
        "Notification dispatched"
    );
}

/// Send email via SMTP using lettre (D-13: Email channel).
async fn send_email(
    config: &AppConfig,
    to: &str,
    payload: &NotificationPayload,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let smtp_host = config
        .smtp_host
        .as_ref()
        .ok_or("SMTP host not configured")?;

    let from = config
        .smtp_from_email
        .as_deref()
        .unwrap_or("alerts@benchify.local");

    let email = lettre::Message::builder()
        .from(from.parse()?)
        .to(to.parse()?)
        .subject(format!(
            "[Benchify] {} — {}",
            payload.event_type, payload.title
        ))
        .body(format!(
            "{}\n\nSession: {}\nMetric: {:?}\nThreshold: {:?}\nTime: {}",
            payload.message,
            payload
                .session_id
                .map_or("N/A".to_string(), |id| id.to_string()),
            payload.metric_value,
            payload.threshold,
            payload.timestamp.to_rfc3339()
        ))?;

    let mailer = lettre::AsyncSmtpTransport::<lettre::Tokio1Executor>::relay(smtp_host)?
        .credentials(
            config
                .smtp_username
                .as_deref()
                .unwrap_or("")
                .to_string()
                .into(),
            config
                .smtp_password
                .as_deref()
                .unwrap_or("")
                .to_string()
                .into(),
        )
        .port(config.smtp_port.unwrap_or(587))
        .build();

    mailer.send(email).await?;
    Ok(())
}

/// Send Slack message via incoming webhook.
async fn send_slack(
    webhook_url: &str,
    payload: &NotificationPayload,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let client = Client::new();
    let color = match payload.event_type.as_str() {
        "alert_fired" => "#F44747",
        "session_end" => "#4EC9B0",
        _ => "#007ACC",
    };
    let slack_payload = serde_json::json!({
        "attachments": [{
            "color": color,
            "title": format!("[Benchify] {} — {}", payload.event_type, payload.title),
            "text": payload.message,
            "fields": [
                {"title": "Session", "value": payload.session_id.map_or("N/A".to_string(), |id| id.to_string()), "short": true},
                {"title": "Time", "value": payload.timestamp.to_rfc3339(), "short": true},
            ],
            "footer": "Benchify Team Server",
        }]
    });
    client
        .post(webhook_url)
        .json(&slack_payload)
        .send()
        .await?;
    Ok(())
}

/// Send generic webhook with HMAC-SHA256 signature (D-16: Webhook callbacks).
async fn send_webhook(
    url: &str,
    secret: &Option<String>,
    payload: &NotificationPayload,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let client = Client::new();
    let body = serde_json::to_string(payload)?;
    let mut request = client
        .post(url)
        .header("Content-Type", "application/json")
        .header("X-Benchify-Event", &payload.event_type);

    // Add HMAC-SHA256 signature if secret is configured
    if let Some(secret) = secret {
        let mut mac =
            HmacSha256::new_from_slice(secret.as_bytes()).map_err(|e| e.to_string())?;
        mac.update(body.as_bytes());
        let signature = hex::encode(mac.finalize().into_bytes());
        request = request.header(
            "X-Benchify-Signature",
            format!("sha256={}", signature),
        );
    }

    request.body(body).send().await?;
    Ok(())
}
