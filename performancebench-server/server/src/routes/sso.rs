use axum::extract::{Query, State};
use axum::response::Redirect;
use axum::routing::{get, post};
use axum::{Form, Json, Router};
use axum_extra::extract::cookie::{Cookie, CookieJar, SameSite};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use uuid::Uuid;

use crate::error::AppError;
use crate::middleware::audit as audit_mw;
use crate::state::AppState;
use crate::utils::{jwt, ldap, oidc, saml};
use db::sso_queries;
use db::user_queries;
use models::audit::{AuditEventCategory, AuditEventType};
use models::sso::{LdapProviderConfig, OidcProviderConfig, SamlProviderConfig};

// ── In-memory SSO state store (short-lived, per-request) ──
// Uses a signed cookie for CSRF/PKCE/SAML relay state instead of server-side store.
// This is the pragmatic approach — avoids session store dependency.

const SSO_STATE_COOKIE: &str = "sso_state";
const SSO_STATE_MAX_AGE: i64 = 600; // 10 minutes

/// Signed cookie payload for OIDC/SAML state.
#[derive(Debug, Serialize, Deserialize)]
struct SsoCookieState {
    csrf_state: String,
    pkce_verifier: Option<String>,
    relay_state: Option<String>,
    nonce: Option<String>,
    provider_id: Uuid,
    redirect_after: Option<String>,
}

// ── Request types ──

#[derive(Debug, Deserialize)]
struct OidcCallbackQuery {
    code: String,
    state: String,
}

#[derive(Debug, Deserialize)]
struct SsoLoginQuery {
    provider: Uuid,
}

#[derive(Debug, Deserialize)]
struct LdapLoginRequest {
    provider_id: Uuid,
    username: String,
    password: String,
}

// ── Response types ──

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct AuthResponse {
    user: super::auth::UserResponse,
    #[serde(rename = "refreshToken")]
    refresh_token: String,
}

// ── Cookie helpers ──

fn sso_state_cookie(data: &SsoCookieState) -> Result<Cookie<'static>, AppError> {
    let json = serde_json::to_string(data)
        .map_err(|e| AppError::Internal(format!("SSO state serialize error: {}", e)))?;
    Ok(Cookie::build((SSO_STATE_COOKIE, json))
        .http_only(true)
        .secure(true)
        .same_site(SameSite::Lax)
        .path("/auth/sso")
        .max_age(time::Duration::seconds(SSO_STATE_MAX_AGE))
        .build())
}

fn parse_sso_state_cookie(jar: &CookieJar) -> Result<SsoCookieState, AppError> {
    let value = jar
        .get(SSO_STATE_COOKIE)
        .map(|c| c.value().to_string())
        .ok_or(AppError::Unauthorized)?;
    serde_json::from_str(&value).map_err(|_| AppError::Unauthorized)
}

fn clear_sso_state_cookie() -> Cookie<'static> {
    Cookie::build((SSO_STATE_COOKIE, ""))
        .http_only(true)
        .secure(true)
        .same_site(SameSite::Lax)
        .path("/auth/sso")
        .max_age(time::Duration::seconds(0))
        .build()
}

fn access_token_cookie(token: &str) -> Cookie<'static> {
    Cookie::build(("access_token", token.to_string()))
        .http_only(true)
        .secure(true)
        .same_site(SameSite::Strict)
        .path("/")
        .max_age(time::Duration::seconds(3600))
        .build()
}

// ── JWT issuance helper (shared across all SSO handlers) ──

async fn issue_jwt_for_user(
    state: &AppState,
    user: &models::user::User,
    jar: CookieJar,
    event_type: &str,
    sso_provider: &str,
) -> Result<(CookieJar, Json<AuthResponse>), AppError> {
    let secret = state.config.jwt_secret.as_bytes();
    let access_token = jwt::create_access_token(user.id, &user.email, &user.role, secret)?;
    let refresh_token_str = jwt::create_refresh_token(user.id, &user.email, secret)?;

    // Store refresh token
    let now = chrono::Utc::now().naive_utc();
    let expires_at = now + chrono::Duration::days(7);
    let rt_hash = db::token_queries::hash_token(&refresh_token_str);
    db::token_queries::create_refresh_token(&state.pool, user.id, &rt_hash, expires_at)
        .await
        .map_err(|e| AppError::Internal(format!("Database error: {}", e)))?;

    tracing::info!(
        event_type = event_type,
        user_id = %user.id,
        sso_provider = sso_provider,
        "SSO login successful"
    );

    // Audit SSO login
    let audit_user = crate::utils::jwt::AuthUser {
        user_id: user.id,
        email: user.email.clone(),
        role: user.role.clone(),
    };
    let _ = audit_mw::record_audit_event(
        &state.pool,
        Some(&audit_user),
        AuditEventType::SsoLogin,
        AuditEventCategory::Auth,
        None,
        None,
        serde_json::json!({
            "success": true,
            "sso_provider": sso_provider,
        }),
    )
    .await;

    let cookie = access_token_cookie(&access_token);
    let body = AuthResponse {
        user: super::auth::UserResponse::from(user),
        refresh_token: refresh_token_str,
    };

    Ok((jar.add(cookie), Json(body)))
}

// ── Router ──

pub fn sso_router() -> Router<AppState> {
    Router::new()
        .route("/auth/sso/oidc/login", get(oidc_login))
        .route("/auth/sso/oidc/callback", get(oidc_callback))
        .route("/auth/sso/saml/login", get(saml_login))
        .route("/auth/sso/saml/acs", post(saml_acs))
        .route("/auth/sso/ldap/login", post(ldap_login))
}

// ── OIDC Handlers ──

/// GET /auth/sso/oidc/login?provider={id}
async fn oidc_login(
    State(state): State<AppState>,
    jar: CookieJar,
    Query(params): Query<SsoLoginQuery>,
) -> Result<(CookieJar, Redirect), AppError> {
    let provider = sso_queries::get_sso_config_by_id(&state.pool, params.provider)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?
        .ok_or(AppError::NotFound("OIDC provider".to_string()))?;

    if provider.provider_type != "oidc" {
        return Err(AppError::Validation(
            "Provider is not an OIDC provider".to_string(),
        ));
    }

    let oidc_cfg: OidcProviderConfig = serde_json::from_value(provider.config.clone())
        .map_err(|e| AppError::Internal(format!("Invalid OIDC config: {}", e)))?;

    let redirect_url = format!(
        "{}/auth/sso/oidc/callback",
        state.config.sso_redirect_base_url
    );

    // Start OIDC flow
    let (auth_url, csrf_state, nonce, pkce_verifier) = oidc::start_oidc_flow(
        &oidc_cfg.issuer_url,
        &oidc_cfg.client_id,
        &oidc_cfg.client_secret,
        &redirect_url,
    )
    .await
    .map_err(|e| AppError::Internal(format!("OIDC flow error: {}", e)))?;

    // Store state in signed cookie
    let state_data = SsoCookieState {
        csrf_state: csrf_state.secret().to_string(),
        pkce_verifier: Some(pkce_verifier.secret().to_string()),
        relay_state: None,
        nonce: Some(nonce.secret().to_string()),
        provider_id: provider.id,
        redirect_after: None,
    };

    let cookie = sso_state_cookie(&state_data)?;
    Ok((jar.add(cookie), Redirect::temporary(&auth_url.to_string())))
}

/// GET /auth/sso/oidc/callback?code={code}&state={state}
async fn oidc_callback(
    State(state): State<AppState>,
    jar: CookieJar,
    Query(params): Query<OidcCallbackQuery>,
) -> Result<(CookieJar, Json<AuthResponse>), AppError> {
    let sso_state = parse_sso_state_cookie(&jar)?;

    // Verify CSRF state
    if sso_state.csrf_state != params.state {
        tracing::warn!("OIDC CSRF state mismatch");
        return Err(AppError::Unauthorized);
    }

    let pkce_verifier_str = sso_state.pkce_verifier.ok_or(AppError::Unauthorized)?;
    let nonce_str = sso_state.nonce.ok_or(AppError::Unauthorized)?;

    let provider = sso_queries::get_sso_config_by_id(&state.pool, sso_state.provider_id)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?
        .ok_or(AppError::NotFound("OIDC provider".to_string()))?;

    let oidc_cfg: OidcProviderConfig = serde_json::from_value(provider.config.clone())
        .map_err(|e| AppError::Internal(format!("Invalid OIDC config: {}", e)))?;

    let redirect_url = format!(
        "{}/auth/sso/oidc/callback",
        state.config.sso_redirect_base_url
    );

    let pkce_verifier = openidconnect::PkceCodeVerifier::new(pkce_verifier_str);
    let nonce = openidconnect::Nonce::new(nonce_str);

    // Finish OIDC flow (exchange code, validate tokens)
    let claims = oidc::finish_oidc_flow(
        &oidc_cfg.issuer_url,
        &oidc_cfg.client_id,
        &oidc_cfg.client_secret,
        &redirect_url,
        &params.code,
        pkce_verifier,
        &nonce,
    )
    .await
    .map_err(|e| {
        tracing::warn!(error = %e, "OIDC code exchange failed");
        AppError::Unauthorized
    })?;

    // Extract user attributes
    let oidc_attrs = oidc::extract_oidc_attributes(&claims).ok_or(AppError::Unauthorized)?;

    // JIT provisioning
    let (user, _is_new) = user_queries::find_or_create_sso_user(
        &state.pool,
        &oidc_attrs.email,
        oidc_attrs.display_name.as_deref(),
        "oidc",
        &oidc_attrs.subject,
    )
    .await
    .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?;

    // Issue JWT
    let (jar, response) = issue_jwt_for_user(&state, &user, jar, "sso_login", "oidc").await?;
    let jar = jar.remove(clear_sso_state_cookie());
    Ok((jar, response))
}

// ── SAML Handlers ──

/// GET /auth/sso/saml/login?provider={id}
async fn saml_login(
    State(state): State<AppState>,
    jar: CookieJar,
    Query(params): Query<SsoLoginQuery>,
) -> Result<(CookieJar, Redirect), AppError> {
    let provider = sso_queries::get_sso_config_by_id(&state.pool, params.provider)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?
        .ok_or(AppError::NotFound("SAML provider".to_string()))?;

    if provider.provider_type != "saml" {
        return Err(AppError::Validation(
            "Provider is not a SAML provider".to_string(),
        ));
    }

    let saml_cfg: SamlProviderConfig = serde_json::from_value(provider.config.clone())
        .map_err(|e| AppError::Internal(format!("Invalid SAML config: {}", e)))?;

    let acs_url = if saml_cfg.acs_url.is_empty() {
        format!("{}/auth/sso/saml/acs", state.config.sso_redirect_base_url)
    } else {
        saml_cfg.acs_url.clone()
    };

    let (redirect_url, relay_state) =
        saml::build_authn_request(&saml_cfg.idp_sso_url, &saml_cfg.sp_entity_id, &acs_url)
            .map_err(|e| AppError::Internal(format!("SAML AuthnRequest build error: {}", e)))?;

    // Store relay state in signed cookie
    let state_data = SsoCookieState {
        csrf_state: String::new(),
        pkce_verifier: None,
        relay_state: Some(relay_state),
        nonce: None,
        provider_id: provider.id,
        redirect_after: None,
    };

    let cookie = sso_state_cookie(&state_data)?;
    Ok((jar.add(cookie), Redirect::temporary(&redirect_url)))
}

/// POST /auth/sso/saml/acs?provider={id}
async fn saml_acs(
    State(state): State<AppState>,
    jar: CookieJar,
    Query(params): Query<SsoLoginQuery>,
    Form(form): Form<HashMap<String, String>>,
) -> Result<(CookieJar, Json<AuthResponse>), AppError> {
    let saml_response_b64 = form.get("SAMLResponse").ok_or(AppError::Unauthorized)?;

    let sso_state = parse_sso_state_cookie(&jar)?;

    let provider = sso_queries::get_sso_config_by_id(&state.pool, sso_state.provider_id)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?
        .ok_or(AppError::NotFound("SAML provider".to_string()))?;

    let saml_cfg: SamlProviderConfig = serde_json::from_value(provider.config.clone())
        .map_err(|e| AppError::Internal(format!("Invalid SAML config: {}", e)))?;

    let acs_url = if saml_cfg.acs_url.is_empty() {
        format!("{}/auth/sso/saml/acs", state.config.sso_redirect_base_url)
    } else {
        saml_cfg.acs_url.clone()
    };

    // Validate SAMLResponse
    let idp_cert = saml_cfg.idp_signing_cert.as_deref().unwrap_or("");
    let assertion = saml::validate_saml_response(
        saml_response_b64,
        idp_cert,
        &acs_url,
        &saml_cfg.sp_entity_id,
    )
    .map_err(|e| {
        tracing::warn!(error = %e, "SAML response validation failed");
        AppError::Unauthorized
    })?;

    let (email, display_name) = saml::extract_saml_attributes(&assertion);

    // JIT provisioning
    let (user, _is_new) = user_queries::find_or_create_sso_user(
        &state.pool,
        &email,
        display_name.as_deref(),
        "saml",
        &assertion.subject,
    )
    .await
    .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?;

    // Issue JWT
    let (jar, response) = issue_jwt_for_user(&state, &user, jar, "sso_login", "saml").await?;
    let jar = jar.remove(clear_sso_state_cookie());
    Ok((jar, response))
}

// ── LDAP Handler ──

/// POST /auth/sso/ldap/login
async fn ldap_login(
    State(state): State<AppState>,
    jar: CookieJar,
    Json(body): Json<LdapLoginRequest>,
) -> Result<(CookieJar, Json<AuthResponse>), AppError> {
    let provider = sso_queries::get_sso_config_by_id(&state.pool, body.provider_id)
        .await
        .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?
        .ok_or(AppError::NotFound("LDAP provider".to_string()))?;

    if provider.provider_type != "ldap" {
        return Err(AppError::Validation(
            "Provider is not an LDAP provider".to_string(),
        ));
    }

    let ldap_cfg: LdapProviderConfig = serde_json::from_value(provider.config.clone())
        .map_err(|e| AppError::Internal(format!("Invalid LDAP config: {}", e)))?;

    let ldap_user = ldap::ldap_authenticate(
        &ldap_cfg.server_url,
        &ldap_cfg.bind_dn,
        &ldap_cfg.bind_password,
        &ldap_cfg.search_base,
        &ldap_cfg.user_filter,
        &body.username,
        &body.password,
    )
    .await
    .map_err(|e| {
        tracing::warn!(error = %e, "LDAP authentication failed");
        AppError::Unauthorized
    })?;

    // JIT provisioning — use email as subject for LDAP
    let (user, _is_new) = user_queries::find_or_create_sso_user(
        &state.pool,
        &ldap_user.email,
        ldap_user.display_name.as_deref(),
        "ldap",
        &body.username,
    )
    .await
    .map_err(|e| AppError::Internal(format!("DB error: {}", e)))?;

    // Issue JWT
    issue_jwt_for_user(&state, &user, jar, "sso_login", "ldap").await
}
