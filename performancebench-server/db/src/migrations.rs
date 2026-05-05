use deadpool_postgres::Pool;

/// Run pending migrations. Currently a no-op — Diesel migrations will be
/// wired in Task 2 when the initial schema migration is created.
pub async fn run_migrations(_pool: &Pool) -> Result<(), Box<dyn std::error::Error>> {
    tracing::info!("Migrations: no migrations configured yet (will be wired in Task 2)");
    Ok(())
}
