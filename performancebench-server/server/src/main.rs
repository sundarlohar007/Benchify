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

    // Bind and serve — with or without TLS (D-16)
    let addr: SocketAddr = format!("{}:{}", config.host, config.port)
        .parse()
        .expect("Invalid host:port binding address");

    if let (Some(cert_path), Some(key_path)) = (config.tls_cert_path.as_ref(), config.tls_key_path.as_ref()) {
        // TLS mode — load certificate and private key via rustls + axum_server
        tracing::info!(
            cert_path = %cert_path,
            key_path = %key_path,
            "TLS configured — starting HTTPS server"
        );

        match axum_server::tls_rustls::RustlsConfig::from_pem_file(cert_path, key_path).await {
            Ok(tls_config) => {
                tracing::info!("TLS certificate loaded successfully");
                // Start HTTPS server
                let handle = axum_server::Handle::new();
                let shutdown_future = shutdown_signal(handle.clone());

                let server = axum_server::bind_rustls(addr, tls_config)
                    .handle(handle)
                    .serve(router.into_make_service());

                // Also start HTTP→HTTPS redirect on port+1 if configured
                let https_host = config.host.clone();
                let https_port = config.port;
                let redirect_addr: SocketAddr = format!("{}:{}", config.host, config.port.wrapping_sub(443).max(1))
                    .parse()
                    .expect("Invalid redirect port");

                let redirect_router = axum::Router::new()
                    .fallback(axum::routing::get(move |_host: axum::http::HeaderMap| async move {
                        // Simple redirect — redirect all HTTP to HTTPS
                        axum::response::Redirect::permanent(&format!(
                            "https://{}:{}/",
                            https_host,
                            https_port
                        ))
                    }));

                tracing::info!("HTTP→HTTPS redirect listening on {}", redirect_addr);
                let redirect_listener = tokio::net::TcpListener::bind(redirect_addr)
                    .await
                    .expect("Failed to bind HTTP redirect listener");

                // Serve both HTTPS and HTTP redirect
                tokio::select! {
                    _ = server => {
                        tracing::info!("HTTPS server stopped");
                    }
                    _ = axum::serve(redirect_listener, redirect_router.into_make_service()) => {
                        tracing::info!("HTTP redirect server stopped");
                    }
                    _ = shutdown_future => {
                        tracing::info!("Shutdown signal received");
                    }
                }
            }
            Err(e) => {
                tracing::error!(
                    error = %e,
                    cert_path = %cert_path,
                    key_path = %key_path,
                    "Failed to load TLS certificate — starting in plain HTTP mode"
                );
                serve_plain_http(addr, router).await;
            }
        }
    } else {
        // Plain HTTP mode (no TLS configured)
        tracing::warn!("TLS not configured — server running in plain HTTP mode");
        serve_plain_http(addr, router).await;
    }
}

/// Start the server in plain HTTP mode.
async fn serve_plain_http(addr: SocketAddr, router: axum::Router) {
    tracing::info!("Server listening on http://{}", addr);

    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .expect("Failed to bind HTTP listener");

    axum::serve(listener, router.into_make_service())
        .await
        .expect("Server error");
}

/// Graceful shutdown on SIGINT/SIGTERM.
async fn shutdown_signal(handle: axum_server::Handle) {
    let ctrl_c = async {
        tokio::signal::ctrl_c()
            .await
            .expect("Failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
            .expect("Failed to install SIGTERM handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }

    tracing::info!("Shutdown signal received — starting graceful shutdown");
    handle.graceful_shutdown(Some(std::time::Duration::from_secs(30)));
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
