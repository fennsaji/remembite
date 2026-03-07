use axum::{
    Json,
    extract::{Query, State},
    http::StatusCode,
};
use base64::{Engine as _, engine::general_purpose};
use serde::Deserialize;

use crate::{AppState, error::AppError, services::google_play};

#[derive(Deserialize)]
pub struct WebhookQuery {
    pub token: String,
}

#[derive(Deserialize)]
pub struct PubSubMessage {
    pub data: String,
}

#[derive(Deserialize)]
pub struct PubSubPayload {
    pub message: PubSubMessage,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct DeveloperNotification {
    subscription_notification: Option<SubscriptionNotification>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct SubscriptionNotification {
    notification_type: i32,
    purchase_token: String,
    subscription_id: String,
}

const RECOVERED: i32 = 1;
const RENEWED: i32 = 2;
const PURCHASED: i32 = 4;
const GRACE_PERIOD: i32 = 6;
const RESTARTED: i32 = 7;
const EXPIRED: i32 = 13;

pub async fn google_play_webhook(
    State(state): State<AppState>,
    Query(query): Query<WebhookQuery>,
    Json(payload): Json<PubSubPayload>,
) -> Result<StatusCode, AppError> {
    if query.token != state.config.google_pubsub_webhook_token {
        return Err(AppError::Unauthorized("Invalid webhook token".to_string()));
    }

    let decoded = general_purpose::STANDARD
        .decode(&payload.message.data)
        .map_err(|_| AppError::BadRequest("Invalid base64 in Pub/Sub message".to_string()))?;

    let notification: DeveloperNotification = serde_json::from_slice(&decoded)
        .map_err(|_| AppError::BadRequest("Invalid notification JSON".to_string()))?;

    let sub_notif = match notification.subscription_notification {
        Some(n) => n,
        None => return Ok(StatusCode::NO_CONTENT),
    };

    let notification_type = sub_notif.notification_type;

    if matches!(
        notification_type,
        PURCHASED | RENEWED | RECOVERED | GRACE_PERIOD | RESTARTED
    ) {
        let access_token = google_play::get_access_token(
            &state.config.google_play_service_account_json,
            &state.http,
        )
        .await
        .map_err(AppError::Internal)?;

        let expiry_ts = google_play::verify_subscription(
            &state.config.google_play_package_name,
            &sub_notif.subscription_id,
            &sub_notif.purchase_token,
            &access_token,
            &state.http,
        )
        .await
        .map_err(AppError::Internal)?;

        let expires_at = chrono::DateTime::from_timestamp(expiry_ts, 0)
            .ok_or_else(|| AppError::Internal(anyhow::anyhow!("Invalid expiry timestamp")))?;

        sqlx::query(
            r#"
            UPDATE users
            SET pro_status = true,
                pro_expires_at = $1,
                updated_at = NOW()
            WHERE purchase_token = $2
            "#,
        )
        .bind(expires_at)
        .bind(&sub_notif.purchase_token)
        .execute(&state.db)
        .await?;
    } else if notification_type == EXPIRED {
        sqlx::query(
            r#"
            UPDATE users
            SET pro_status = false,
                updated_at = NOW()
            WHERE purchase_token = $1
              AND pro_expires_at < NOW()
            "#,
        )
        .bind(&sub_notif.purchase_token)
        .execute(&state.db)
        .await?;
    }

    Ok(StatusCode::NO_CONTENT)
}

pub fn router() -> axum::Router<AppState> {
    axum::Router::new()
        .route("/google-play", axum::routing::post(google_play_webhook))
}
