use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::Json;
use serde_json::{json, Value};

#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("Invalid or expired credentials")]
    Unauthorized,

    #[error("Insufficient permissions")]
    Forbidden,

    #[error("{0} not found")]
    NotFound(String),

    #[error("{0}")]
    Conflict(String),

    #[error("{0}")]
    Validation(String),

    #[error("Internal server error: {0}")]
    Internal(String),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, code, message, details): (StatusCode, &str, String, Option<Value>) = match &self {
            AppError::Unauthorized => (
                StatusCode::UNAUTHORIZED,
                "UNAUTHORIZED",
                "Invalid or expired credentials".to_string(),
                None,
            ),
            AppError::Forbidden => (
                StatusCode::FORBIDDEN,
                "FORBIDDEN",
                "Insufficient permissions".to_string(),
                None,
            ),
            AppError::NotFound(resource) => (
                StatusCode::NOT_FOUND,
                "NOT_FOUND",
                format!("{} not found", resource),
                None,
            ),
            AppError::Conflict(reason) => (
                StatusCode::CONFLICT,
                "CONFLICT",
                reason.clone(),
                None,
            ),
            AppError::Validation(reason) => (
                StatusCode::UNPROCESSABLE_ENTITY,
                "VALIDATION_ERROR",
                reason.clone(),
                None,
            ),
            AppError::Internal(_inner) => (
                StatusCode::INTERNAL_SERVER_ERROR,
                "INTERNAL_ERROR",
                "Internal server error".to_string(),
                None,
            ),
        };

        let body = json!({
            "code": code,
            "message": message,
            "details": details,
        });

        (status, Json(body)).into_response()
    }
}
