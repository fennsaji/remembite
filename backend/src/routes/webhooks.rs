use axum::{
    Json,
    extract::{Query, State},
    http::StatusCode,
};
use base64::{Engine as _, engine::general_purpose};
use serde::Deserialize;
use subtle::ConstantTimeEq;

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
    /// Milliseconds since epoch, set by Google on the decoded RTDN envelope.
    /// Optional: it is documented but we must not 400 (and trigger endless
    /// Pub/Sub retries) if a payload ever lacks it. Arrives as a JSON string
    /// in Google's payload, hence the deserialize helper.
    #[serde(default, deserialize_with = "deserialize_opt_i64")]
    event_time_millis: Option<i64>,
}

/// `eventTimeMillis` is a *string* of digits in Google's payload, but tolerate
/// a bare number too. Anything unparseable degrades to `None` (apply as
/// before) rather than failing the whole webhook.
fn deserialize_opt_i64<'de, D>(d: D) -> Result<Option<i64>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    use serde::Deserialize as _;
    Ok(match serde_json::Value::deserialize(d)? {
        serde_json::Value::String(s) => s.parse::<i64>().ok(),
        serde_json::Value::Number(n) => n.as_i64(),
        _ => None,
    })
}

/// Should a notification stamped `event_time_millis` be applied, given the
/// `last_notification_at` already recorded for the user?
///
/// Used for logging/short-circuiting only — the authoritative check is the
/// same comparison inlined in the UPDATE's WHERE clause, so a concurrent
/// delivery cannot slip between a read and a write.
#[allow(dead_code)] // mirrors the SQL predicate; exercised by the unit tests
pub fn should_apply(event_time_millis: Option<i64>, last_applied_millis: Option<i64>) -> bool {
    match (event_time_millis, last_applied_millis) {
        // No timestamp on the notification — behave exactly as before.
        (None, _) => true,
        // Nothing applied yet.
        (Some(_), None) => true,
        // Strictly newer wins; equal timestamps are treated as a duplicate
        // redelivery of an already-applied notification and skipped.
        (Some(event), Some(last)) => event > last,
    }
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
// CANCELED (3) is intentionally unhandled — the user keeps access until the
// subscription actually lapses (EXPIRED) or Google revokes it (REVOKED).
const PURCHASED: i32 = 4;
const ON_HOLD: i32 = 5;
const GRACE_PERIOD: i32 = 6;
const RESTARTED: i32 = 7;
const PAUSED: i32 = 10;
const REVOKED: i32 = 12;
const EXPIRED: i32 = 13;

pub async fn google_play_webhook(
    State(state): State<AppState>,
    Query(query): Query<WebhookQuery>,
    Json(payload): Json<PubSubPayload>,
) -> Result<StatusCode, AppError> {
    // Constant-time compare so timing can't leak the token byte-by-byte.
    // `ct_eq` on slices of unequal length short-circuits to false, which is
    // fine — the token length is not secret.
    let token_ok: bool = query
        .token
        .as_bytes()
        .ct_eq(state.config.google_pubsub_webhook_token.as_bytes())
        .into();
    if !token_ok {
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

    // Out-of-order guard. `event_at` is NULL when Google sent no
    // eventTimeMillis; the SQL below then leaves the ordering check inert and
    // the notification applies as it always did.
    let event_at = notification.event_time_millis.and_then(|ms| {
        let dt = chrono::DateTime::from_timestamp_millis(ms);
        if dt.is_none() {
            tracing::warn!(event_time_millis = ms, "webhook: uninterpretable eventTimeMillis");
        }
        dt
    });
    if event_at.is_none() {
        tracing::info!(
            purchase_token = %sub_notif.purchase_token,
            "webhook: no usable eventTimeMillis — applying without ordering guard"
        );
    }

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

        let expiry_ts = match google_play::verify_subscription(
            &state.config.google_play_package_name,
            &sub_notif.subscription_id,
            &sub_notif.purchase_token,
            &access_token,
            &state.http,
        )
        .await
        {
            Ok(ts) => ts,
            Err(e) if e.to_string().contains("invalid purchase token") => {
                // Permanently bad token (never valid, or already consumed) —
                // acking without retry avoids Pub/Sub redelivering forever.
                tracing::warn!("webhook: invalid purchase token, skipping: {e}");
                return Ok(StatusCode::NO_CONTENT);
            }
            Err(e) => return Err(AppError::Internal(e)), // transient — let Pub/Sub retry
        };

        let expires_at = chrono::DateTime::from_timestamp(expiry_ts, 0)
            .ok_or_else(|| AppError::Internal(anyhow::anyhow!("Invalid expiry timestamp")))?;

        // The ordering compare-and-set lives in the WHERE clause, not in a
        // separate SELECT, so two deliveries racing each other can't both
        // read the same stale last_notification_at and both apply.
        let grant = sqlx::query(
            r#"
            UPDATE users
            SET pro_status = true,
                pro_expires_at = $1,
                last_notification_at = COALESCE($3::timestamptz, last_notification_at),
                updated_at = NOW()
            WHERE purchase_token = $2
              AND ($3::timestamptz IS NULL
                   OR last_notification_at IS NULL
                   OR last_notification_at < $3)
            "#,
        )
        .bind(expires_at)
        .bind(&sub_notif.purchase_token)
        .bind(event_at)
        .execute(&state.db)
        .await?;

        // purchase_token is only written by /payments/verify. A grant that
        // arrives before the client's verify round-trip matches no row and
        // would otherwise vanish silently, leaving a paying user without Pro.
        // A stale/duplicate notification also matches no row — distinguish
        // the two for the log only (204 either way, so Pub/Sub stops).
        if grant.rows_affected() == 0 {
            log_no_rows(&state, &sub_notif.purchase_token, "grant").await;
        }
    } else if matches!(notification_type, EXPIRED | REVOKED | ON_HOLD | PAUSED) {
        // Trust Google's notification directly — no local expiry-timestamp gate.
        // The old `AND pro_expires_at < NOW()` gate meant a single delivery
        // (Pub/Sub does not redeliver on our 204 ack) could silently no-op if
        // our stored expiry lagged Google's clock, or if pro_expires_at was
        // NULL (`NULL < NOW()` is NULL, so the row never matched).
        // Same race-safe compare-and-set as the grant path. The revoke still
        // has no local expiry gate — only the ordering guard is added.
        let revoke = sqlx::query(
            r#"
            UPDATE users
            SET pro_status = false,
                last_notification_at = COALESCE($2::timestamptz, last_notification_at),
                updated_at = NOW()
            WHERE purchase_token = $1
              AND ($2::timestamptz IS NULL
                   OR last_notification_at IS NULL
                   OR last_notification_at < $2)
            "#,
        )
        .bind(&sub_notif.purchase_token)
        .bind(event_at)
        .execute(&state.db)
        .await?;

        if revoke.rows_affected() == 0 {
            log_no_rows(&state, &sub_notif.purchase_token, "revoke").await;
        }
    }

    Ok(StatusCode::NO_CONTENT)
}

/// Explain a zero-row UPDATE: either the ordering guard dropped a stale or
/// duplicate notification, or no user holds this purchase_token yet.
async fn log_no_rows(state: &AppState, purchase_token: &str, op: &str) {
    let exists = sqlx::query_scalar::<_, i64>(
        "SELECT 1 FROM users WHERE purchase_token = $1 LIMIT 1",
    )
    .bind(purchase_token)
    .fetch_optional(&state.db)
    .await
    .ok()
    .flatten()
    .is_some();

    if exists {
        tracing::info!(
            purchase_token = %purchase_token,
            op,
            "webhook: skipped out-of-order or duplicate notification"
        );
    } else {
        tracing::warn!(
            purchase_token = %purchase_token,
            op,
            "webhook: matched no user — client has not called /payments/verify yet"
        );
    }
}

pub fn router() -> axum::Router<AppState> {
    axum::Router::new()
        .route("/google-play", axum::routing::post(google_play_webhook))
}

#[cfg(test)]
mod tests {
    use super::{DeveloperNotification, should_apply};

    // ── Ordering comparison ───────────────────────────────────────────────

    #[test]
    fn missing_event_time_applies_as_before() {
        assert!(should_apply(None, None));
        assert!(should_apply(None, Some(9_999)));
    }

    #[test]
    fn first_notification_for_user_applies() {
        assert!(should_apply(Some(1_000), None));
    }

    #[test]
    fn newer_notification_applies() {
        assert!(should_apply(Some(2_000), Some(1_000)));
    }

    #[test]
    fn older_notification_is_skipped() {
        // The bug this guards: a delayed EXPIRED landing after a RENEWED.
        assert!(!should_apply(Some(1_000), Some(2_000)));
    }

    #[test]
    fn duplicate_redelivery_is_skipped() {
        assert!(!should_apply(Some(1_000), Some(1_000)));
    }

    // ── Payload parsing ───────────────────────────────────────────────────

    #[test]
    fn parses_event_time_millis_as_string() {
        let n: DeveloperNotification = serde_json::from_str(
            r#"{"version":"1.0","packageName":"x","eventTimeMillis":"1700000000000",
                "subscriptionNotification":{"version":"1.0","notificationType":2,
                "purchaseToken":"tok","subscriptionId":"sub"}}"#,
        )
        .unwrap();
        assert_eq!(n.event_time_millis, Some(1_700_000_000_000));
    }

    #[test]
    fn parses_event_time_millis_as_number() {
        let n: DeveloperNotification =
            serde_json::from_str(r#"{"eventTimeMillis":1700000000000}"#).unwrap();
        assert_eq!(n.event_time_millis, Some(1_700_000_000_000));
    }

    #[test]
    fn absent_event_time_millis_parses_to_none() {
        let n: DeveloperNotification = serde_json::from_str(
            r#"{"subscriptionNotification":{"notificationType":13,
                "purchaseToken":"tok","subscriptionId":"sub"}}"#,
        )
        .unwrap();
        assert!(n.event_time_millis.is_none());
        assert!(n.subscription_notification.is_some());
    }

    #[test]
    fn garbage_event_time_millis_degrades_to_none() {
        let n: DeveloperNotification =
            serde_json::from_str(r#"{"eventTimeMillis":"not-a-number"}"#).unwrap();
        assert!(n.event_time_millis.is_none());
    }
}
