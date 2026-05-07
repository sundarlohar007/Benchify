use axum::extract::State;
use axum::http::{HeaderMap, header};
use axum::middleware::Next;
use axum::response::Response;

use crate::error::AppError;
use crate::state::AppState;
use crate::utils::jwt::AuthUser;
use db::token_queries;

/// API token middleware for machine-to-machine endpoints.
/// Reads Authorization: Bearer <api_token>, validates against api_tokens table,
/// checks scope, and inserts AuthUser into request extensions.
pub async fn api_token_middleware(
    State(state): State<AppState>,
    headers: HeaderMap,
    mut request: axum::extract::Request,
    next: Next,
) -> Result<Response, AppError> {
    // Extract Bearer token
    let token = headers
        .get(header::AUTHORIZATION)
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "))
        .ok_or(AppError::Unauthorized)?;

    // API tokens are expected to have "pb_" prefix
    if !token.starts_with("pb_") {
        return Err(AppError::Unauthorized);
    }

    // Hash the token for lookup
    let token_hash = token_queries::hash_token(token);

    // Look up in database
    let api_token = token_queries::get_token_by_hash(&state.pool, &token_hash)
        .await
        .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?
        .ok_or(AppError::Unauthorized)?;

    if api_token.is_revoked {
        return Err(AppError::Unauthorized);
    }

    // Update last_used_at (fire and forget — don't fail the request if this errors)
    let _ = token_queries::update_token_last_used(&state.pool, api_token.id).await;

    // Insert AuthUser (role reflects token scopes)
    let role = if api_token.scopes.contains(&"admin".to_string()) {
        "admin"
    } else if api_token.scopes.contains(&"write".to_string()) {
        "write"
    } else {
        "read"
    };

    let auth_user = AuthUser {
        user_id: api_token.user_id,
        email: format!("token:{}", api_token.name),
        role: role.to_string(),
    };

    request.extensions_mut().insert(auth_user);

    Ok(next.run(request).await)
}
