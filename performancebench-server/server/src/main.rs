use std::net::SocketAddr;

use db::connection;
use db::migrations;
use server::config::AppConfig;
use server::routes::create_router;
use server::state::AppState;

#[tokio::main]
async fn main() {
    // Initialize tracing
    tracing_subscriber::fmt()
        .json()
        .with_env_filter("info,performancebench_server=debug")
        .init();

    tracing::info!("Starting PerformanceBench server...");

    // Load configuration
    let config = AppConfig::from_env().expect("Failed to load configuration");
    tracing::info!(
        host = %config.host,
        port = config.port,
        "Configuration loaded"
    );

    // Run migrations (sync, before pool creation)
    migrations::run_migrations(&config.database_url).expect("Failed to run migrations");
    tracing::info!("Database migrations complete");

    // Build database connection pool
    let pool = connection::create_pool(&config.database_url);
    tracing::info!("Database connection pool created");

    // Build application state
    let state = AppState::new(pool, config.clone());

    // Build router
    let router = create_router(state);

    // Bind and serve
    let addr: SocketAddr = format!("{}:{}", config.host, config.port)
        .parse()
        .expect("Invalid host:port binding address");

    tracing::info!("Server listening on {}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, router.into_make_service())
        .await
        .unwrap();
}
