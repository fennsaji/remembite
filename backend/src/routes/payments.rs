use axum::{Json, extract::State, http::HeaderMap};
use chrono::DateTime;
use serde::{Deserialize, Serialize};

use crate::{
    AppState,
    auth::{
        jwt::{issue_access_token, issue_refresh_token_with_jti},
        middleware::AuthUser,
        session,
    },
    error::{AppError, AppResult},
    services::google_play,
};

#[derive(Deserialize)]
pub struct VerifyRequest {
    pub purchase_token: String,
    pub product_id: String,
}

#[derive(Serialize)]
pub struct VerifyResponse {
    pub access_token: String,
    pub refresh_token: String,
    pub pro_status: bool,
    pub pro_expires_at: Option<String>,
}

pub async fn verify_purchase(
    State(state): State<AppState>,
    auth: AuthUser,
    headers: HeaderMap,
    Json(req): Json<VerifyRequest>,
) -> AppResult<Json<VerifyResponse>> {
    let gp_access_token = google_play::get_access_token(
        &state.config.google_play_service_account_json,
        &state.http,
    )
    .await
    .map_err(AppError::Internal)?;

    let expiry_ts = google_play::verify_subscription(
        &state.config.google_play_package_name,
        &req.product_id,
        &req.purchase_token,
        &gp_access_token,
        &state.http,
    )
    .await
    .map_err(|e| {
        if e.to_string().contains("invalid purchase token") {
            AppError::BadRequest("Invalid or expired purchase token".to_string())
        } else {
            AppError::Internal(e)
        }
    })?;

    let expires_at = DateTime::from_timestamp(expiry_ts, 0)
        .ok_or_else(|| AppError::Internal(anyhow::anyhow!("Invalid expiry timestamp")))?;

    // Atomic claim: a unique partial index on purchase_token (migration 0011)
    // makes a concurrent double-redemption fail this UPDATE with a unique
    // violation instead of racing a separate SELECT-then-UPDATE check.
    let update_result = sqlx::query(
        r#"
        UPDATE users
        SET pro_status = true,
            pro_expires_at = $1,
            purchase_token = $2,
            updated_at = NOW()
        WHERE id = $3
        "#,
    )
    .bind(expires_at)
    .bind(&req.purchase_token)
    .bind(auth.id)
    .execute(&state.db)
    .await;

    if let Err(sqlx::Error::Database(db_err)) = &update_result {
        if db_err.is_unique_violation() {
            return Err(AppError::Conflict(
                "Purchase token already redeemed by another account".to_string(),
            ));
        }
    }
    update_result?;

    // Re-issue tokens reflecting pro=true
    let new_access = issue_access_token(
        auth.id,
        &auth.email,
        true,
        auth.admin,
        &state.config.jwt_secret,
        state.config.jwt_access_expiry_hours,
    )?;

    // Refresh tokens are only accepted by /auth/refresh if a matching
    // refresh_sessions row exists, so this re-issued token must be recorded
    // too — otherwise upgrading to Pro would hand the client a token that
    // fails on its next refresh.
    let (new_refresh, _jti, refresh_expires_at) = issue_refresh_token_with_jti(
        auth.id,
        &auth.email,
        true,
        auth.admin,
        &state.config.jwt_secret,
        state.config.jwt_refresh_expiry_days,
    )?;
    let user_agent = headers
        .get(axum::http::header::USER_AGENT)
        .and_then(|v| v.to_str().ok());
    session::insert_session(
        &state.db,
        auth.id,
        &new_refresh,
        refresh_expires_at,
        user_agent,
    )
    .await?;

    Ok(Json(VerifyResponse {
        access_token: new_access,
        refresh_token: new_refresh,
        pro_status: true,
        pro_expires_at: Some(expires_at.to_rfc3339()),
    }))
}

pub fn router() -> axum::Router<AppState> {
    axum::Router::new()
        .route("/verify", axum::routing::post(verify_purchase))
}
