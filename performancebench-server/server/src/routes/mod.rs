use axum::middleware::from_fn_with_state;
use axum::routing::{get, post};
use axum::Router;
use tower_http::compression::CompressionLayer;
use tower_http::cors::CorsLayer;
use tower_http::trace::TraceLayer;

use crate::middleware::auth as auth_mw;
use crate::middleware::api_token as api_token_mw;
use crate::state::AppState;

pub mod alerts;
pub mod auth;
pub mod devices;
pub mod health;
pub mod lenses;
pub mod openapi;
pub mod sessions;
pub mod tokens;
pub mod trends;
pub mod upload;
pub mod webhooks;

pub fn create_router(state: AppState) -> Router {
    // ── Public routes (no auth required) ──

    // Auth routes
    let public_auth = Router::new()
        .route("/auth/login", post(auth::login))
        .route("/auth/register", post(auth::register))
        .route("/auth/refresh", post(auth::refresh))
        .route("/auth/logout", post(auth::logout));

    // Protected auth routes (require JWT)
    let protected_auth = Router::new()
        .route("/auth/me", get(auth::me))
        .route_layer(from_fn_with_state(state.clone(), auth_mw::auth_middleware));

    // Health check
    let health_routes = Router::new()
        .route("/health", get(health::health_check));

    // OpenAPI docs (no auth required)
    let openapi_routes = Router::new()
        .route("/api/v1/openapi.json", get(openapi::openapi_json));

    // ── Upload route (API token auth, not JWT cookie) ──
    // The upload endpoint uses API token Bearer auth with "write" scope (D-32).
    // It must be OUTSIDE the JWT cookie middleware.
    let upload_routes = Router::new()
        .route("/sessions", post(upload::upload_session))
        .route_layer(from_fn_with_state(state.clone(), api_token_mw::api_token_middleware));

    // ── API v1 (JWT cookie auth required) ──
    let v1_sessions = sessions::router();
    let v1_trends = trends::router();
    let v1_lenses = lenses::router();
    let v1_alerts = alerts::router();
    let v1_devices = devices::router();
    let v1_tokens = tokens::router();
    let v1_webhooks = webhooks::router();

    // Merge upload routes into sessions scope
    let v1_sessions_with_upload = Router::new()
        .merge(upload_routes)
        .merge(v1_sessions);

    let api_routes = Router::new()
        .nest("/sessions", v1_sessions_with_upload)
        .nest("/trends", v1_trends)
        .nest("/lenses", v1_lenses)
        .nest("/alerts", v1_alerts)
        .nest("/devices", v1_devices)
        .nest("/tokens", v1_tokens)
        .nest("/webhooks", v1_webhooks)
        .route_layer(from_fn_with_state(state.clone(), auth_mw::auth_middleware));

    // ── Compose final router ──
    Router::new()
        .merge(health_routes)
        .merge(public_auth)
        .merge(protected_auth)
        .merge(openapi_routes)
        .nest("/api/v1", api_routes)
        .layer(TraceLayer::new_for_http())
        .layer(CompressionLayer::new().gzip(true))
        .layer(CorsLayer::permissive())
        .with_state(state)
}
