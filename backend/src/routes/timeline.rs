use axum::{Json, Router, extract::State, routing::{get, post}};
use std::collections::BTreeMap;

use crate::{
    AppState,
    auth::middleware::AuthUser,
    dto::{BootstrapRequest, BootstrapResponse, DishReactionItem, TasteInsightsResponse, TasteProfileStatusResponse, TimelineEntry, TimelineResponse},
    error::AppResult,
};

/// Minimum reactions to classified dishes required before predictions are shown.
/// Must match CLAUDE.md architecture spec. Also referenced in dishes.rs::get_compatibility.
const TASTE_PROFILE_THRESHOLD: i32 = 10;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/timeline", get(get_timeline))
        .route("/taste-insights", get(get_taste_insights))
        .route("/taste-profile-status", get(get_taste_profile_status))
        .route("/bootstrap", post(post_bootstrap))
}

async fn get_timeline(
    State(state): State<AppState>,
    user: AuthUser,
) -> AppResult<Json<TimelineResponse>> {
    let rows = sqlx::query(
        r#"
        SELECT
            dr.dish_id,
            d.name as dish_name,
            dr.reaction::text as reaction,
            dr.updated_at as reacted_at,
            r.id as restaurant_id,
            r.name as restaurant_name,
            DATE(dr.updated_at AT TIME ZONE 'UTC') as visit_date
        FROM dish_reactions dr
        JOIN dishes d ON d.id = dr.dish_id
        JOIN restaurants r ON r.id = d.restaurant_id
        WHERE dr.user_id = $1
        ORDER BY dr.updated_at DESC
        LIMIT 200
        "#,
    )
    .bind(user.id)
    .fetch_all(&state.db)
    .await?;

    use sqlx::Row;

    // Group by (visit_date, restaurant_id). Date must sort before restaurant_id
    // in the key tuple — BTreeMap orders lexicographically by the first field,
    // so keying on (restaurant_id, date) sorted entries by restaurant UUID
    // first and shuffled the timeline by date.
    let mut groups: BTreeMap<(String, String), (uuid::Uuid, String, Vec<DishReactionItem>)> =
        BTreeMap::new();

    for row in rows {
        let restaurant_id: uuid::Uuid = row.try_get("restaurant_id")?;
        let restaurant_name: String = row.try_get("restaurant_name")?;
        let visit_date: chrono::NaiveDate = row.try_get("visit_date")?;
        let date_str = visit_date.format("%Y-%m-%d").to_string();

        let key = (date_str.clone(), restaurant_id.to_string());
        let entry = groups
            .entry(key)
            .or_insert_with(|| (restaurant_id, restaurant_name.clone(), vec![]));

        entry.2.push(DishReactionItem {
            dish_id: row.try_get("dish_id")?,
            dish_name: row.try_get("dish_name")?,
            reaction: row.try_get("reaction")?,
            reacted_at: row.try_get("reacted_at")?,
        });
    }

    // Newest first by (date, restaurant_id) — BTreeMap is ascending, so reverse.
    let entries: Vec<TimelineEntry> = groups
        .into_iter()
        .rev()
        .map(|((date, _), (restaurant_id, restaurant_name, reactions))| TimelineEntry {
            restaurant_id,
            restaurant_name,
            date,
            reactions,
        })
        .collect();

    Ok(Json(TimelineResponse { entries }))
}

async fn get_taste_insights(
    State(state): State<AppState>,
    user: AuthUser,
) -> AppResult<Json<TasteInsightsResponse>> {
    user.require_pro()?;

    use sqlx::Row;

    let row = sqlx::query(
        r#"SELECT spice_preference, sweetness_preference, cuisine_distribution,
                  dish_type_distribution, reaction_count
           FROM user_taste_vectors WHERE user_id = $1"#,
    )
    .bind(user.id)
    .fetch_optional(&state.db)
    .await?;

    let (spice_pref, sweet_pref, cuisine_dist, dish_type_dist, reaction_count) = match row {
        Some(ref r) => {
            let spice: f64 = r.try_get("spice_preference")?;
            let sweet: f64 = r.try_get("sweetness_preference")?;
            let cuisine: serde_json::Value = r.try_get("cuisine_distribution")?;
            let dish_type: serde_json::Value = r.try_get("dish_type_distribution")?;
            let count: i32 = r.try_get("reaction_count")?;
            (spice, sweet, cuisine, dish_type, count)
        }
        None => {
            return Ok(Json(TasteInsightsResponse {
                ready: false,
                reaction_count: 0,
                insights: vec![],
            }));
        }
    };

    if reaction_count < TASTE_PROFILE_THRESHOLD {
        return Ok(Json(TasteInsightsResponse {
            ready: false,
            reaction_count,
            insights: vec![],
        }));
    }

    let mut insights: Vec<String> = Vec::new();

    // Spice insights
    if spice_pref > 0.65 {
        insights.push("You prefer spicy food".to_string());
    } else if spice_pref < 0.35 {
        insights.push("You tend to dislike spicy food".to_string());
    }

    // Sweetness insights
    if sweet_pref > 0.65 {
        insights.push("You enjoy sweet dishes".to_string());
    } else if sweet_pref < 0.35 {
        insights.push("You tend to dislike sweet dishes".to_string());
    }

    // Cuisine distribution insight
    if let Some(obj) = cuisine_dist.as_object() {
        let best = obj
            .iter()
            .filter_map(|(k, v)| v.as_f64().map(|f| (k.clone(), f)))
            .filter(|(_, f)| *f > 0.3)
            .max_by(|a, b| a.1.partial_cmp(&b.1).unwrap_or(std::cmp::Ordering::Equal));
        if let Some((cuisine, _)) = best {
            insights.push(format!("You love {} cuisine", cuisine));
        }
    }

    // Dish type distribution insight
    if let Some(obj) = dish_type_dist.as_object() {
        let best = obj
            .iter()
            .filter_map(|(k, v)| v.as_f64().map(|f| (k.clone(), f)))
            .filter(|(_, f)| *f > 0.3)
            .max_by(|a, b| a.1.partial_cmp(&b.1).unwrap_or(std::cmp::Ordering::Equal));
        if let Some((dish_type, _)) = best {
            insights.push(format!("You frequently enjoy {}", dish_type));
        }
    }

    insights.truncate(3);

    Ok(Json(TasteInsightsResponse {
        ready: true,
        reaction_count,
        insights,
    }))
}

/// No Pro gate — intentionally accessible to free users.
/// Powers the "Taste Profile Completion" progress bar on the Profile screen (free teaser).
/// The `insights_locked` field tells the client whether to show the upgrade CTA.
async fn get_taste_profile_status(
    State(state): State<AppState>,
    user: AuthUser,
) -> AppResult<Json<TasteProfileStatusResponse>> {
    use sqlx::Row;

    let row = sqlx::query(
        "SELECT reaction_count FROM user_taste_vectors WHERE user_id = $1",
    )
    .bind(user.id)
    .fetch_optional(&state.db)
    .await?;

    let reaction_count: i32 = match row {
        Some(ref r) => r.try_get("reaction_count")?,
        None => 0,
    };

    let threshold = TASTE_PROFILE_THRESHOLD;
    let progress = (reaction_count as f64 / threshold as f64).min(1.0);
    let complete = reaction_count >= threshold;
    let insights_locked = !user.pro;

    Ok(Json(TasteProfileStatusResponse {
        reaction_count,
        threshold,
        progress,
        complete,
        insights_locked,
    }))
}

/// Onboarding presents 10-15 dishes (CLAUDE.md taste bootstrapping spec) —
/// reject anything larger so a crafted request can't fabricate an arbitrary
/// number of reactions and blow past the ≥10-reaction confidence gate.
const MAX_BOOTSTRAP_REACTIONS: usize = 15;

async fn post_bootstrap(
    State(state): State<AppState>,
    user: AuthUser,
    Json(req): Json<BootstrapRequest>,
) -> AppResult<Json<BootstrapResponse>> {
    use sqlx::Row;

    if req.reactions.len() > MAX_BOOTSTRAP_REACTIONS {
        return Err(crate::error::AppError::BadRequest(format!(
            "at most {MAX_BOOTSTRAP_REACTIONS} bootstrap reactions allowed"
        )));
    }
    for item in &req.reactions {
        if !(0.0..=1.0).contains(&item.spice_score) || !(0.0..=1.0).contains(&item.sweetness_score) {
            return Err(crate::error::AppError::BadRequest(
                "spice_score and sweetness_score must be between 0.0 and 1.0".to_string(),
            ));
        }
    }

    // Idempotency — if already bootstrapped, no-op
    let row = sqlx::query("SELECT bootstrapped_at FROM users WHERE id = $1")
        .bind(user.id)
        .fetch_one(&state.db)
        .await?;
    let already_done: Option<chrono::DateTime<chrono::Utc>> = row.try_get("bootstrapped_at")?;
    if already_done.is_some() {
        return Ok(Json(BootstrapResponse { ok: true }));
    }

    // Ensure taste vector row exists
    sqlx::query(
        "INSERT INTO user_taste_vectors (id, user_id) VALUES ($1, $2) ON CONFLICT (user_id) DO NOTHING",
    )
    .bind(uuid::Uuid::new_v4())
    .bind(user.id)
    .execute(&state.db)
    .await?;

    // Apply each reaction to the taste vector
    for item in &req.reactions {
        // Skip non-positive reactions (meh provides no directional signal)
        let reaction_signal: f64 = match item.reaction.as_str() {
            "so_yummy" => 1.0,
            "tasty"    => 0.75,
            _          => continue,
        };

        sqlx::query(
            r#"
            UPDATE user_taste_vectors SET
                spice_preference    = spice_preference    + 0.1 * ($1 - spice_preference),
                sweetness_preference = sweetness_preference + 0.1 * ($2 - sweetness_preference),
                cuisine_distribution = jsonb_set(
                    cuisine_distribution,
                    ARRAY[$5::text],
                    to_jsonb(
                        COALESCE((cuisine_distribution ->> $5::text)::float, 0.0)
                        + 0.1 * ($3 - COALESCE((cuisine_distribution ->> $5::text)::float, 0.0))
                    )
                ),
                dish_type_distribution = jsonb_set(
                    dish_type_distribution,
                    ARRAY[$6::text],
                    to_jsonb(
                        COALESCE((dish_type_distribution ->> $6::text)::float, 0.0)
                        + 0.1 * ($4 - COALESCE((dish_type_distribution ->> $6::text)::float, 0.0))
                    )
                ),
                reaction_count = reaction_count + 1,
                updated_at = NOW()
            WHERE user_id = $7
            "#,
        )
        .bind(item.spice_score)
        .bind(item.sweetness_score)
        .bind(reaction_signal)
        .bind(reaction_signal)
        .bind(&item.cuisine)
        .bind(&item.dish_type)
        .bind(user.id)
        .execute(&state.db)
        .await?;
    }

    // Mark bootstrapped
    sqlx::query("UPDATE users SET bootstrapped_at = NOW() WHERE id = $1")
        .bind(user.id)
        .execute(&state.db)
        .await?;

    Ok(Json(BootstrapResponse { ok: true }))
}
