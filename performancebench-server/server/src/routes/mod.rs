use axum::middleware::from_fn_with_state;
use axum::routing::{get, post};
use axum::Router;
use tower_http::compression::CompressionLayer;
use tower_http::cors::CorsLayer;
use tower_http::trace::TraceLayer;

use crate::middleware::auth as auth_mw;
use crate::middleware::api_token as api_token_mw;
use crate::middleware::rbac;
use crate::state::AppState;

pub mod admin;
pub mod alerts;
pub mod auth;
pub mod devices;
pub mod health;
pub mod lenses;
pub mod openapi;
pub mod sessions;
pub mod sso;
pub mod tokens;
pub mod trends;
pub mod upload;
pub mod webhooks;
pub mod ws;

pub fn create_router(state: AppState) -> Router {
    // ── Public routes (no auth required) ──

    // Auth routes
    let public_auth = Router::new()
        .route("/auth/login", post(auth::login))
        .route("/auth/register", post(auth::register))
        .route("/auth/refresh", post(auth::refresh))
        .route("/auth/logout", post(auth::logout))
        .merge(sso::sso_router());

    // Protected auth routes (require JWT)
    let protected_auth = Router::new()
        .route("/auth/me", get(auth::me))
        .route_layer(from_fn_with_state(state.clone(), auth_mw::auth_middleware));

    // Health check
    let health_routes = Router::new()
        .route("/health", get(health::health_check));

    // WebSocket live overlay (D-47, V20-17)
    // No auth middleware — auth checked implicitly by session UUID (unguessable)
    let ws_routes = Router::new()
        .route("/live/{session_id}", get(ws::ws_handler));

    // OpenAPI docs (no auth required)
    let openapi_routes = Router::new()
        .route("/api/v1/openapi.json", get(openapi::openapi_json));

    // ── Upload route (API token auth, not JWT cookie) ──
    // The upload endpoint uses API token Bearer auth with "write" scope (D-32).
    // It must be OUTSIDE the JWT cookie middleware.
    let upload_routes = Router::new()
        .route("/sessions", post(upload::upload_session));

    // Live push batch endpoint (API token auth, desktop -> server push)
    let live_push_routes = Router::new()
        .route("/sessions/{session_id}/live/batch", post(ws::push_live_batch))
        .route_layer(from_fn_with_state(state.clone(), api_token_mw::api_token_middleware));

    // ── API v1 (JWT cookie auth required) ──
    let v1_sessions = sessions::router();
    let v1_trends = trends::router();
    let v1_lenses = lenses::router();
    let v1_alerts = alerts::router();
    let v1_devices = devices::router();
    let v1_tokens = tokens::router();
    let v1_webhooks = webhooks::router();

    // Merge upload + live push routes into sessions scope
    let v1_sessions_with_upload = Router::new()
        .merge(upload_routes)
        .merge(live_push_routes)
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

    // ── Admin routes (JWT + RBAC Admin role required) ──
    let admin_routes = admin::admin_router()
        .route_layer(from_fn_with_state(state.clone(), auth_mw::auth_middleware))
        .route_layer(from_fn_with_state(state.clone(), rbac::require_admin()));

    // ── Compose final router ──
    Router::new()
        .merge(health_routes)
        .merge(public_auth)
        .merge(protected_auth)
        .merge(openapi_routes)
        .nest("/ws", ws_routes)
        .nest("/api/v1", api_routes)
        .nest("/api/v1/admin", admin_routes)
        .layer(TraceLayer::new_for_http())
        .layer(CompressionLayer::new().gzip(true))
        .layer(CorsLayer::permissive())
        .with_state(state)
}
