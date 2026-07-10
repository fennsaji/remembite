use std::net::SocketAddr;

use axum::{
    Json, Router,
    extract::{ConnectInfo, State},
    routing::patch,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{
    AppState,
    auth::{
        google::verify_google_id_token,
        jwt::{TokenKind, issue_access_token, issue_refresh_token, verify_token},
        middleware::AuthUser,
    },
    dto::FcmTokenRequest,
    error::{AppError, AppResult},
    middleware::rate_limit::check_ip_limit,
};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/users/me/fcm-token", patch(update_fcm_token))
        .route("/auth/refresh", axum::routing::post(refresh_tokens))
}

#[derive(Deserialize)]
pub struct RefreshRequest {
    pub refresh_token: String,
}

#[derive(Serialize)]
pub struct RefreshResponse {
    pub access_token: String,
    pub refresh_token: String,
    pub pro_status: bool,
}

/// Exchange a valid refresh token for a fresh access+refresh pair.
/// Re-reads pro/admin from the DB so the new access token reflects current status.
async fn refresh_tokens(
    State(state): State<AppState>,
    Json(req): Json<RefreshRequest>,
) -> AppResult<Json<RefreshResponse>> {
    let claims = verify_token(&req.refresh_token, &state.config.jwt_secret)?;
    if claims.kind != TokenKind::Refresh {
        return Err(AppError::Unauthorized(
            "Not a refresh token".to_string(),
        ));
    }

    // Re-read current pro/admin state — refresh must reflect revocations/upgrades.
    let row: Option<(bool, bool)> =
        sqlx::query_as("SELECT pro_status, is_admin FROM users WHERE id = $1")
            .bind(claims.sub)
            .fetch_optional(&state.db)
            .await?;
    let (pro_status, is_admin) =
        row.ok_or_else(|| AppError::Unauthorized("User no longer exists".to_string()))?;

    let access_token = issue_access_token(
        claims.sub,
        &claims.email,
        pro_status,
        is_admin,
        &state.config.jwt_secret,
        state.config.jwt_access_expiry_hours,
    )?;
    let refresh_token = issue_refresh_token(
        claims.sub,
        &claims.email,
        pro_status,
        is_admin,
        &state.config.jwt_secret,
        state.config.jwt_refresh_expiry_days,
    )?;

    Ok(Json(RefreshResponse {
        access_token,
        refresh_token,
        pro_status,
    }))
}

#[derive(Deserialize)]
pub struct GoogleAuthRequest {
    pub id_token: String,
}

#[derive(Serialize)]
pub struct AuthResponse {
    pub access_token: String,
    pub refresh_token: String,
    pub user: UserDto,
}

#[derive(Serialize)]
pub struct UserDto {
    pub id: Uuid,
    pub email: String,
    pub display_name: String,
    pub avatar_url: Option<String>,
    pub pro_status: bool,
}

pub async fn google_auth(
    State(state): State<AppState>,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    Json(req): Json<GoogleAuthRequest>,
) -> AppResult<Json<AuthResponse>> {
    check_ip_limit(&state.rl_global_ip, addr.ip())?;

    // 1. Verify Google ID token (checks signature via tokeninfo, aud, email_verified)
    let google_payload =
        verify_google_id_token(&state.http, &req.id_token, &state.config.google_client_id)
            .await
            .map_err(|e| match e {
                AppError::Unauthorized(msg) => AppError::Unauthorized(msg),
                _ => AppError::Unauthorized("Invalid Google ID token".to_string()),
            })?;

    // Google tokens without profile scope may omit `name`
    let display_name = google_payload
        .name
        .clone()
        .unwrap_or_else(|| google_payload.email.split('@').next().unwrap_or("User").to_string());

    // 2. Upsert user in DB
    let user = sqlx::query_as::<_, crate::models::User>(
        r#"
        INSERT INTO users (id, google_id, email, display_name, avatar_url)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (google_id) DO UPDATE SET
            email = EXCLUDED.email,
            display_name = EXCLUDED.display_name,
            avatar_url = EXCLUDED.avatar_url,
            updated_at = NOW()
        RETURNING
            id, google_id, email, display_name, avatar_url,
            pro_status, pro_expires_at, is_admin, fcm_token,
            created_at, updated_at
        "#,
    )
    .bind(Uuid::new_v4())
    .bind(google_payload.sub)
    .bind(google_payload.email)
    .bind(display_name)
    .bind(google_payload.picture)
    .fetch_one(&state.db)
    .await?;

    // 3. Issue tokens
    let access_token = issue_access_token(
        user.id,
        &user.email,
        user.pro_status,
        user.is_admin,
        &state.config.jwt_secret,
        state.config.jwt_access_expiry_hours,
    )?;
    let refresh_token = issue_refresh_token(
        user.id,
        &user.email,
        user.pro_status,
        user.is_admin,
        &state.config.jwt_secret,
        state.config.jwt_refresh_expiry_days,
    )?;

    Ok(Json(AuthResponse {
        access_token,
        refresh_token,
        user: UserDto {
            id: user.id,
            email: user.email,
            display_name: user.display_name,
            avatar_url: user.avatar_url,
            pro_status: user.pro_status,
        },
    }))
}

async fn update_fcm_token(
    State(state): State<AppState>,
    user: AuthUser,
    Json(req): Json<FcmTokenRequest>,
) -> AppResult<Json<serde_json::Value>> {
    sqlx::query("UPDATE users SET fcm_token = $1, updated_at = NOW() WHERE id = $2")
        .bind(&req.token)
        .bind(user.id)
        .execute(&state.db)
        .await?;

    Ok(Json(serde_json::json!({ "ok": true })))
}
