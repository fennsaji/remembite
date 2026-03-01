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

pub fn issue_refresh_token(
    user_id: Uuid,
    email: &str,
    pro: bool,
    admin: bool,
    secret: &str,
    expiry_days: u64,
) -> AppResult<String> {
    let now = Utc::now();
    let exp = (now + Duration::days(expiry_days as i64)).timestamp();
    let claims = Claims {
        sub: user_id,
        email: email.to_string(),
        pro,
        admin,
        exp,
        iat: now.timestamp(),
        kind: TokenKind::Refresh,
    };
    encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(secret.as_bytes()),
    )
    .map_err(|e| AppError::Internal(anyhow::anyhow!("JWT encode error: {e}")))
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
