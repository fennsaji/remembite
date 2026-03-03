use axum::{
    Json, Router,
    extract::{Path, State},
    http::StatusCode,
    routing::{get, post},
};
use uuid::Uuid;

use crate::{
    AppState,
    auth::middleware::AuthUser,
    dto::{
        AttributeVoteRequest, CompatibilityResponse, DishAttributesResponse,
        DishBatchCreateRequest, DishDetailResponse, DishResponse, ReactionSummaryResponse,
        ReactionUpsertRequest,
    },
    error::{AppError, AppResult},
    jobs::queue::Job,
    middleware::rate_limit::check_user_limit,
};

/// Admin-only routes mounted at /admin
pub fn admin_router() -> Router<AppState> {
    Router::new()
        .route("/recompute-taste-vectors", post(admin_recompute_taste_vectors))
}

/// Routes mounted at /restaurants/:id/dishes
pub fn restaurant_dishes_router() -> Router<AppState> {
    Router::new()
        .route("/", get(list_dishes).post(batch_create_dishes))
}

/// Routes mounted at /dishes
pub fn dishes_router() -> Router<AppState> {
    Router::new()
        .route("/:id", get(get_dish))
        .route("/:id/reactions", post(upsert_reaction).get(reaction_summary))
        .route("/:id/attribute_votes", post(upsert_attribute_vote))
        .route("/:id/favorites", post(toggle_favorite))
        .route("/:id/attributes", get(get_dish_attributes))
        .route("/:id/compatibility", get(get_compatibility))
}

async fn list_dishes(
    State(state): State<AppState>,
    Path(restaurant_id): Path<Uuid>,
) -> AppResult<Json<Vec<DishResponse>>> {
    let rows = sqlx::query(
        r#"
        SELECT id, restaurant_id, name, category, price, attribute_state::text,
               community_score, vote_count, created_at
        FROM dishes
        WHERE restaurant_id = $1
        ORDER BY community_score DESC NULLS LAST, created_at ASC
        "#,
    )
    .bind(restaurant_id)
    .fetch_all(&state.db)
    .await?;

    use sqlx::Row;
    let dishes: Vec<DishResponse> = rows
        .into_iter()
        .map(|r| -> Result<DishResponse, sqlx::Error> {
            Ok(DishResponse {
                id: r.try_get("id")?,
                restaurant_id: r.try_get("restaurant_id")?,
                name: r.try_get("name")?,
                category: r.try_get("category")?,
                price: r.try_get("price")?,
                attribute_state: r.try_get("attribute_state")?,
                community_score: r.try_get("community_score")?,
                vote_count: r.try_get("vote_count")?,
                created_at: r.try_get("created_at")?,
            })
        })
        .collect::<Result<Vec<_>, _>>()?;

    Ok(Json(dishes))
}

async fn batch_create_dishes(
    State(state): State<AppState>,
    Path(restaurant_id): Path<Uuid>,
    user: AuthUser,
    Json(req): Json<DishBatchCreateRequest>,
) -> AppResult<(StatusCode, Json<Vec<DishResponse>>)> {
    if req.dishes.is_empty() {
        return Err(AppError::BadRequest("At least one dish is required".to_string()));
    }

    // Fetch restaurant to get cuisine type for LLM classification
    let cuisine_row = sqlx::query("SELECT COALESCE(cuisine_type, 'Indian') as cuisine FROM restaurants WHERE id = $1")
        .bind(restaurant_id)
        .fetch_optional(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound(format!("Restaurant {restaurant_id} not found")))?;

    use sqlx::Row;
    let cuisine: String = cuisine_row.try_get("cuisine")?;

    let mut created_dishes = Vec::new();

    for item in &req.dishes {
        let dish_id = Uuid::new_v4();

        sqlx::query(
            r#"
            INSERT INTO dishes (id, restaurant_id, name, category, price, created_by, attribute_state)
            VALUES ($1, $2, $3, $4, $5, $6, 'classifying')
            "#,
        )
        .bind(dish_id)
        .bind(restaurant_id)
        .bind(&item.name)
        .bind(&item.category)
        .bind(item.price)
        .bind(user.id)
        .execute(&state.db)
        .await?;

        // Enqueue LLM classification job
        state.job_queue.enqueue(Job::ClassifyDish {
            dish_id,
            dish_name: item.name.clone(),
            cuisine: cuisine.clone(),
        }).await?;

        created_dishes.push(DishResponse {
            id: dish_id,
            restaurant_id,
            name: item.name.clone(),
            category: item.category.clone(),
            price: item.price,
            attribute_state: "classifying".to_string(),
            community_score: None,
            vote_count: 0,
            created_at: chrono::Utc::now(),
        });
    }

    Ok((StatusCode::CREATED, Json(created_dishes)))
}

async fn get_dish(
    State(state): State<AppState>,
    Path(dish_id): Path<Uuid>,
) -> AppResult<Json<DishDetailResponse>> {
    let row = sqlx::query(
        r#"
        SELECT id, restaurant_id, name, category, price, attribute_state::text,
               community_score, vote_count, created_at
        FROM dishes WHERE id = $1
        "#,
    )
    .bind(dish_id)
    .fetch_optional(&state.db)
    .await?
    .ok_or_else(|| AppError::NotFound(format!("Dish {dish_id} not found")))?;

    use sqlx::Row;
    let attribute_state: String = row.try_get("attribute_state")?;

    // Fetch attribute priors if classified
    let attribute_priors = if attribute_state == "classified" {
        let prior_row = sqlx::query(
            r#"
            SELECT spice_score, sweetness_score, dish_type, cuisine,
                   final_spice_score, final_sweetness_score, community_vote_count, confidence_score
            FROM dish_attribute_priors WHERE dish_id = $1
            "#,
        )
        .bind(dish_id)
        .fetch_optional(&state.db)
        .await?;

        use sqlx::Row;
        prior_row
            .map(|p| -> Result<crate::dto::AttributePriorResponse, sqlx::Error> {
                Ok(crate::dto::AttributePriorResponse {
                    spice_score: p.try_get("spice_score")?,
                    sweetness_score: p.try_get("sweetness_score")?,
                    dish_type: p.try_get("dish_type")?,
                    cuisine: p.try_get("cuisine")?,
                    final_spice_score: p.try_get("final_spice_score")?,
                    final_sweetness_score: p.try_get("final_sweetness_score")?,
                    community_vote_count: p.try_get("community_vote_count")?,
                    confidence_score: p.try_get("confidence_score")?,
                })
            })
            .transpose()?
    } else {
        None
    };

    Ok(Json(DishDetailResponse {
        id: row.try_get("id")?,
        restaurant_id: row.try_get("restaurant_id")?,
        name: row.try_get("name")?,
        category: row.try_get("category")?,
        price: row.try_get("price")?,
        attribute_state,
        community_score: row.try_get("community_score")?,
        vote_count: row.try_get("vote_count")?,
        attribute_priors,
        created_at: row.try_get("created_at")?,
    }))
}

async fn upsert_reaction(
    State(state): State<AppState>,
    Path(dish_id): Path<Uuid>,
    user: AuthUser,
    Json(req): Json<ReactionUpsertRequest>,
) -> AppResult<Json<serde_json::Value>> {
    check_user_limit(&state.rl_reactions, user.id)?;

    let valid_reactions = ["so_yummy", "tasty", "pretty_good", "meh", "never_again"];
    if !valid_reactions.contains(&req.reaction.as_str()) {
        return Err(AppError::BadRequest(format!(
            "Invalid reaction. Must be one of: {}",
            valid_reactions.join(", ")
        )));
    }

    // Check if this is a new reaction (for reaction_count tracking)
    let is_new_reaction = sqlx::query(
        "SELECT 1 FROM dish_reactions WHERE user_id = $1 AND dish_id = $2",
    )
    .bind(user.id)
    .bind(dish_id)
    .fetch_optional(&state.db)
    .await?
    .is_none();

    // Upsert reaction + recalculate aggregate inside a single transaction
    let mut tx = state.db.begin().await?;

    sqlx::query(
        r#"
        INSERT INTO dish_reactions (id, user_id, dish_id, reaction)
        VALUES ($1, $2, $3, $4::reaction_type)
        ON CONFLICT (user_id, dish_id) DO UPDATE SET
            reaction = EXCLUDED.reaction,
            updated_at = NOW(),
            synced_at = NOW()
        "#,
    )
    .bind(Uuid::new_v4())
    .bind(user.id)
    .bind(dish_id)
    .bind(&req.reaction)
    .execute(&mut *tx)
    .await?;

    // Recalculate community_score and vote_count for the dish
    // Weights: so_yummy=5, tasty=4, pretty_good=3, meh=2, never_again=1
    sqlx::query(
        r#"
        UPDATE dishes SET
            vote_count = (SELECT COUNT(*) FROM dish_reactions WHERE dish_id = $1),
            community_score = (
                SELECT CASE WHEN COUNT(*) = 0 THEN NULL ELSE
                    (SUM(CASE reaction::text
                        WHEN 'so_yummy' THEN 5.0
                        WHEN 'tasty' THEN 4.0
                        WHEN 'pretty_good' THEN 3.0
                        WHEN 'meh' THEN 2.0
                        WHEN 'never_again' THEN 1.0
                        ELSE 3.0 END) / COUNT(*))
                END
                FROM dish_reactions WHERE dish_id = $1
            ),
            updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(dish_id)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;

    // Anomaly detection: flag reaction spam (>20 reactions in 5 min) — non-blocking
    let spam_db = state.db.clone();
    let spam_user_id = user.id;
    tokio::spawn(async move {
        let result = sqlx::query(
            r#"
            SELECT COUNT(*) as cnt
            FROM dish_reactions
            WHERE user_id = $1
              AND updated_at > NOW() - INTERVAL '5 minutes'
            "#,
        )
        .bind(spam_user_id)
        .fetch_one(&spam_db)
        .await;

        if let Ok(row) = result {
            use sqlx::Row;
            let count: i64 = row.try_get("cnt").unwrap_or(0);
            if count > 20 {
                let _ = sqlx::query(
                    r#"
                    INSERT INTO admin_flags (user_id, reason, metadata)
                    VALUES ($1, 'reaction_spam', $2)
                    "#,
                )
                .bind(spam_user_id)
                .bind(serde_json::json!({ "reaction_count_5min": count }))
                .execute(&spam_db)
                .await;
            }
        }
    });

    // Update taste vector incrementally if dish is classified
    let prior_row = sqlx::query(
        r#"SELECT spice_score, sweetness_score, final_spice_score, final_sweetness_score,
                  dish_type, cuisine
           FROM dish_attribute_priors WHERE dish_id = $1"#,
    )
    .bind(dish_id)
    .fetch_optional(&state.db)
    .await?;

    if let Some(prior) = prior_row {
        use sqlx::Row;
        let raw_spice: f64 = prior.try_get("spice_score")?;
        let raw_sweetness: f64 = prior.try_get("sweetness_score")?;
        let final_spice_score: Option<f64> = prior.try_get("final_spice_score")?;
        let final_sweetness_score: Option<f64> = prior.try_get("final_sweetness_score")?;
        // dish_type and cuisine are NOT NULL in schema
        let dish_type: String = prior.try_get("dish_type")?;
        let cuisine: String = prior.try_get("cuisine")?;

        // Use Bayesian-blended scores when available, fall back to raw LLM priors
        let spice = final_spice_score.unwrap_or(raw_spice);
        let sweetness = final_sweetness_score.unwrap_or(raw_sweetness);

        // Normalize reaction to 0–1 signal for distribution updates
        let reaction_signal: f64 = match req.reaction.as_str() {
            "so_yummy"    => 1.0,
            "tasty"       => 0.75,
            "pretty_good" => 0.5,
            "meh"         => 0.25,
            "never_again" => 0.0,
            _             => 0.5,
        };

        // Get or create taste vector
        sqlx::query(
            r#"
            INSERT INTO user_taste_vectors (id, user_id) VALUES ($1, $2)
            ON CONFLICT (user_id) DO NOTHING
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(user.id)
        .execute(&state.db)
        .await?;

        // Incremental update: new_pref = old_pref + 0.1 * (dish_attr - old_pref)
        // cuisine and dish_type are NOT NULL, so always update distributions.
        // Only increment reaction_count for new reactions (not re-reactions).
        sqlx::query(
            r#"
            UPDATE user_taste_vectors SET
                spice_preference = spice_preference + 0.1 * ($1 - spice_preference),
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
                reaction_count = reaction_count + $7,
                updated_at = NOW()
            WHERE user_id = $8
            "#,
        )
        .bind(spice)
        .bind(sweetness)
        .bind(reaction_signal)  // $3 cuisine signal
        .bind(reaction_signal)  // $4 dish_type signal
        .bind(&cuisine)
        .bind(&dish_type)
        .bind(if is_new_reaction { 1i32 } else { 0i32 })
        .bind(user.id)
        .execute(&state.db)
        .await?;
    }

    Ok(Json(serde_json::json!({ "ok": true })))
}

async fn reaction_summary(
    State(state): State<AppState>,
    Path(dish_id): Path<Uuid>,
) -> AppResult<Json<ReactionSummaryResponse>> {
    let rows = sqlx::query(
        "SELECT reaction::text, COUNT(*) as count FROM dish_reactions WHERE dish_id = $1 GROUP BY reaction",
    )
    .bind(dish_id)
    .fetch_all(&state.db)
    .await?;

    use sqlx::Row;
    let mut breakdown = std::collections::HashMap::new();
    let mut total: i64 = 0;
    let mut weighted_sum: f64 = 0.0;

    for row in rows {
        let reaction: String = row.try_get("reaction")?;
        let count: i64 = row.try_get("count")?;
        total += count;
        let weight = match reaction.as_str() {
            "so_yummy" => 5.0,
            "tasty" => 4.0,
            "pretty_good" => 3.0,
            "meh" => 2.0,
            "never_again" => 1.0,
            _ => 3.0,
        };
        weighted_sum += weight * count as f64;
        breakdown.insert(reaction, count);
    }

    let weighted_score = if total > 0 { weighted_sum / total as f64 } else { 0.0 };

    Ok(Json(ReactionSummaryResponse { total, breakdown, weighted_score }))
}

async fn upsert_attribute_vote(
    State(state): State<AppState>,
    Path(dish_id): Path<Uuid>,
    user: AuthUser,
    Json(req): Json<AttributeVoteRequest>,
) -> AppResult<Json<serde_json::Value>> {
    let valid_attrs = ["spice", "sweetness"];
    if !valid_attrs.contains(&req.attribute.as_str()) {
        return Err(AppError::BadRequest("attribute must be 'spice' or 'sweetness'".to_string()));
    }
    if req.value < 0.0 || req.value > 1.0 {
        return Err(AppError::BadRequest("value must be between 0.0 and 1.0".to_string()));
    }

    // Upsert attribute vote + recompute Bayesian blended scores inside a single transaction
    let mut tx = state.db.begin().await?;

    sqlx::query(
        r#"
        INSERT INTO dish_attribute_votes (id, user_id, dish_id, attribute, value)
        VALUES ($1, $2, $3, $4::attribute_name, $5)
        ON CONFLICT (user_id, dish_id, attribute) DO UPDATE SET
            value = EXCLUDED.value,
            updated_at = NOW()
        "#,
    )
    .bind(Uuid::new_v4())
    .bind(user.id)
    .bind(dish_id)
    .bind(&req.attribute)
    .bind(req.value)
    .execute(&mut *tx)
    .await?;

    // Recompute Bayesian blended scores
    // final_score = (k * llm_prior + n * community_avg) / (k + n)
    let k = state.config.bayesian_prior_weight;
    let prior_row = sqlx::query(
        "SELECT spice_score, sweetness_score FROM dish_attribute_priors WHERE dish_id = $1",
    )
    .bind(dish_id)
    .fetch_optional(&mut *tx)
    .await?;

    if let Some(prior) = prior_row {
        use sqlx::Row;
        let llm_spice: f64 = prior.try_get("spice_score")?;
        let llm_sweetness: f64 = prior.try_get("sweetness_score")?;

        let vote_avgs = sqlx::query(
            r#"
            SELECT
                AVG(CASE WHEN attribute = 'spice' THEN value END) as avg_spice,
                COUNT(CASE WHEN attribute = 'spice' THEN 1 END) as n_spice,
                AVG(CASE WHEN attribute = 'sweetness' THEN value END) as avg_sweetness,
                COUNT(CASE WHEN attribute = 'sweetness' THEN 1 END) as n_sweetness
            FROM dish_attribute_votes WHERE dish_id = $1
            "#,
        )
        .bind(dish_id)
        .fetch_one(&mut *tx)
        .await?;

        let avg_spice: Option<f64> = vote_avgs.try_get("avg_spice")?;
        let avg_sweetness: Option<f64> = vote_avgs.try_get("avg_sweetness")?;
        let n_spice: i64 = vote_avgs.try_get("n_spice")?;
        let n_sweetness: i64 = vote_avgs.try_get("n_sweetness")?;

        let final_spice = avg_spice
            .map(|s| (k * llm_spice + n_spice as f64 * s) / (k + n_spice as f64));
        let final_sweetness = avg_sweetness
            .map(|s| (k * llm_sweetness + n_sweetness as f64 * s) / (k + n_sweetness as f64));

        // confidence_score = min(n / (n + k), 1.0) — per-attribute for the voted attribute
        let n_for_confidence = if req.attribute == "spice" { n_spice } else { n_sweetness } as f64;
        let confidence_score = (n_for_confidence / (n_for_confidence + k)).min(1.0);

        sqlx::query(
            r#"
            UPDATE dish_attribute_priors SET
                final_spice_score = $1,
                final_sweetness_score = $2,
                community_vote_count = $3,
                confidence_score = $4,
                updated_at = NOW()
            WHERE dish_id = $5
            "#,
        )
        .bind(final_spice)
        .bind(final_sweetness)
        .bind((n_spice + n_sweetness) as i32)
        .bind(confidence_score)
        .bind(dish_id)
        .execute(&mut *tx)
        .await?;
    }

    tx.commit().await?;

    Ok(Json(serde_json::json!({ "ok": true })))
}

async fn toggle_favorite(
    State(state): State<AppState>,
    Path(dish_id): Path<Uuid>,
    user: AuthUser,
) -> AppResult<Json<serde_json::Value>> {
    // Check if already favorited
    let existing = sqlx::query(
        "SELECT id FROM favorites WHERE user_id = $1 AND dish_id = $2",
    )
    .bind(user.id)
    .bind(dish_id)
    .fetch_optional(&state.db)
    .await?;

    if existing.is_some() {
        // Remove favorite
        sqlx::query("DELETE FROM favorites WHERE user_id = $1 AND dish_id = $2")
            .bind(user.id)
            .bind(dish_id)
            .execute(&state.db)
            .await?;
        Ok(Json(serde_json::json!({ "favorited": false })))
    } else {
        // Add favorite
        sqlx::query(
            "INSERT INTO favorites (id, user_id, dish_id) VALUES ($1, $2, $3)",
        )
        .bind(Uuid::new_v4())
        .bind(user.id)
        .bind(dish_id)
        .execute(&state.db)
        .await?;
        Ok(Json(serde_json::json!({ "favorited": true })))
    }
}

async fn get_dish_attributes(
    State(state): State<AppState>,
    Path(dish_id): Path<Uuid>,
) -> AppResult<Json<DishAttributesResponse>> {
    use sqlx::Row;

    // Get dish attribute_state
    let dish_row = sqlx::query(
        "SELECT attribute_state::text FROM dishes WHERE id = $1"
    )
    .bind(dish_id)
    .fetch_optional(&state.db)
    .await?
    .ok_or_else(|| AppError::NotFound(format!("Dish {dish_id} not found")))?;

    let attribute_state: String = dish_row.try_get("attribute_state")?;

    // Get LLM priors if available
    let prior = sqlx::query(
        r#"SELECT spice_score, sweetness_score, dish_type, cuisine,
                  final_spice_score, final_sweetness_score, community_vote_count, confidence_score
           FROM dish_attribute_priors WHERE dish_id = $1"#
    )
    .bind(dish_id)
    .fetch_optional(&state.db)
    .await?;

    // Get community vote averages (AVG of an empty set returns NULL, so these are always Option<f64>)
    let vote_row = sqlx::query(
        r#"SELECT
               AVG(CASE WHEN attribute = 'spice' THEN value END) as avg_spice,
               AVG(CASE WHEN attribute = 'sweetness' THEN value END) as avg_sweetness
           FROM dish_attribute_votes WHERE dish_id = $1"#
    )
    .bind(dish_id)
    .fetch_one(&state.db)
    .await?;

    let community_spice_avg: Option<f64> = vote_row.try_get("avg_spice")?;
    let community_sweetness_avg: Option<f64> = vote_row.try_get("avg_sweetness")?;

    Ok(Json(match prior {
        Some(p) => DishAttributesResponse {
            attribute_state,
            llm_spice_score: Some(p.try_get("spice_score")?),
            llm_sweetness_score: Some(p.try_get("sweetness_score")?),
            llm_dish_type: Some(p.try_get("dish_type")?),
            llm_cuisine: Some(p.try_get("cuisine")?),
            community_spice_avg,
            community_sweetness_avg,
            community_vote_count: p.try_get("community_vote_count")?,
            final_spice_score: p.try_get("final_spice_score")?,
            final_sweetness_score: p.try_get("final_sweetness_score")?,
            confidence_score: p.try_get("confidence_score")?,
        },
        None => DishAttributesResponse {
            attribute_state,
            llm_spice_score: None,
            llm_sweetness_score: None,
            llm_dish_type: None,
            llm_cuisine: None,
            community_spice_avg,
            community_sweetness_avg,
            community_vote_count: 0,
            final_spice_score: None,
            final_sweetness_score: None,
            confidence_score: None,
        },
    }))
}

async fn get_compatibility(
    State(state): State<AppState>,
    Path(dish_id): Path<Uuid>,
    user: AuthUser,
) -> AppResult<Json<CompatibilityResponse>> {
    user.require_pro()?;

    use sqlx::Row;

    // Verify dish exists before any threshold checks
    sqlx::query("SELECT 1 FROM dishes WHERE id = $1")
        .bind(dish_id)
        .fetch_optional(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound(format!("Dish {dish_id} not found")))?;

    // Fetch user taste vector — reaction_count here counts only reactions to classified dishes,
    // matching the spec requirement of ≥10 reactions to dishes with overlapping attributes.
    let vector_row = sqlx::query(
        r#"SELECT spice_preference, sweetness_preference, reaction_count
           FROM user_taste_vectors WHERE user_id = $1"#,
    )
    .bind(user.id)
    .fetch_optional(&state.db)
    .await?;

    let (spice_pref, sweet_pref, user_reactions) = match vector_row {
        Some(ref r) => {
            let spice: f64 = r.try_get("spice_preference")?;
            let sweet: f64 = r.try_get("sweetness_preference")?;
            let count: i32 = r.try_get("reaction_count")?;
            (spice, sweet, count)
        }
        None => {
            return Ok(Json(CompatibilityResponse {
                signal: None,
                score: None,
                reason: Some("no_taste_vector".to_string()),
            }));
        }
    };

    if user_reactions < 10 {
        return Ok(Json(CompatibilityResponse {
            signal: None,
            score: None,
            reason: Some("user_threshold_not_met".to_string()),
        }));
    }

    // Fetch dish attribute priors
    let prior_row = sqlx::query(
        r#"SELECT final_spice_score, final_sweetness_score, community_vote_count
           FROM dish_attribute_priors WHERE dish_id = $1"#,
    )
    .bind(dish_id)
    .fetch_optional(&state.db)
    .await?;

    let (final_spice, final_sweet, community_votes) = match prior_row {
        Some(ref r) => {
            let spice: Option<f64> = r.try_get("final_spice_score")?;
            let sweet: Option<f64> = r.try_get("final_sweetness_score")?;
            let votes: i32 = r.try_get("community_vote_count")?;
            (spice, sweet, votes)
        }
        None => (None, None, 0i32),
    };

    // community_votes < 10 covers the None prior case (votes defaults to 0)
    if community_votes < 10 {
        return Ok(Json(CompatibilityResponse {
            signal: None,
            score: None,
            reason: Some("dish_threshold_not_met".to_string()),
        }));
    }

    let final_spice = match final_spice {
        Some(v) => v,
        None => {
            return Ok(Json(CompatibilityResponse {
                signal: None,
                score: None,
                reason: Some("dish_threshold_not_met".to_string()),
            }));
        }
    };
    let final_sweet = match final_sweet {
        Some(v) => v,
        None => {
            return Ok(Json(CompatibilityResponse {
                signal: None,
                score: None,
                reason: Some("dish_threshold_not_met".to_string()),
            }));
        }
    };

    // Euclidean similarity over spice + sweetness dimensions, normalised to [0, 1]
    let d_spice = (spice_pref - final_spice).abs();
    let d_sweet = (sweet_pref - final_sweet).abs();
    let distance = ((d_spice * d_spice + d_sweet * d_sweet) / 2.0).sqrt();
    let score = (1.0 - distance).clamp(0.0, 1.0);

    let signal = if score >= 0.75 {
        "You'll probably love this"
    } else if score >= 0.55 {
        "This fits your taste"
    } else if score >= 0.40 {
        "Could go either way"
    } else {
        "Might not be your style"
    };

    Ok(Json(CompatibilityResponse {
        signal: Some(signal.to_string()),
        score: Some(score),
        reason: None,
    }))
}

// ─────────────────────────────────────────────
// Admin handlers
// ─────────────────────────────────────────────

async fn admin_recompute_taste_vectors(
    State(state): State<AppState>,
    user: AuthUser,
) -> AppResult<Json<serde_json::Value>> {
    user.require_admin()?;

    state.job_queue.enqueue(Job::RecomputeTasteVectors).await?;

    Ok(Json(serde_json::json!({
        "ok": true,
        "message": "Recompute job enqueued"
    })))
}
