use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use axum::Router;
use axum::extract::ConnectInfo;
use axum::http::{HeaderValue, Method, StatusCode};
use axum::middleware::{self, Next, from_fn_with_state};
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use tower_http::compression::CompressionLayer;
use tower_http::cors::{AllowOrigin, CorsLayer};
use tower_http::trace::TraceLayer;

use crate::middleware::api_token as api_token_mw;
use crate::middleware::auth as auth_mw;
use crate::middleware::rbac;
use crate::state::AppState;

pub mod admin;
pub mod alerts;
pub mod audit;
pub mod auth;
pub mod devices;
pub mod health;
pub mod jira;
pub mod lenses;
pub mod openapi;
pub mod sessions;
pub mod sso;
pub mod teams;
pub mod tokens;
pub mod trends;
pub mod upload;
pub mod webhooks;
pub mod ws;

/// Simple in-memory IP rate limiter for auth endpoints (replaces non-Clone RateLimitLayer).
#[derive(Clone, Default)]
struct AuthRateLimiter {
    hits: Arc<Mutex<HashMap<String, Vec<Instant>>>>,
}

impl AuthRateLimiter {
    fn allow(&self, key: &str, max: usize, window: Duration) -> bool {
        let mut map = self.hits.lock().unwrap_or_else(|e| e.into_inner());
        let now = Instant::now();
        let entry = map.entry(key.to_string()).or_default();
        entry.retain(|t| now.duration_since(*t) < window);
        if entry.len() >= max {
            return false;
        }
        entry.push(now);
        true
    }
}

async fn auth_rate_limit(
    axum::Extension(limiter): axum::Extension<AuthRateLimiter>,
    request: axum::extract::Request,
    next: Next,
) -> Response {
    let key = request
        .extensions()
        .get::<ConnectInfo<std::net::SocketAddr>>()
        .map(|c| c.0.ip().to_string())
        .unwrap_or_else(|| "unknown".to_string());
    if !limiter.allow(&key, 5, Duration::from_secs(60)) {
        return (StatusCode::TOO_MANY_REQUESTS, "rate limit exceeded").into_response();
    }
    next.run(request).await
}

fn build_cors(state: &AppState) -> CorsLayer {
    let origins = &state.config.cors_allowed_origins;
    if origins.iter().any(|o| o.trim() == "*") {
        return CorsLayer::permissive();
    }

    let parsed: Vec<HeaderValue> = origins
        .iter()
        .filter_map(|o| HeaderValue::from_str(o.trim()).ok())
        .collect();

    if parsed.is_empty() {
        CorsLayer::new()
            .allow_origin(AllowOrigin::list([
                HeaderValue::from_static("http://localhost:5173"),
                HeaderValue::from_static("http://localhost:3000"),
            ]))
            .allow_methods([
                Method::GET,
                Method::POST,
                Method::PUT,
                Method::PATCH,
                Method::DELETE,
                Method::OPTIONS,
            ])
            .allow_headers(tower_http::cors::Any)
            .allow_credentials(true)
    } else {
        CorsLayer::new()
            .allow_origin(AllowOrigin::list(parsed))
            .allow_methods([
                Method::GET,
                Method::POST,
                Method::PUT,
                Method::PATCH,
                Method::DELETE,
                Method::OPTIONS,
            ])
            .allow_headers(tower_http::cors::Any)
            .allow_credentials(true)
    }
}

pub fn create_router(state: AppState) -> Router {
    let auth_limiter = AuthRateLimiter::default();

    let public_auth = Router::new()
        .route("/auth/login", post(auth::login))
        .route("/auth/register", post(auth::register))
        .route("/auth/refresh", post(auth::refresh))
        .route("/auth/logout", post(auth::logout))
        .merge(sso::sso_router())
        .layer(middleware::from_fn(auth_rate_limit))
        .layer(axum::Extension(auth_limiter));

    let protected_auth = Router::new()
        .route("/auth/me", get(auth::me))
        .route_layer(from_fn_with_state(state.clone(), auth_mw::auth_middleware));

    let health_routes = Router::new().route("/health", get(health::health_check));

    let ws_routes = Router::new()
        .route("/live/{session_id}", get(ws::ws_handler))
        .route_layer(from_fn_with_state(state.clone(), auth_mw::auth_middleware));

    let openapi_routes = Router::new().route("/api/v1/openapi.json", get(openapi::openapi_json));

    // API-token-only routes (D-32) — outside JWT middleware
    let api_token_routes = Router::new()
        .route("/sessions", post(upload::upload_session))
        .route(
            "/sessions/{session_id}/live/batch",
            post(ws::push_live_batch),
        )
        .route_layer(from_fn_with_state(
            state.clone(),
            api_token_mw::api_token_middleware,
        ));

    let jwt_routes = Router::new()
        .nest("/sessions", sessions::router())
        .nest("/trends", trends::router())
        .nest("/lenses", lenses::router())
        .nest("/alerts", alerts::router())
        .nest("/devices", devices::router())
        .nest("/tokens", tokens::router())
        .nest("/webhooks", webhooks::router())
        .route_layer(from_fn_with_state(state.clone(), auth_mw::auth_middleware));

    let audit_routes = audit::audit_router()
        .route_layer(from_fn_with_state(
            state.clone(),
            rbac::require_role(rbac::Role::Auditor),
        ))
        .route_layer(from_fn_with_state(state.clone(), auth_mw::auth_middleware));

    let team_routes = teams::teams_router()
        .route_layer(from_fn_with_state(
            state.clone(),
            rbac::require_role(rbac::Role::Viewer),
        ))
        .route_layer(from_fn_with_state(state.clone(), auth_mw::auth_middleware));

    let admin_routes = admin::admin_router()
        .route_layer(from_fn_with_state(state.clone(), rbac::require_admin()))
        .route_layer(from_fn_with_state(state.clone(), auth_mw::auth_middleware));

    let cors = build_cors(&state);

    Router::new()
        .merge(health_routes)
        .merge(public_auth)
        .merge(protected_auth)
        .merge(openapi_routes)
        .nest("/ws", ws_routes)
        .nest(
            "/api/v1",
            Router::new()
                .merge(api_token_routes)
                .merge(jwt_routes)
                .nest("/audit", audit_routes)
                .nest("/teams", team_routes)
                .nest("/admin", admin_routes),
        )
        .layer(TraceLayer::new_for_http())
        .layer(CompressionLayer::new().gzip(true))
        .layer(cors)
        .with_state(state)
}
