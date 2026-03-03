use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum AppError {
    #[error("Not found: {0}")]
    NotFound(String),

    #[error("Unauthorized: {0}")]
    Unauthorized(String),

    #[error("Forbidden: {0}")]
    Forbidden(String),

    #[error("Bad request: {0}")]
    BadRequest(String),

    #[error("Conflict: {0}")]
    Conflict(String),

    #[error("Upgrade required")]
    UpgradeRequired,

    #[error("Rate limit exceeded")]
    RateLimited,

    #[error("Rate limit exceeded")]
    RateLimitedWithRetry(u64), // seconds until the client may retry

    #[error("Database error: {0}")]
    Database(#[from] sqlx::Error),

    #[error("Internal error: {0}")]
    Internal(#[from] anyhow::Error),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        // Handle RateLimitedWithRetry separately: it needs a Retry-After header.
        if let AppError::RateLimitedWithRetry(secs) = self {
            let body = Json(json!({
                "error": "rate_limited",
                "message": "Too many requests"
            }));
            return (
                StatusCode::TOO_MANY_REQUESTS,
                [("Retry-After", secs.to_string())],
                body,
            )
                .into_response();
        }

        let (status, code, message) = match &self {
            AppError::NotFound(msg) => (StatusCode::NOT_FOUND, "not_found", msg.clone()),
            AppError::Unauthorized(msg) => (StatusCode::UNAUTHORIZED, "unauthorized", msg.clone()),
            AppError::Forbidden(msg) => (StatusCode::FORBIDDEN, "forbidden", msg.clone()),
            AppError::BadRequest(msg) => (StatusCode::BAD_REQUEST, "bad_request", msg.clone()),
            AppError::Conflict(msg) => (StatusCode::CONFLICT, "conflict", msg.clone()),
            AppError::UpgradeRequired => (
                StatusCode::PAYMENT_REQUIRED,
                "upgrade_required",
                "Pro subscription required".to_string(),
            ),
            AppError::RateLimited => (
                StatusCode::TOO_MANY_REQUESTS,
                "rate_limited",
                "Too many requests".to_string(),
            ),
            // Already handled above; unreachable here.
            AppError::RateLimitedWithRetry(_) => unreachable!(),
            AppError::Database(e) => {
                tracing::error!("Database error: {e}");
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "database_error",
                    "A database error occurred".to_string(),
                )
            }
            AppError::Internal(e) => {
                tracing::error!("Internal error: {e:#}");
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "internal_error",
                    "An internal error occurred".to_string(),
                )
            }
        };

        let body = Json(json!({ "error": code, "message": message }));
        (status, body).into_response()
    }
}

pub type AppResult<T> = Result<T, AppError>;
