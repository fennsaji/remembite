use std::net::SocketAddr;

use axum::{
    Json, Router,
    extract::{ConnectInfo, State},
    http::HeaderMap,
    routing::patch,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{
    AppState,
    auth::{
        google::verify_google_id_token,
        jwt::{TokenKind, issue_access_token, issue_refresh_token_with_jti, verify_token},
        middleware::AuthUser,
        session,
    },
    dto::FcmTokenRequest,
    error::{AppError, AppResult},
    middleware::rate_limit::check_ip_limit,
};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/users/me/fcm-token", patch(update_fcm_token))
        .route("/auth/refresh", axum::routing::post(refresh_tokens))
        .route("/auth/signout", axum::routing::post(signout))
}

/// Best-effort User-Agent capture, so a user can tell their sessions apart.
fn user_agent_of(headers: &HeaderMap) -> Option<String> {
    headers
        .get(axum::http::header::USER_AGENT)
        .and_then(|v| v.to_str().ok())
        .map(|s| s.chars().take(255).collect())
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
    headers: HeaderMap,
    Json(req): Json<RefreshRequest>,
) -> AppResult<Json<RefreshResponse>> {
    let claims = verify_token(&req.refresh_token, &state.config.jwt_secret)?;
    if claims.kind != TokenKind::Refresh {
        return Err(AppError::Unauthorized(
            "Not a refresh token".to_string(),
        ));
    }

    // The token must correspond to a live session row. Tokens issued before
    // this table existed have no row and are rejected — the client falls back
    // to a fresh sign-in.
    let token_hash = session::hash_token(&req.refresh_token);
    let row: Option<(uuid::Uuid, Option<chrono::DateTime<chrono::Utc>>, chrono::DateTime<chrono::Utc>)> =
        sqlx::query_as(
            "SELECT user_id, revoked_at, expires_at FROM refresh_sessions WHERE token_hash = $1",
        )
        .bind(&token_hash)
        .fetch_optional(&state.db)
        .await?;

    let (session_user_id, revoked_at, session_expires_at) = row.ok_or_else(|| {
        AppError::Unauthorized("Refresh token is not recognised".to_string())
    })?;

    match session::classify(revoked_at, session_expires_at, chrono::Utc::now()) {
        session::SessionStatus::Revoked => {
            // A rotation whose response never reached the client leaves that
            // client holding a token we already retired. Inside the grace
            // window treat that as the network blip it almost certainly is:
            // reject this call, but don't sign the account out everywhere.
            if session::is_recent_rotation(revoked_at, chrono::Utc::now()) {
                tracing::info!(
                    user_id = %session_user_id,
                    "revoked refresh token re-presented within grace window — treating as lost-response retry"
                );
                return Err(AppError::Unauthorized(
                    "Refresh token was already rotated — retry with the newest token".to_string(),
                ));
            }
            // Refresh-token reuse: this token was already rotated away or
            // explicitly signed out, yet someone still holds it. We cannot
            // tell the thief from the legitimate user, so we revoke every
            // session for the account and force a fresh sign-in everywhere.
            session::revoke_all_for_user(&state.db, session_user_id).await?;
            tracing::warn!(user_id = %session_user_id, "refresh token reuse detected — all sessions revoked");
            return Err(AppError::Unauthorized(
                "Refresh token reuse detected — please sign in again".to_string(),
            ));
        }
        session::SessionStatus::Expired => {
            return Err(AppError::Unauthorized("Refresh token expired".to_string()));
        }
        session::SessionStatus::Active => {}
    }

    // Re-read current pro/admin state — refresh must reflect revocations/upgrades.
    // Pro is only *reactively* cleared by the Play webhook; if that delivery
    // is missed, pro_status stays true past pro_expires_at. Gate on the
    // expiry here so a lapsed subscription can't keep Pro indefinitely.
    // NULL expiry = manual/lifetime grant, still honoured.
    let row: Option<(bool, bool)> = sqlx::query_as(
        r#"
        SELECT pro_status AND (pro_expires_at IS NULL OR pro_expires_at > NOW()),
               is_admin
        FROM users WHERE id = $1
        "#,
    )
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
    let (refresh_token, _jti, refresh_expires_at) = issue_refresh_token_with_jti(
        claims.sub,
        &claims.email,
        pro_status,
        is_admin,
        &state.config.jwt_secret,
        state.config.jwt_refresh_expiry_days,
    )?;

    // Rotate atomically: the old token dies and the new one is born in one
    // transaction, so a crash can never leave both live (or neither).
    let mut tx = state.db.begin().await?;
    session::revoke_by_hash(&mut tx, &token_hash).await?;
    session::insert_session(
        &mut *tx,
        claims.sub,
        &refresh_token,
        refresh_expires_at,
        user_agent_of(&headers).as_deref(),
    )
    .await?;
    sqlx::query("UPDATE refresh_sessions SET last_used_at = NOW() WHERE token_hash = $1")
        .bind(&token_hash)
        .execute(&mut *tx)
        .await?;
    tx.commit().await?;

    // Opportunistic housekeeping — see prune_expired() for why it lives here.
    // Failure is non-fatal: the user still gets their tokens.
    if let Err(e) = session::prune_expired(&state.db).await {
        tracing::warn!("refresh_sessions prune failed: {e}");
    }

    Ok(Json(RefreshResponse {
        access_token,
        refresh_token,
        pro_status,
    }))
}

#[derive(Deserialize, Default)]
pub struct SignOutRequest {
    /// The refresh token held by this device. Revoked when `all_devices` is
    /// false. Optional: a client that lost it can still sign out locally, and
    /// its access token expires on its own shortly after.
    #[serde(default)]
    pub refresh_token: Option<String>,
    /// True = revoke every session for this user, not just this device.
    #[serde(default)]
    pub all_devices: bool,
}

#[derive(Serialize)]
pub struct SignOutResponse {
    pub revoked: u64,
}

/// Revoke refresh sessions for the caller.
///
/// Authenticated with the (short-lived) access token, so we always know whose
/// sessions these are even when the body omits the refresh token.
async fn signout(
    State(state): State<AppState>,
    user: AuthUser,
    body: Option<Json<SignOutRequest>>,
) -> AppResult<Json<SignOutResponse>> {
    let req = body.map(|Json(b)| b).unwrap_or_default();

    let revoked = if req.all_devices {
        session::revoke_all_for_user(&state.db, user.id).await?
    } else if let Some(token) = req.refresh_token.as_deref() {
        // Scope the revoke to this user's own row so a leaked token belonging
        // to somebody else can't be revoked by an unrelated caller.
        let result = sqlx::query(
            r#"
            UPDATE refresh_sessions SET revoked_at = NOW()
            WHERE token_hash = $1 AND user_id = $2 AND revoked_at IS NULL
            "#,
        )
        .bind(session::hash_token(token))
        .bind(user.id)
        .execute(&state.db)
        .await?;
        result.rows_affected()
    } else {
        // No refresh token supplied and not all-devices: nothing to revoke
        // server-side; the client still clears its local state.
        0
    };

    Ok(Json(SignOutResponse { revoked }))
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
    headers: HeaderMap,
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

    // 3. Issue tokens — same expiry gate as `refresh` (see comment there).
    let pro_status = user.pro_status
        && user
            .pro_expires_at
            .is_none_or(|exp| exp > chrono::Utc::now());
    let access_token = issue_access_token(
        user.id,
        &user.email,
        pro_status,
        user.is_admin,
        &state.config.jwt_secret,
        state.config.jwt_access_expiry_hours,
    )?;
    let (refresh_token, _jti, refresh_expires_at) = issue_refresh_token_with_jti(
        user.id,
        &user.email,
        pro_status,
        user.is_admin,
        &state.config.jwt_secret,
        state.config.jwt_refresh_expiry_days,
    )?;

    // Record the session so this refresh token can later be rotated or revoked.
    session::insert_session(
        &state.db,
        user.id,
        &refresh_token,
        refresh_expires_at,
        user_agent_of(&headers).as_deref(),
    )
    .await?;

    Ok(Json(AuthResponse {
        access_token,
        refresh_token,
        user: UserDto {
            id: user.id,
            email: user.email,
            display_name: user.display_name,
            avatar_url: user.avatar_url,
            pro_status,
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
