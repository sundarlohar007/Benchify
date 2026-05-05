use axum::extract::State;
use axum::http::{header, HeaderMap};
use axum::middleware::Next;
use axum::response::Response;
use axum_extra::extract::cookie::CookieJar;

use crate::error::AppError;
use crate::state::AppState;
use crate::utils::jwt::{self, AuthUser};

/// Auth middleware that extracts JWT from httpOnly cookie (priority) or Bearer header.
/// Validates the token and inserts AuthUser into request extensions.
pub async fn auth_middleware(
    State(state): State<AppState>,
    jar: CookieJar,
    headers: HeaderMap,
    mut request: axum::extract::Request,
    next: Next,
) -> Result<Response, AppError> {
    let secret = state.config.jwt_secret.as_bytes();

    // 1. Try cookie "access_token" first (web dashboard)
    let token = jar
        .get("access_token")
        .map(|c| c.value().to_string())
        // 2. Fall back to Authorization: Bearer <token> (API/CI/CD)
        .or_else(|| {
            headers
                .get(header::AUTHORIZATION)
                .and_then(|v| v.to_str().ok())
                .and_then(|v| v.strip_prefix("Bearer "))
                .map(|s| s.to_string())
        })
        .ok_or(AppError::Unauthorized)?;

    // 3. Validate token
    let claims = jwt::validate_token(&token, secret)?;

    // Only accept access tokens (not refresh or API tokens)
    if claims.token_type != "access" {
        return Err(AppError::Unauthorized);
    }

    // 4. Parse user_id
    let user_id: uuid::Uuid = claims.sub.parse().map_err(|_| AppError::Unauthorized)?;

    // 5. Insert AuthUser into request extensions
    let auth_user = AuthUser {
        user_id,
        email: claims.email,
        role: claims.role,
    };

    request.extensions_mut().insert(auth_user);

    Ok(next.run(request).await)
}
