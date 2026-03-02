use std::sync::Arc;
use tokio::sync::mpsc;
use tokio::time::{sleep, Duration};

use crate::{llm::LlmProvider as _, jobs::queue::Job, AppState};

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
        Job::ParseMenuOcr { raw_text: _, restaurant_id, user_id } => {
            // OCR parsing result is returned to the client via a separate endpoint.
            // This job is fire-and-forget; results stored in a temporary table or returned via FCM.
            tracing::info!("OCR parse job received for restaurant {restaurant_id} by user {user_id}");
            Ok(())
        }
    }
}

async fn classify_dish_with_retry(
    dish_id: uuid::Uuid,
    dish_name: &str,
    cuisine: &str,
    state: &AppState,
) -> anyhow::Result<()> {
    let max_retries = 3u32;
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
                return Ok(());
            }
            Err(e) if attempt < max_retries => {
                let backoff = Duration::from_secs(4u64.pow(attempt - 1)); // 1s, 4s, 16s
                tracing::warn!("Dish {dish_id} classification attempt {attempt} failed: {e}. Retrying in {backoff:?}");
                sleep(backoff).await;
            }
            Err(e) => {
                tracing::error!("Dish {dish_id} classification failed after {max_retries} attempts: {e}");
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
