use chrono::{Duration, Utc};
use jsonwebtoken::{DecodingKey, EncodingKey, Header, Validation, decode, encode};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::error::{AppError, AppResult};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Claims {
    pub sub: Uuid,          // user id
    pub email: String,
    pub pro: bool,
    pub admin: bool,
    pub exp: i64,
    pub iat: i64,
    pub kind: TokenKind,
}

/// Refresh-token payload: `Claims` plus a unique `jti`.
///
/// Kept as its own struct rather than an extra field on `Claims` because
/// decoding ignores unknown fields — `verify_token` still returns `Claims`,
/// and nothing outside issuance needs to read the `jti`. Its only job is to
/// make every issued refresh token byte-unique, so two tokens minted for the
/// same user in the same second can't collide on `refresh_sessions.token_hash`.
#[derive(Debug, Serialize, Deserialize, Clone)]
struct RefreshClaims {
    #[serde(flatten)]
    claims: Claims,
    jti: Uuid,
}

#[derive(Debug, Serialize, Deserialize, Clone, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum TokenKind {
    Access,
    Refresh,
}

pub fn issue_access_token(
    user_id: Uuid,
    email: &str,
    pro: bool,
    admin: bool,
    secret: &str,
    expiry_hours: u64,
) -> AppResult<String> {
    let now = Utc::now();
    let exp = (now + Duration::hours(expiry_hours as i64)).timestamp();
    let claims = Claims {
        sub: user_id,
        email: email.to_string(),
        pro,
        admin,
        exp,
        iat: now.timestamp(),
        kind: TokenKind::Access,
    };
    encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(secret.as_bytes()),
    )
    .map_err(|e| AppError::Internal(anyhow::anyhow!("JWT encode error: {e}")))
}

/// Issues a refresh token carrying a fresh `jti`, returned alongside the token
/// so the caller can record it in `refresh_sessions`.
pub fn issue_refresh_token_with_jti(
    user_id: Uuid,
    email: &str,
    pro: bool,
    admin: bool,
    secret: &str,
    expiry_days: u64,
) -> AppResult<(String, Uuid, chrono::DateTime<Utc>)> {
    let now = Utc::now();
    let expires_at = now + Duration::days(expiry_days as i64);
    let jti = Uuid::new_v4();
    let claims = RefreshClaims {
        claims: Claims {
            sub: user_id,
            email: email.to_string(),
            pro,
            admin,
            exp: expires_at.timestamp(),
            iat: now.timestamp(),
            kind: TokenKind::Refresh,
        },
        jti,
    };
    let token = encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(secret.as_bytes()),
    )
    .map_err(|e| AppError::Internal(anyhow::anyhow!("JWT encode error: {e}")))?;
    Ok((token, jti, expires_at))
}

/// Convenience wrapper for callers that only need the token string.
#[allow(dead_code)]
pub fn issue_refresh_token(
    user_id: Uuid,
    email: &str,
    pro: bool,
    admin: bool,
    secret: &str,
    expiry_days: u64,
) -> AppResult<String> {
    issue_refresh_token_with_jti(user_id, email, pro, admin, secret, expiry_days)
        .map(|(token, _, _)| token)
}

pub fn verify_token(token: &str, secret: &str) -> AppResult<Claims> {
    decode::<Claims>(
        token,
        &DecodingKey::from_secret(secret.as_bytes()),
        &Validation::default(),
    )
    .map(|data| data.claims)
    .map_err(|e| AppError::Unauthorized(format!("Invalid token: {e}")))
}
