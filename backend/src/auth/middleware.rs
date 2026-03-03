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

#[cfg(test)]
mod tests {
    use super::*;

    fn make_user(pro: bool, admin: bool) -> AuthUser {
        AuthUser {
            id: Uuid::new_v4(),
            email: "test@test.com".to_string(),
            pro,
            admin,
        }
    }

    #[test]
    fn non_pro_user_gets_upgrade_required() {
        let user = make_user(false, false);
        assert!(matches!(user.require_pro(), Err(AppError::UpgradeRequired)));
    }

    #[test]
    fn pro_user_passes_require_pro() {
        let user = make_user(true, false);
        assert!(user.require_pro().is_ok());
    }

    #[test]
    fn non_admin_gets_forbidden() {
        let user = make_user(false, false);
        assert!(matches!(user.require_admin(), Err(AppError::Forbidden(_))));
    }

    #[test]
    fn admin_passes_require_admin() {
        let user = make_user(false, true);
        assert!(user.require_admin().is_ok());
    }

    #[test]
    fn pro_admin_user_passes_both_checks() {
        let user = make_user(true, true);
        assert!(user.require_pro().is_ok());
        assert!(user.require_admin().is_ok());
    }

    #[test]
    fn admin_without_pro_fails_pro_check() {
        // Admin does not automatically grant Pro — they are orthogonal flags.
        let user = make_user(false, true);
        assert!(matches!(user.require_pro(), Err(AppError::UpgradeRequired)));
    }
}
