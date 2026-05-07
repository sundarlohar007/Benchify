use crate::error::AppError;

/// Hash a password using bcrypt with cost factor 12.
pub fn hash_password(password: &str) -> Result<String, AppError> {
    bcrypt::hash(password, 12)
        .map_err(|e| AppError::Internal(format!("Password hashing failed: {}", e)))
}

/// Verify a password against a bcrypt hash.
pub fn verify_password(password: &str, hash: &str) -> Result<bool, AppError> {
    bcrypt::verify(password, hash)
        .map_err(|e| AppError::Internal(format!("Password verification failed: {}", e)))
}

/// Validate password meets minimum policy: 8+ chars, at least 1 letter + 1 number.
pub fn validate_password_policy(password: &str) -> Result<(), AppError> {
    if password.len() < 8 {
        return Err(AppError::Validation(
            "Password must be at least 8 characters with at least 1 letter and 1 number"
                .to_string(),
        ));
    }
    let has_letter = password.chars().any(|c| c.is_alphabetic());
    let has_number = password.chars().any(|c| c.is_numeric());
    if !has_letter || !has_number {
        return Err(AppError::Validation(
            "Password must be at least 8 characters with at least 1 letter and 1 number"
                .to_string(),
        ));
    }
    Ok(())
}
