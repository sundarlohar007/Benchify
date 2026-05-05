use std::net::SocketAddr;

use db::connection;
use db::migrations;
use db::user_queries;
use server::config::AppConfig;
use server::routes::create_router;
use server::state::AppState;
use server::utils::password;

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

    // First-user auto-admin: if no users exist, create default admin
    let user_count = user_queries::count_users(&pool).await.unwrap_or(0);
    if user_count == 0 {
        let admin_password = generate_random_password();
        let password_hash = password::hash_password(&admin_password)
            .expect("Failed to hash admin password");
        user_queries::create_user(&pool, "admin@localhost", &password_hash, Some("Admin"), "admin")
            .await
            .expect("Failed to create default admin user");
        tracing::warn!(
            event_type = "auto_admin_created",
            email = "admin@localhost",
            password = %admin_password,
            "No users found — created default admin user. CHANGE THIS PASSWORD IMMEDIATELY."
        );
    }

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

/// Generate a cryptographically random 16-character alphanumeric password.
fn generate_random_password() -> String {
    use rand::Rng;
    const CHARSET: &[u8] = b"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    let mut rng = rand::thread_rng();
    (0..16)
        .map(|_| {
            let idx = rng.gen_range(0..CHARSET.len());
            CHARSET[idx] as char
        })
        .collect()
}
