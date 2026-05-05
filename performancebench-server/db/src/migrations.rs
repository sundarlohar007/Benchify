use diesel::prelude::*;
use diesel::PgConnection;
use diesel_migrations::{embed_migrations, EmbeddedMigrations, MigrationHarness};

pub const MIGRATIONS: EmbeddedMigrations = embed_migrations!("../migrations");

/// Run all pending Diesel migrations against the database.
/// Uses a synchronous PgConnection — call this at startup before
/// creating the async deadpool.
pub fn run_migrations(database_url: &str) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let mut conn = PgConnection::establish(database_url)?;
    conn.run_pending_migrations(MIGRATIONS)?;
    tracing::info!("Database migrations complete");
    Ok(())
}
