use std::sync::Arc;
use tokio::sync::mpsc;
use tokio::time::{sleep, Duration};

use crate::{jobs::queue::Job, AppState};

/// Background worker — drains the job queue and processes jobs.
/// Runs as a separate Tokio task spawned at startup.
pub async fn run_worker(mut receiver: mpsc::Receiver<Job>, state: Arc<AppState>) {
    tracing::info!("Job worker started");

    while let Some(job) = receiver.recv().await {
        let state = state.clone();
        tokio::spawn(async move {
            if let Err(e) = process_job(job, state).await {
                tracing::error!("Job processing error: {e:#}");
            }
        });
    }

    tracing::warn!("Job worker shutting down — channel closed");
}

async fn process_job(job: Job, state: Arc<AppState>) -> anyhow::Result<()> {
    match job {
        Job::ClassifyDish { dish_id, dish_name, cuisine } => {
            classify_dish_with_retry(dish_id, &dish_name, &cuisine, &state).await
        }
        Job::ParseMenuOcr { raw_text, restaurant_id, user_id } => {
            match state.llm.parse_menu_ocr(&raw_text).await {
                Ok(dishes) => {
                    tracing::info!(
                        restaurant_id = %restaurant_id,
                        user_id = %user_id,
                        dish_count = dishes.len(),
                        "OCR parse job completed"
                    );
                    // TODO: In a future phase, persist parsed dishes to a staging table
                    // and notify the user via FCM, so they can confirm before dishes enter the DB.
                    // For now, POST /ocr/parse (synchronous endpoint) handles the OCR flow for Phase 4.
                    Ok(())
                }
                Err(e) => {
                    // OCR parse failures are non-fatal — log and continue
                    tracing::error!(
                        restaurant_id = %restaurant_id,
                        "OCR parse job failed: {e}"
                    );
                    Ok(())
                }
            }
        }
    }
}

async fn classify_dish_with_retry(
    dish_id: uuid::Uuid,
    dish_name: &str,
    cuisine: &str,
    state: &AppState,
) -> anyhow::Result<()> {
    let max_attempts = 3u32;
    let mut attempt = 0u32;

    loop {
        attempt += 1;
        match state.llm.classify_dish(dish_name, cuisine).await {
            Ok(attrs) => {
                // Store priors in DB
                sqlx::query(
                    r#"
                    INSERT INTO dish_attribute_priors
                        (id, dish_id, spice_score, sweetness_score, dish_type, cuisine, confidence)
                    VALUES ($1, $2, $3, $4, $5, $6, $7)
                    ON CONFLICT (dish_id) DO UPDATE SET
                        spice_score = EXCLUDED.spice_score,
                        sweetness_score = EXCLUDED.sweetness_score,
                        dish_type = EXCLUDED.dish_type,
                        cuisine = EXCLUDED.cuisine,
                        confidence = EXCLUDED.confidence
                    "#,
                )
                .bind(uuid::Uuid::new_v4())
                .bind(dish_id)
                .bind(attrs.spice_score as f64)
                .bind(attrs.sweetness_score as f64)
                .bind(attrs.dish_type)
                .bind(attrs.cuisine)
                .bind(attrs.confidence as f64)
                .execute(&state.db)
                .await?;

                // Update dish attribute_state to classified
                sqlx::query(
                    "UPDATE dishes SET attribute_state = 'classified', updated_at = NOW() WHERE id = $1",
                )
                .bind(dish_id)
                .execute(&state.db)
                .await?;

                tracing::info!("Dish {dish_id} classified successfully");
                // Send FCM push notification to dish creator
                send_classification_fcm(dish_id, dish_name, state).await;
                return Ok(());
            }
            Err(e) if attempt < max_attempts => {
                let backoff = Duration::from_secs(4u64.pow(attempt - 1)); // delays: 1s, 4s (2 retries after first failure)
                tracing::warn!("Dish {dish_id} classification attempt {attempt} failed: {e}. Retrying in {backoff:?}");
                sleep(backoff).await;
            }
            Err(e) => {
                tracing::error!("Dish {dish_id} classification failed after {max_attempts} attempts: {e}");
                sqlx::query(
                    "UPDATE dishes SET attribute_state = 'failed', updated_at = NOW() WHERE id = $1",
                )
                .bind(dish_id)
                .execute(&state.db)
                .await?;
                return Err(e.into());
            }
        }
    }
}

async fn send_classification_fcm(
    dish_id: uuid::Uuid,
    dish_name: &str,
    state: &AppState,
) {
    if state.config.fcm_service_account_json.is_empty() || state.config.fcm_project_id.is_empty() {
        return;
    }

    // Fetch dish creator's FCM token
    let result = sqlx::query(
        r#"SELECT u.fcm_token FROM dishes d
           JOIN users u ON u.id = d.created_by
           WHERE d.id = $1"#,
    )
    .bind(dish_id)
    .fetch_optional(&state.db)
    .await;

    let fcm_token = match result {
        Ok(Some(row)) => {
            use sqlx::Row;
            let token: Option<String> = row.try_get("fcm_token").unwrap_or(None);
            match token {
                Some(t) if !t.is_empty() => t,
                _ => return,
            }
        }
        _ => return,
    };

    // Get OAuth2 access token via service account JWT
    let access_token = match get_fcm_access_token(&state.config, &state.http).await {
        Ok(t) => t,
        Err(e) => {
            tracing::warn!(dish_id = %dish_id, "FCM auth token error: {e}");
            return;
        }
    };

    // Send FCM v1 message
    let url = format!(
        "https://fcm.googleapis.com/v1/projects/{}/messages:send",
        state.config.fcm_project_id
    );
    let payload = serde_json::json!({
        "message": {
            "token": fcm_token,
            "data": {
                "type": "classification_complete",
                "dish_id": dish_id.to_string(),
                "dish_name": dish_name,
            }
        }
    });

    match state
        .http
        .post(&url)
        .bearer_auth(&access_token)
        .json(&payload)
        .send()
        .await
    {
        Ok(resp) if resp.status().is_success() => {
            tracing::info!(dish_id = %dish_id, "FCM v1 notification sent");
        }
        Ok(resp) => {
            let status = resp.status();
            let body = resp.text().await.unwrap_or_default();
            tracing::warn!(dish_id = %dish_id, %status, "FCM v1 notification failed: {body}");
        }
        Err(e) => {
            tracing::warn!(dish_id = %dish_id, "FCM v1 request error: {e}");
        }
    }
}

async fn get_fcm_access_token(
    config: &crate::config::Config,
    http: &reqwest::Client,
) -> anyhow::Result<String> {
    use jsonwebtoken::{Algorithm, EncodingKey, Header, encode};
    use serde::Serialize;

    // Parse service account JSON
    #[derive(serde::Deserialize)]
    struct ServiceAccount {
        client_email: String,
        private_key: String,
    }
    let sa: ServiceAccount = serde_json::from_str(&config.fcm_service_account_json)
        .map_err(|e| anyhow::anyhow!("Invalid FCM service account JSON: {e}"))?;

    // Build JWT claims for service account auth
    #[derive(Serialize)]
    struct Claims {
        iss: String,
        sub: String,
        aud: String,
        scope: String,
        iat: u64,
        exp: u64,
    }
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();

    let claims = Claims {
        iss: sa.client_email.clone(),
        sub: sa.client_email,
        aud: "https://oauth2.googleapis.com/token".to_string(),
        scope: "https://www.googleapis.com/auth/firebase.messaging".to_string(),
        iat: now,
        exp: now + 3600,
    };

    let key = EncodingKey::from_rsa_pem(sa.private_key.as_bytes())
        .map_err(|e| anyhow::anyhow!("Invalid FCM private key: {e}"))?;
    let header = Header::new(Algorithm::RS256);
    let jwt = encode(&header, &claims, &key)
        .map_err(|e| anyhow::anyhow!("Failed to sign FCM JWT: {e}"))?;

    // Exchange JWT for OAuth2 access token
    #[derive(serde::Deserialize)]
    struct TokenResponse {
        access_token: String,
    }
    let token_resp = http
        .post("https://oauth2.googleapis.com/token")
        .form(&[
            ("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer"),
            ("assertion", &jwt),
        ])
        .send()
        .await
        .map_err(|e| anyhow::anyhow!("OAuth2 token request failed: {e}"))?
        .json::<TokenResponse>()
        .await
        .map_err(|e| anyhow::anyhow!("OAuth2 token response parse failed: {e}"))?;

    Ok(token_resp.access_token)
}
