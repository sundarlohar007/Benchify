use axum::middleware::from_fn_with_state;
use axum::routing::{get, post};
use axum::Router;
use tower_http::compression::CompressionLayer;
use tower_http::cors::CorsLayer;
use tower_http::trace::TraceLayer;

use crate::middleware::auth as auth_mw;
use crate::state::AppState;

pub mod auth;
pub mod health;

pub fn create_router(state: AppState) -> Router {
    // Public routes — no auth required
    let public_auth = Router::new()
        .route("/auth/login", post(auth::login))
        .route("/auth/register", post(auth::register))
        .route("/auth/refresh", post(auth::refresh))
        .route("/auth/logout", post(auth::logout));

    // Protected routes — require valid JWT
    let protected_auth = Router::new()
        .route("/auth/me", get(auth::me))
        .route_layer(from_fn_with_state(state.clone(), auth_mw::auth_middleware));

    // Health check
    let health_routes = Router::new()
        .route("/health", get(health::health_check));

    // API v1 (empty for now — populated in later waves)
    let api_routes = Router::new();

    Router::new()
        .merge(health_routes)
        .merge(public_auth)
        .merge(protected_auth)
        .nest("/api/v1", api_routes)
        .layer(TraceLayer::new_for_http())
        .layer(CompressionLayer::new().gzip(true))
        .layer(CorsLayer::permissive())
        .with_state(state)
}
