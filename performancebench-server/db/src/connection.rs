use diesel_async::AsyncPgConnection;
use diesel_async::pooled_connection::AsyncDieselConnectionManager;
use diesel_async::pooled_connection::deadpool::Pool;

pub type DbPool = Pool<AsyncPgConnection>;

/// Create a database connection pool using diesel-async's deadpool integration.
pub fn create_pool(database_url: &str) -> DbPool {
    let manager = AsyncDieselConnectionManager::<AsyncPgConnection>::new(database_url);
    Pool::builder(manager)
        .build()
        .expect("Failed to create database pool")
}
