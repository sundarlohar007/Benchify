use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::{Extension, Json, Router};
use axum::routing::{delete, get, post};
use serde::Deserialize;
use sha2::{Digest, Sha256};
use uuid::Uuid;

use db::token_queries;
use models::token::CreateApiToken;
use crate::error::AppError;
use crate::state::AppState;
use crate::utils::jwt::AuthUser;

#[derive(Debug, Deserialize)]
pub struct CreateTokenBody {
    pub name: String,
    #[serde(default = "default_scopes")]
    pub scopes: Vec<String>,
    pub expires_at: Option<String>,
}

fn default_scopes() -> Vec<String> {
    vec!["read".to_string()]
}

/// GET /api/v1/tokens — list user's API tokens (masked — never show full token).
pub async fn list_tokens(
    State(state): State<AppState>,
    Extension(auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    let tokens = token_queries::list_tokens_for_user(&state.pool, auth_user.user_id)
        .await
        .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?;

    let masked: Vec<serde_json::Value> = tokens
        .into_iter()
        .map(|t| {
            serde_json::json!({
                "id": t.id,
                "name": t.name,
                "token_prefix": t.token_prefix,
                "scopes": t.scopes,
                "last_used_at": t.last_used_at,
                "expires_at": t.expires_at,
                "is_revoked": t.is_revoked,
                "created_at": t.created_at,
            })
        })
        .collect();

    Ok((StatusCode::OK, Json(serde_json::json!({ "data": masked }))))
}

/// POST /api/v1/tokens — create a new API token.
/// Returns the full token ONCE — user must copy immediately.
/// Token format: pb_<64_hex_chars> (pb_ prefix + 32 random bytes as hex).
/// SHA-256 hash stored in DB.
pub async fn create_token(
    State(state): State<AppState>,
    Json(body): Json<CreateTokenBody>,
    Extension(auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    // Generate random API token: pb_ + 32 random bytes as hex
    let random_bytes: Vec<u8> = (0..32).map(|_| rand::random::<u8>()).collect();
    let full_token = format!("pb_{}", bytes_to_hex(&random_bytes));

    // Hash the token for storage
    let token_hash = {
        let mut hasher = Sha256::new();
        hasher.update(full_token.as_bytes());
        format!("{:x}", hasher.finalize())
    };

    // Token prefix for display: first 8 chars after pb_
    let token_prefix = format!("pb_{}...", &full_token[3..11]);

    let new_token = CreateApiToken {
        user_id: auth_user.user_id,
        name: body.name,
        token_prefix,
        token_hash,
        scopes: body.scopes,
        expires_at: body.expires_at,
    };

    let _created = token_queries::create_api_token(&state.pool, &new_token)
        .await
        .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?;

    Ok((
        StatusCode::CREATED,
        Json(serde_json::json!({
            "token": full_token,
            "message": "Copy this token now — it will not be shown again.",
        })),
    ))
}

/// DELETE /api/v1/tokens/:id — revoke an API token.
pub async fn revoke_token(
    State(state): State<AppState>,
    Path(token_id): Path<Uuid>,
    Extension(_auth_user): Extension<AuthUser>,
) -> Result<impl IntoResponse, AppError> {
    token_queries::revoke_token(&state.pool, token_id)
        .await
        .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?;

    Ok((StatusCode::OK, Json(serde_json::json!({"status": "revoked"}))))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/", get(list_tokens).post(create_token))
        .route("/{id}", delete(revoke_token))
}

/// Convert a byte slice to a lowercase hex string.
fn bytes_to_hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{:02x}", b)).collect()
}
