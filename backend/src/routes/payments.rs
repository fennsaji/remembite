use axum::{Json, extract::State};
use chrono::DateTime;
use serde::{Deserialize, Serialize};

use crate::{
    AppState,
    auth::{
        jwt::{issue_access_token, issue_refresh_token},
        middleware::AuthUser,
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
        let msg = e.to_string();
        if msg.contains("not active") || msg.contains("no expiry") {
            AppError::BadRequest("Invalid or expired purchase token".to_string())
        } else {
            AppError::Internal(e)
        }
    })?;

    let expires_at = DateTime::from_timestamp(expiry_ts, 0)
        .ok_or_else(|| AppError::Internal(anyhow::anyhow!("Invalid expiry timestamp")))?;

    // Update user pro status and store purchase_token for webhook lookups
    sqlx::query(
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
    .await?;

    // Re-issue tokens reflecting pro=true
    let new_access = issue_access_token(
        auth.id,
        &auth.email,
        true,
        auth.admin,
        &state.config.jwt_secret,
        state.config.jwt_access_expiry_hours,
    )?;

    let new_refresh = issue_refresh_token(
        auth.id,
        &auth.email,
        true,
        auth.admin,
        &state.config.jwt_secret,
        state.config.jwt_refresh_expiry_days,
    )?;

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
