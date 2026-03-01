use axum::{Json, extract::State};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{
    AppState,
    auth::{
        google::verify_google_id_token,
        jwt::{issue_access_token, issue_refresh_token},
    },
    error::{AppError, AppResult},
};

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
    Json(req): Json<GoogleAuthRequest>,
) -> AppResult<Json<AuthResponse>> {
    // 1. Verify Google ID token
    let google_payload = verify_google_id_token(&state.http, &req.id_token)
        .await
        .map_err(|_| AppError::Unauthorized("Invalid Google ID token".to_string()))?;

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
    .bind(google_payload.name)
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
