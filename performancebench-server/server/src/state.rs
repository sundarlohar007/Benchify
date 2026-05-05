use crate::config::AppConfig;

#[derive(Clone)]
pub struct AppState {
    pub pool: deadpool_postgres::Pool,
    pub config: AppConfig,
}

impl AppState {
    pub fn new(pool: deadpool_postgres::Pool, config: AppConfig) -> Self {
        Self { pool, config }
    }
}
