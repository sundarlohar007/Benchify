use jsonwebtoken::{decode, encode, Algorithm, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::error::AppError;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Claims {
    pub sub: String,
    pub email: String,
    pub role: String,
    pub scope: String,
    pub exp: usize,
    pub iat: usize,
    pub token_type: String,
}

/// Auth user extracted from JWT by middleware.
#[derive(Debug, Clone)]
pub struct AuthUser {
    pub user_id: Uuid,
    pub email: String,
    pub role: String,
}

pub fn create_access_token(user_id: Uuid, email: &str, role: &str, secret: &[u8]) -> Result<String, AppError> {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_err(|_| AppError::Internal("System clock is before UNIX epoch".to_string()))?
        .as_secs() as usize;
    let claims = Claims {
        sub: user_id.to_string(),
        email: email.to_string(),
        role: role.to_string(),
        scope: String::new(),
        exp: now + 3600, // 1 hour
        iat: now,
        token_type: "access".to_string(),
    };
    encode(&Header::default(), &claims, &EncodingKey::from_secret(secret))
        .map_err(|e| AppError::Internal(format!("JWT encode error: {}", e)))
}

pub fn create_refresh_token(user_id: Uuid, email: &str, secret: &[u8]) -> Result<String, AppError> {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_err(|_| AppError::Internal("System clock is before UNIX epoch".to_string()))?
        .as_secs() as usize;
    let claims = Claims {
        sub: user_id.to_string(),
        email: email.to_string(),
        role: String::new(),
        scope: String::new(),
        exp: now + 604800, // 7 days
        iat: now,
        token_type: "refresh".to_string(),
    };
    encode(&Header::default(), &claims, &EncodingKey::from_secret(secret))
        .map_err(|e| AppError::Internal(format!("JWT encode error: {}", e)))
}

/// Validate a JWT token and return its claims.
/// Uses HS256 algorithm explicitly — jsonwebtoken rejects 'none' by default.
pub fn validate_token(token: &str, secret: &[u8]) -> Result<Claims, AppError> {
    let mut validation = Validation::new(Algorithm::HS256);
    validation.leeway = 60; // 60-second clock skew tolerance
    validation.validate_exp = true;
    let token_data = decode::<Claims>(token, &DecodingKey::from_secret(secret), &validation).map_err(|e| {
        match e.kind() {
            jsonwebtoken::errors::ErrorKind::ExpiredSignature => AppError::Unauthorized,
            _ => AppError::Unauthorized,
        }
    })?;
    Ok(token_data.claims)
}
