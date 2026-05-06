use axum::extract::State;
use axum::http::StatusCode;
use axum::{Extension, Json};
use axum_extra::extract::cookie::{Cookie, CookieJar, SameSite};
use serde::{Deserialize, Serialize};
use serde_json::json;
use uuid::Uuid;

use db::token_queries;
use db::user_queries;
use crate::error::AppError;
use crate::state::AppState;
use crate::utils::jwt::{self, AuthUser};
use crate::utils::password;

// ── Request types ──

#[derive(Debug, Deserialize)]
pub struct LoginRequest {
    pub email: String,
    pub password: String,
}

#[derive(Debug, Deserialize)]
pub struct RegisterRequest {
    pub email: String,
    pub password: String,
    #[serde(default)]
    pub display_name: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct RefreshRequest {
    #[serde(rename = "refreshToken")]
    pub refresh_token: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AuthResponse {
    pub user: UserResponse,
    #[serde(rename = "refreshToken")]
    pub refresh_token: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct UserResponse {
    pub id: Uuid,
    pub email: String,
    pub display_name: Option<String>,
    pub role: String,
    pub is_active: bool,
}

impl From<&models::user::User> for UserResponse {
    fn from(u: &models::user::User) -> Self {
        Self {
            id: u.id,
            email: u.email.clone(),
            display_name: u.display_name.clone(),
            role: u.role.clone(),
            is_active: u.is_active,
        }
    }
}

// ── Helper: build Set-Cookie for access token ──

fn access_token_cookie(token: &str, max_age_secs: i64) -> Cookie<'static> {
    Cookie::build(("access_token", token.to_string()))
        .http_only(true)
        .secure(true)
        .same_site(SameSite::Strict)
        .path("/")
        .max_age(time::Duration::seconds(max_age_secs))
        .build()
}

fn clear_access_token_cookie() -> Cookie<'static> {
    Cookie::build(("access_token", ""))
        .http_only(true)
        .secure(true)
        .same_site(SameSite::Strict)
        .path("/")
        .max_age(time::Duration::seconds(0))
        .build()
}

fn map_db_err(e: Box<dyn std::error::Error + Send + Sync>) -> AppError {
    AppError::Internal(format!("Database error: {}", e))
}

// ── Handlers ──

/// POST /auth/login
pub async fn login(
    State(state): State<AppState>,
    jar: CookieJar,
    Json(body): Json<LoginRequest>,
) -> Result<(CookieJar, Json<AuthResponse>), AppError> {
    let user = user_queries::get_user_by_email(&state.pool, &body.email)
        .await
        .map_err(map_db_err)?
        .ok_or(AppError::Unauthorized)?;

    // SSO users have no password — reject password login
    let password_hash = user.password_hash.as_deref().ok_or(AppError::Unauthorized)?;
    let valid = password::verify_password(&body.password, password_hash)?;
    if !valid {
        tracing::info!(
            event_type = "login",
            user_id = %user.id,
            success = false,
            "Login failed: invalid password"
        );
        return Err(AppError::Unauthorized);
    }

    let secret = state.config.jwt_secret.as_bytes();
    let access_token = jwt::create_access_token(user.id, &user.email, &user.role, secret)?;
    let refresh_token_str = jwt::create_refresh_token(user.id, &user.email, secret)?;

    let now = chrono::Utc::now().naive_utc();
    let expires_at = now + chrono::Duration::days(7);
    let rt_hash = token_queries::hash_token(&refresh_token_str);
    token_queries::create_refresh_token(&state.pool, user.id, &rt_hash, expires_at)
        .await
        .map_err(map_db_err)?;

    tracing::info!(
        event_type = "login",
        user_id = %user.id,
        success = true,
        "Login successful"
    );

    let cookie = access_token_cookie(&access_token, 3600);
    let body = AuthResponse {
        user: UserResponse::from(&user),
        refresh_token: refresh_token_str,
    };

    Ok((jar.add(cookie), Json(body)))
}

/// POST /auth/register
pub async fn register(
    State(state): State<AppState>,
    Json(body): Json<RegisterRequest>,
) -> Result<(StatusCode, Json<serde_json::Value>), AppError> {
    password::validate_password_policy(&body.password)?;

    let user_count = user_queries::count_users(&state.pool)
        .await
        .map_err(map_db_err)?;

    if user_count > 0 {
        return Err(AppError::Forbidden);
    }

    let password_hash = password::hash_password(&body.password)?;

    let user = user_queries::create_user(
        &state.pool,
        &body.email,
        &password_hash,
        body.display_name.as_deref(),
        "admin",
    )
    .await
    .map_err(map_db_err)?;

    tracing::info!(
        event_type = "register",
        user_id = %user.id,
        role = "admin",
        "First admin user created"
    );

    let response = json!({
        "user": UserResponse::from(&user),
        "message": "Admin account created. You can now log in."
    });

    Ok((StatusCode::CREATED, Json(response)))
}

/// POST /auth/refresh
pub async fn refresh(
    State(state): State<AppState>,
    jar: CookieJar,
    Json(body): Json<RefreshRequest>,
) -> Result<(CookieJar, Json<AuthResponse>), AppError> {
    let secret = state.config.jwt_secret.as_bytes();

    let claims = jwt::validate_token(&body.refresh_token, secret)?;
    if claims.token_type != "refresh" {
        tracing::warn!(
            event_type = "refresh",
            user_id = %claims.sub,
            "Token type mismatch: expected refresh, got {}",
            claims.token_type
        );
        return Err(AppError::Unauthorized);
    }

    let user_id: Uuid = claims.sub.parse().map_err(|_| AppError::Unauthorized)?;

    let rt_hash = token_queries::hash_token(&body.refresh_token);
    let stored = token_queries::get_refresh_token_by_hash(&state.pool, &rt_hash)
        .await
        .map_err(map_db_err)?
        .ok_or(AppError::Unauthorized)?;

    if stored.is_revoked {
        return Err(AppError::Unauthorized);
    }

    token_queries::revoke_refresh_token(&state.pool, stored.id)
        .await
        .map_err(map_db_err)?;

    let user = user_queries::get_user_by_id(&state.pool, user_id)
        .await
        .map_err(map_db_err)?
        .ok_or(AppError::Unauthorized)?;

    let access_token = jwt::create_access_token(user.id, &user.email, &user.role, secret)?;
    let refresh_token_str = jwt::create_refresh_token(user.id, &user.email, secret)?;

    let now = chrono::Utc::now().naive_utc();
    let expires_at = now + chrono::Duration::days(7);
    let new_rt_hash = token_queries::hash_token(&refresh_token_str);
    token_queries::create_refresh_token(&state.pool, user.id, &new_rt_hash, expires_at)
        .await
        .map_err(map_db_err)?;

    tracing::info!(
        event_type = "token_refresh",
        user_id = %user.id,
        "Tokens refreshed"
    );

    let cookie = access_token_cookie(&access_token, 3600);
    let body = AuthResponse {
        user: UserResponse::from(&user),
        refresh_token: refresh_token_str,
    };

    Ok((jar.add(cookie), Json(body)))
}

/// POST /auth/logout
pub async fn logout(
    State(state): State<AppState>,
    jar: CookieJar,
    Json(body): Json<RefreshRequest>,
) -> Result<(CookieJar, Json<serde_json::Value>), AppError> {
    let rt_hash = token_queries::hash_token(&body.refresh_token);
    if let Ok(Some(stored)) = token_queries::get_refresh_token_by_hash(&state.pool, &rt_hash).await {
        let _ = token_queries::revoke_refresh_token(&state.pool, stored.id).await;
    }

    tracing::info!(event_type = "logout", "User logged out");

    let response = json!({"message": "Logged out"});
    Ok((jar.add(clear_access_token_cookie()), Json(response)))
}

/// GET /auth/me — requires auth middleware
pub async fn me(
    Extension(auth_user): Extension<AuthUser>,
    State(state): State<AppState>,
) -> Result<Json<UserResponse>, AppError> {
    let user = user_queries::get_user_by_id(&state.pool, auth_user.user_id)
        .await
        .map_err(map_db_err)?
        .ok_or(AppError::Unauthorized)?;

    Ok(Json(UserResponse::from(&user)))
}
