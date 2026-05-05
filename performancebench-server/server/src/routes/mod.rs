use axum::routing::get;
use axum::Router;
use tower_http::compression::CompressionLayer;
use tower_http::cors::CorsLayer;
use tower_http::trace::TraceLayer;

use crate::state::AppState;

pub mod auth;
pub mod health;

pub fn create_router(state: AppState) -> Router {
    let public_routes = Router::new()
        .route("/health", get(health::health_check));

    let api_routes = Router::new();

    Router::new()
        .merge(public_routes)
        .nest("/api/v1", api_routes)
        .layer(TraceLayer::new_for_http())
        .layer(CompressionLayer::new().gzip(true))
        .layer(CorsLayer::permissive())
        .with_state(state)
}
