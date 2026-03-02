use async_trait::async_trait;
use axum::{
    extract::FromRequestParts,
    http::request::Parts,
};
use uuid::Uuid;

use crate::{
    auth::jwt::{TokenKind, verify_token},
    error::AppError,
    AppState,
};

/// Authenticated user extracted from JWT — injected into handlers via extractor.
#[derive(Debug, Clone)]
#[allow(dead_code)]
pub struct AuthUser {
    pub id: Uuid,
    pub email: String,
    pub pro: bool,
    pub admin: bool,
}

#[allow(dead_code)]
impl AuthUser {
    /// Returns Err if user is not Pro.
    pub fn require_pro(&self) -> Result<(), AppError> {
        if self.pro {
            Ok(())
        } else {
            Err(AppError::UpgradeRequired)
        }
    }

    /// Returns Err if user is not admin.
    pub fn require_admin(&self) -> Result<(), AppError> {
        if self.admin {
            Ok(())
        } else {
            Err(AppError::Forbidden("Admin access required".to_string()))
        }
    }
}

#[async_trait]
impl FromRequestParts<AppState> for AuthUser {
    type Rejection = AppError;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        let token = extract_bearer(parts)?;
        let claims = verify_token(&token, &state.config.jwt_secret)?;

        if claims.kind != TokenKind::Access {
            return Err(AppError::Unauthorized(
                "Refresh token cannot be used for API access".to_string(),
            ));
        }

        Ok(AuthUser {
            id: claims.sub,
            email: claims.email,
            pro: claims.pro,
            admin: claims.admin,
        })
    }
}

fn extract_bearer(parts: &Parts) -> Result<String, AppError> {
    let header = parts
        .headers
        .get("Authorization")
        .and_then(|v| v.to_str().ok())
        .ok_or_else(|| AppError::Unauthorized("Missing Authorization header".to_string()))?;

    header
        .strip_prefix("Bearer ")
        .map(|t| t.to_string())
        .ok_or_else(|| AppError::Unauthorized("Invalid Authorization header format".to_string()))
}
