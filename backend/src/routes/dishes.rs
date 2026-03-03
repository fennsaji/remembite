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
        AttributeVoteRequest, DishAttributesResponse, DishBatchCreateRequest, DishDetailResponse,
        DishResponse, ReactionSummaryResponse, ReactionUpsertRequest,
    },
    error::{AppError, AppResult},
    jobs::queue::Job,
    middleware::rate_limit::check_user_limit,
};

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
        .map(|r| DishResponse {
            id: r.try_get("id").unwrap(),
            restaurant_id: r.try_get("restaurant_id").unwrap(),
            name: r.try_get("name").unwrap(),
            category: r.try_get("category").unwrap(),
            price: r.try_get("price").unwrap(),
            attribute_state: r.try_get("attribute_state").unwrap(),
            community_score: r.try_get("community_score").unwrap(),
            vote_count: r.try_get("vote_count").unwrap(),
            created_at: r.try_get("created_at").unwrap(),
        })
        .collect();

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
                   final_spice_score, final_sweetness_score, community_vote_count
            FROM dish_attribute_priors WHERE dish_id = $1
            "#,
        )
        .bind(dish_id)
        .fetch_optional(&state.db)
        .await?;

        prior_row.map(|p| crate::dto::AttributePriorResponse {
            spice_score: p.try_get("spice_score").unwrap(),
            sweetness_score: p.try_get("sweetness_score").unwrap(),
            dish_type: p.try_get("dish_type").unwrap(),
            cuisine: p.try_get("cuisine").unwrap(),
            final_spice_score: p.try_get("final_spice_score").unwrap(),
            final_sweetness_score: p.try_get("final_sweetness_score").unwrap(),
            community_vote_count: p.try_get("community_vote_count").unwrap(),
        })
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
        "SELECT spice_score, sweetness_score FROM dish_attribute_priors WHERE dish_id = $1",
    )
    .bind(dish_id)
    .fetch_optional(&state.db)
    .await?;

    if let Some(prior) = prior_row {
        use sqlx::Row;
        let spice: f64 = prior.try_get("spice_score")?;
        let sweetness: f64 = prior.try_get("sweetness_score")?;

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
        sqlx::query(
            r#"
            UPDATE user_taste_vectors SET
                spice_preference = spice_preference + 0.1 * ($1 - spice_preference),
                sweetness_preference = sweetness_preference + 0.1 * ($2 - sweetness_preference),
                reaction_count = reaction_count + 1,
                updated_at = NOW()
            WHERE user_id = $3
            "#,
        )
        .bind(spice)
        .bind(sweetness)
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

    // Recompute Bayesian blended scores (k=5)
    // final_score = (k * llm_prior + n * community_avg) / (k + n)
    let k = 5.0f64;
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
                AVG(CASE WHEN attribute = 'sweetness' THEN value END) as avg_sweetness,
                COUNT(*) as total_votes
            FROM dish_attribute_votes WHERE dish_id = $1
            "#,
        )
        .bind(dish_id)
        .fetch_one(&mut *tx)
        .await?;

        let avg_spice: Option<f64> = vote_avgs.try_get("avg_spice")?;
        let avg_sweetness: Option<f64> = vote_avgs.try_get("avg_sweetness")?;
        let n: i64 = vote_avgs.try_get("total_votes")?;
        let n = n as f64;

        let final_spice = avg_spice
            .map(|s| (k * llm_spice + n * s) / (k + n));
        let final_sweetness = avg_sweetness
            .map(|s| (k * llm_sweetness + n * s) / (k + n));

        sqlx::query(
            r#"
            UPDATE dish_attribute_priors SET
                final_spice_score = $1,
                final_sweetness_score = $2,
                community_vote_count = $3,
                updated_at = NOW()
            WHERE dish_id = $4
            "#,
        )
        .bind(final_spice)
        .bind(final_sweetness)
        .bind(n as i32)
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
                  final_spice_score, final_sweetness_score, community_vote_count
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
        },
    }))
}
