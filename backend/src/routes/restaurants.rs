use axum::{
    Json, Router,
    extract::{Path, Query, State},
    http::StatusCode,
    routing::{get, post},
};
use uuid::Uuid;

use crate::{
    AppState,
    auth::middleware::AuthUser,
    dto::{
        DishResponse, DuplicateCheckQuery, DuplicateCheckResponse, MergeRestaurantRequest,
        NearbyQuery, RestaurantCreateRequest, RestaurantDetailResponse, RestaurantPatchRequest,
        RestaurantSummary,
    },
    error::{AppError, AppResult},
    middleware::rate_limit::check_user_limit,
};

const MAX_RESTAURANT_NAME_LEN: usize = 200;
const MAX_CITY_LEN: usize = 100;

fn validate_name(name: &str) -> AppResult<()> {
    let name = name.trim();
    if name.is_empty() {
        return Err(AppError::BadRequest("Restaurant name is required".to_string()));
    }
    if name.chars().count() > MAX_RESTAURANT_NAME_LEN {
        return Err(AppError::BadRequest(format!(
            "Restaurant name must be at most {MAX_RESTAURANT_NAME_LEN} characters"
        )));
    }
    Ok(())
}

fn validate_city(city: &str) -> AppResult<()> {
    if city.trim().chars().count() > MAX_CITY_LEN {
        return Err(AppError::BadRequest(format!(
            "City must be at most {MAX_CITY_LEN} characters"
        )));
    }
    Ok(())
}

fn validate_coordinates(latitude: f64, longitude: f64) -> AppResult<()> {
    if !latitude.is_finite() || !(-90.0..=90.0).contains(&latitude) {
        return Err(AppError::BadRequest(
            "latitude must be between -90 and 90".to_string(),
        ));
    }
    if !longitude.is_finite() || !(-180.0..=180.0).contains(&longitude) {
        return Err(AppError::BadRequest(
            "longitude must be between -180 and 180".to_string(),
        ));
    }
    Ok(())
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/", post(create_restaurant))
        .route("/nearby", get(nearby_restaurants))
        .route("/duplicate-check", get(duplicate_check))
        .route("/:id", get(get_restaurant).patch(update_restaurant))
}

pub fn admin_router() -> Router<AppState> {
    Router::new()
        .route("/restaurants/:id/merge", post(merge_restaurant))
}

async fn create_restaurant(
    State(state): State<AppState>,
    user: AuthUser,
    Json(req): Json<RestaurantCreateRequest>,
) -> AppResult<(StatusCode, Json<RestaurantDetailResponse>)> {
    tracing::info!(user_id = %user.id, name = %req.name, "create_restaurant called");
    check_user_limit(&state.rl_restaurant_create, user.id)?;

    validate_name(&req.name)?;
    validate_city(&req.city)?;
    validate_coordinates(req.latitude, req.longitude)?;

    // Duplicate guard: block if a restaurant with the same name exists within ~100 m.
    // Uses bounding box (≈ 0.001° ≈ 111 m) + case-insensitive name match or high similarity.
    let lat_delta = 0.001_f64;
    let lng_delta = 0.001_f64 / (req.latitude.to_radians().cos()).max(0.001);

    let duplicate = sqlx::query(
        r#"
        SELECT id FROM restaurants
        WHERE (LOWER(name) = LOWER($1) OR similarity(name, $1) > 0.7)
          AND latitude  BETWEEN $2 AND $3
          AND longitude BETWEEN $4 AND $5
        LIMIT 1
        "#,
    )
    .bind(&req.name)
    .bind(req.latitude - lat_delta)
    .bind(req.latitude + lat_delta)
    .bind(req.longitude - lng_delta)
    .bind(req.longitude + lng_delta)
    .fetch_optional(&state.db)
    .await?;

    if duplicate.is_some() {
        return Err(AppError::BadRequest(
            "A restaurant with this name already exists at this location".to_string(),
        ));
    }

    let id = Uuid::new_v4();

    let insert_result = sqlx::query(
        r#"
        INSERT INTO restaurants (
            id, name, city, latitude, longitude, cuisine_type, created_by,
            google_place_id, google_rating, google_rating_count, price_level,
            business_status, phone_number, website, opening_hours
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
        "#,
    )
    .bind(id)
    .bind(&req.name)
    .bind(&req.city)
    .bind(req.latitude)
    .bind(req.longitude)
    .bind(&req.cuisine_type)
    .bind(user.id)
    .bind(&req.google_place_id)
    .bind(req.google_rating)
    .bind(req.google_rating_count)
    .bind(req.price_level)
    .bind(&req.business_status)
    .bind(&req.phone_number)
    .bind(&req.website)
    .bind(req.opening_hours.as_ref())
    .execute(&state.db)
    .await;

    // A Google Place picked via the map/autocomplete flow may already have
    // been inserted by the crawler (place_id unique index, migration 0009) —
    // surface that as a friendly duplicate message instead of a raw 500.
    if let Err(sqlx::Error::Database(db_err)) = &insert_result {
        if db_err.is_unique_violation() {
            return Err(AppError::Conflict(
                "This place has already been added to Remembite".to_string(),
            ));
        }
    }
    insert_result?;

    let response = RestaurantDetailResponse {
        id,
        name: req.name,
        city: req.city,
        latitude: req.latitude,
        longitude: req.longitude,
        cuisine_type: req.cuisine_type,
        avg_rating: None,
        rating_count: 0,
        top_dishes: vec![],
        created_by: user.id,
        created_at: chrono::Utc::now(),
        google_place_id: req.google_place_id,
        google_rating: req.google_rating,
        google_rating_count: req.google_rating_count,
        price_level: req.price_level,
        business_status: req.business_status,
        phone_number: req.phone_number,
        website: req.website,
        opening_hours: req.opening_hours,
    };

    Ok((StatusCode::CREATED, Json(response)))
}

async fn get_restaurant(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> AppResult<Json<RestaurantDetailResponse>> {
    let row = sqlx::query(
        r#"SELECT id, name, city, latitude, longitude, cuisine_type, created_by, avg_rating, rating_count, created_at,
                  google_place_id, google_rating, google_rating_count, price_level,
                  business_status, phone_number, website, opening_hours
           FROM restaurants WHERE id = $1"#,
    )
    .bind(id)
    .fetch_optional(&state.db)
    .await?
    .ok_or_else(|| AppError::NotFound(format!("Restaurant {id} not found")))?;

    use sqlx::Row;
    let restaurant_id: Uuid = row.try_get("id")?;
    let name: String = row.try_get("name")?;
    let city: String = row.try_get("city")?;
    let latitude: f64 = row.try_get("latitude")?;
    let longitude: f64 = row.try_get("longitude")?;
    let cuisine_type: Option<String> = row.try_get("cuisine_type")?;
    let created_by: Uuid = row.try_get("created_by")?;
    let avg_rating: Option<f64> = row.try_get("avg_rating")?;
    let rating_count: i32 = row.try_get("rating_count")?;
    let created_at: chrono::DateTime<chrono::Utc> = row.try_get("created_at")?;
    let google_place_id: Option<String> = row.try_get("google_place_id")?;
    let google_rating: Option<f64> = row.try_get("google_rating")?;
    let google_rating_count: Option<i32> = row.try_get("google_rating_count")?;
    let price_level: Option<i16> = row.try_get("price_level")?;
    let business_status: Option<String> = row.try_get("business_status")?;
    let phone_number: Option<String> = row.try_get("phone_number")?;
    let website: Option<String> = row.try_get("website")?;
    let opening_hours: Option<serde_json::Value> = row.try_get("opening_hours")?;

    // Lazy enrichment: fetch Place Details in the background when stale or missing.
    // User gets the cached response immediately; enriched data shows on next load.
    //
    // Atomic claim: set enriched_at = NOW() up front, gated on the same
    // staleness predicate, before spawning the expensive work. Without this,
    // N concurrent viewers of a stale restaurant all read enriched_at as
    // stale, all spawn Place Details + menu-seed calls, and — worse — two
    // concurrent seed_dishes() calls both pass the "restaurant has 0 dishes"
    // check before either commits, duplicating the whole menu. Only the
    // request whose UPDATE actually changes a row (rows_affected == 1) wins
    // the claim and proceeds; everyone else no-ops.
    let claimed = sqlx::query(
        r#"
        UPDATE restaurants
        SET enriched_at = NOW()
        WHERE id = $1
          AND (enriched_at IS NULL OR enriched_at < NOW() - INTERVAL '90 days')
        "#,
    )
    .bind(restaurant_id)
    .execute(&state.db)
    .await?
    .rows_affected()
        > 0;

    if claimed && !state.config.google_places_api_key.is_empty() {
        if let Some(place_id) = google_place_id.clone() {
            let crawler = state.crawler.clone();
            let db = state.db.clone();
            let rid = restaurant_id;

            tokio::spawn(async move {
                match crawler.place_details(&place_id).await {
                    Ok(Some(detail)) => {
                        let _ = sqlx::query(
                            r#"UPDATE restaurants SET
                                phone_number  = COALESCE($1, phone_number),
                                website       = COALESCE($2, website),
                                opening_hours = COALESCE($3, opening_hours),
                                enriched_at   = NOW()
                               WHERE id = $4"#,
                        )
                        .bind(&detail.formatted_phone_number)
                        .bind(&detail.website)
                        .bind(&detail.opening_hours)
                        .bind(rid)
                        .execute(&db)
                        .await;

                        if let Err(e) = crawler
                            .seed_dishes(rid, &detail.name, detail.website.as_deref())
                            .await
                        {
                            tracing::warn!(restaurant_id = %rid, "menu seeding failed: {e}");
                        }
                    }
                    Ok(None) => {}
                    Err(e) => {
                        tracing::warn!(restaurant_id = %rid, "place details enrichment failed: {e}");
                    }
                }
            });
        }
    }

    // Top 5 dishes by community_score
    let dish_rows = sqlx::query(
        r#"
        SELECT id, restaurant_id, name, category, price, attribute_state::text, community_score, vote_count, created_at
        FROM dishes
        WHERE restaurant_id = $1
        ORDER BY community_score DESC NULLS LAST
        LIMIT 5
        "#,
    )
    .bind(restaurant_id)
    .fetch_all(&state.db)
    .await?;

    let top_dishes: Vec<DishResponse> = dish_rows
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

    Ok(Json(RestaurantDetailResponse {
        id: restaurant_id,
        name,
        city,
        latitude,
        longitude,
        cuisine_type,
        avg_rating,
        rating_count,
        top_dishes,
        created_by,
        created_at,
        google_place_id,
        google_rating,
        google_rating_count,
        price_level,
        business_status,
        phone_number,
        website,
        opening_hours,
    }))
}

async fn update_restaurant(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    user: AuthUser,
    Json(req): Json<RestaurantPatchRequest>,
) -> AppResult<Json<serde_json::Value>> {
    if let Some(name) = req.name.as_deref() {
        validate_name(name)?;
    }
    if let Some(city) = req.city.as_deref() {
        validate_city(city)?;
    }

    // Verify ownership or admin
    let row = sqlx::query("SELECT created_by FROM restaurants WHERE id = $1")
        .bind(id)
        .fetch_optional(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound(format!("Restaurant {id} not found")))?;

    use sqlx::Row;
    let created_by: Uuid = row.try_get("created_by")?;
    if created_by != user.id && !user.admin {
        return Err(AppError::Forbidden("Not authorized to edit this restaurant".to_string()));
    }

    sqlx::query(
        r#"
        UPDATE restaurants
        SET
            name = COALESCE($1, name),
            city = COALESCE($2, city),
            cuisine_type = COALESCE($3, cuisine_type),
            updated_at = NOW()
        WHERE id = $4
        "#,
    )
    .bind(&req.name)
    .bind(&req.city)
    .bind(&req.cuisine_type)
    .bind(id)
    .execute(&state.db)
    .await?;

    Ok(Json(serde_json::json!({ "ok": true })))
}

async fn nearby_restaurants(
    State(state): State<AppState>,
    Query(params): Query<NearbyQuery>,
) -> AppResult<Json<Vec<RestaurantSummary>>> {
    let radius = params.radius.unwrap_or(5000.0); // default 5km

    // Bounding box approximation (1 degree lat ≈ 111km)
    let lat_delta = radius / 111_000.0;
    let lng_delta = radius / (111_000.0 * (params.lat.to_radians().cos()).max(0.001));

    let rows = sqlx::query(
        r#"
        SELECT id, name, city, cuisine_type, avg_rating, rating_count, latitude, longitude,
               google_rating, google_rating_count, price_level,
               (opening_hours->>'open_now')::boolean AS open_now
        FROM restaurants
        WHERE latitude BETWEEN $1 AND $2
          AND longitude BETWEEN $3 AND $4
        ORDER BY (
            -- Weighted average of app rating and Google rating
            COALESCE(
                (
                    COALESCE(avg_rating, 0.0) * rating_count
                    + COALESCE(google_rating, 0.0) * COALESCE(google_rating_count, 0)
                ) / NULLIF(rating_count + COALESCE(google_rating_count, 0), 0),
                COALESCE(avg_rating, google_rating, 0.0)
            )
            -- Popularity bonus on a log scale (prevents huge chains from dominating)
            + LN(1.0 + rating_count + COALESCE(google_rating_count, 0)) * 0.3
        ) DESC NULLS LAST
        LIMIT 20
        "#,
    )
    .bind(params.lat - lat_delta)
    .bind(params.lat + lat_delta)
    .bind(params.lng - lng_delta)
    .bind(params.lng + lng_delta)
    .fetch_all(&state.db)
    .await?;

    use sqlx::Row;
    let mut restaurants: Vec<RestaurantSummary> = Vec::with_capacity(rows.len());
    for r in rows {
        restaurants.push(RestaurantSummary {
            id: r.try_get("id")?,
            name: r.try_get("name")?,
            city: r.try_get("city")?,
            cuisine_type: r.try_get("cuisine_type")?,
            avg_rating: r.try_get("avg_rating")?,
            rating_count: r.try_get("rating_count")?,
            latitude: r.try_get("latitude")?,
            longitude: r.try_get("longitude")?,
            google_rating: r.try_get("google_rating")?,
            open_now: r.try_get("open_now")?,
            price_level: r.try_get("price_level")?,
        });
    }

    Ok(Json(restaurants))
}


async fn duplicate_check(
    State(state): State<AppState>,
    Query(params): Query<DuplicateCheckQuery>,
) -> AppResult<Json<DuplicateCheckResponse>> {
    let lat_delta = 500.0 / 111_000.0;
    let lng_delta = 500.0 / (111_000.0 * (params.lat.to_radians().cos()).max(0.001));

    let rows = sqlx::query(
        r#"
        SELECT id, name, city, cuisine_type, avg_rating, rating_count, latitude, longitude,
               google_rating, price_level
        FROM restaurants
        WHERE similarity(name, $1) > 0.4
          AND latitude BETWEEN $2 AND $3
          AND longitude BETWEEN $4 AND $5
        ORDER BY similarity(name, $1) DESC
        LIMIT 5
        "#,
    )
    .bind(&params.name)
    .bind(params.lat - lat_delta)
    .bind(params.lat + lat_delta)
    .bind(params.lng - lng_delta)
    .bind(params.lng + lng_delta)
    .fetch_all(&state.db)
    .await?;

    use sqlx::Row;
    let mut candidates: Vec<RestaurantSummary> = Vec::with_capacity(rows.len());
    for r in rows {
        candidates.push(RestaurantSummary {
            id: r.try_get("id")?,
            name: r.try_get("name")?,
            city: r.try_get("city")?,
            cuisine_type: r.try_get("cuisine_type")?,
            avg_rating: r.try_get("avg_rating")?,
            rating_count: r.try_get("rating_count")?,
            latitude: r.try_get("latitude")?,
            longitude: r.try_get("longitude")?,
            google_rating: r.try_get("google_rating")?,
            open_now: None,
            price_level: r.try_get("price_level")?,
        });
    }

    let has_duplicate = !candidates.is_empty();
    Ok(Json(DuplicateCheckResponse { has_duplicate, candidates }))
}

async fn merge_restaurant(
    State(state): State<AppState>,
    Path(source_id): Path<Uuid>,
    auth: AuthUser,
    Json(req): Json<MergeRestaurantRequest>,
) -> AppResult<Json<serde_json::Value>> {
    auth.require_admin()?;

    let merge_into_id = req.merge_into_id;

    // Prevent merging into itself
    if source_id == merge_into_id {
        return Err(AppError::BadRequest(
            "Cannot merge a restaurant into itself".to_string(),
        ));
    }

    // Verify source restaurant exists
    sqlx::query("SELECT id FROM restaurants WHERE id = $1")
        .bind(source_id)
        .fetch_optional(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound(format!("Source restaurant {source_id} not found")))?;

    // Verify merge_into restaurant exists
    sqlx::query("SELECT id FROM restaurants WHERE id = $1")
        .bind(merge_into_id)
        .fetch_optional(&state.db)
        .await?
        .ok_or_else(|| {
            AppError::NotFound(format!("Target restaurant {merge_into_id} not found"))
        })?;

    let mut tx = state.db.begin().await?;

    // Step 3b: Same-named dishes in both restaurants would otherwise become
    // duplicate rows with split reactions once source dishes are re-pointed
    // to merge_into_id below. Find those pairs first, re-attach each source
    // dish's reactions/votes/favorites/intents onto the existing target dish
    // (skipping any a user already has on the target — the UNIQUE
    // constraints on these tables are per (user_id, dish_id)), then delete
    // the now-redundant source dish. ON DELETE CASCADE on dish_id cleans up
    // anything not explicitly re-attached.
    use sqlx::Row;
    let duplicate_pairs: Vec<(Uuid, Uuid)> = sqlx::query(
        r#"
        SELECT s.id as source_dish_id, t.id as target_dish_id
        FROM dishes s
        JOIN dishes t ON t.restaurant_id = $1 AND lower(t.name) = lower(s.name)
        WHERE s.restaurant_id = $2
        "#,
    )
    .bind(merge_into_id)
    .bind(source_id)
    .fetch_all(&mut *tx)
    .await?
    .into_iter()
    .map(|r| Ok::<_, sqlx::Error>((r.try_get("source_dish_id")?, r.try_get("target_dish_id")?)))
    .collect::<Result<_, _>>()?;

    for (dup_source_dish, target_dish) in duplicate_pairs {
        sqlx::query(
            r#"
            INSERT INTO dish_reactions (id, user_id, dish_id, reaction, synced_at, updated_at)
            SELECT uuid_generate_v4(), user_id, $2, reaction, synced_at, updated_at
            FROM dish_reactions WHERE dish_id = $1
            ON CONFLICT (user_id, dish_id) DO NOTHING
            "#,
        )
        .bind(dup_source_dish)
        .bind(target_dish)
        .execute(&mut *tx)
        .await?;

        sqlx::query(
            r#"
            INSERT INTO dish_attribute_votes (id, user_id, dish_id, attribute, value, created_at, updated_at)
            SELECT uuid_generate_v4(), user_id, $2, attribute, value, created_at, updated_at
            FROM dish_attribute_votes WHERE dish_id = $1
            ON CONFLICT (user_id, dish_id, attribute) DO NOTHING
            "#,
        )
        .bind(dup_source_dish)
        .bind(target_dish)
        .execute(&mut *tx)
        .await?;

        sqlx::query(
            r#"
            INSERT INTO favorites (id, user_id, dish_id, created_at)
            SELECT uuid_generate_v4(), user_id, $2, created_at
            FROM favorites WHERE dish_id = $1
            ON CONFLICT (user_id, dish_id) DO NOTHING
            "#,
        )
        .bind(dup_source_dish)
        .bind(target_dish)
        .execute(&mut *tx)
        .await?;

        sqlx::query(
            r#"
            INSERT INTO dish_intents (id, user_id, dish_id, intent, created_at)
            SELECT gen_random_uuid(), user_id, $2, intent, created_at
            FROM dish_intents WHERE dish_id = $1
            ON CONFLICT (user_id, dish_id) DO NOTHING
            "#,
        )
        .bind(dup_source_dish)
        .bind(target_dish)
        .execute(&mut *tx)
        .await?;

        // Polymorphic (entity_type, entity_id) rows have no FK — repoint
        // them before the source dish disappears, same as step 7b does for
        // the restaurant itself.
        for table in ["images", "reports", "edit_suggestions"] {
            sqlx::query(&format!(
                "UPDATE {table} SET entity_id = $1 WHERE entity_type = 'dish' AND entity_id = $2"
            ))
            .bind(target_dish)
            .bind(dup_source_dish)
            .execute(&mut *tx)
            .await?;
        }

        sqlx::query("DELETE FROM dishes WHERE id = $1")
            .bind(dup_source_dish)
            .execute(&mut *tx)
            .await?;

        // Reactions/votes were attached without going through
        // upsert_reaction / upsert_attribute_vote, so the cached aggregates
        // on the target dish are stale until recomputed here.
        crate::routes::dishes::recompute_dish_aggregates(&mut tx, target_dish, state.config.bayesian_prior_weight)
            .await?;
    }

    // Step 4: Move remaining (non-duplicate) dishes from source to merge_into
    sqlx::query("UPDATE dishes SET restaurant_id = $1 WHERE restaurant_id = $2")
        .bind(merge_into_id)
        .bind(source_id)
        .execute(&mut *tx)
        .await?;

    // Step 5: Copy ratings from source that don't conflict on (user_id, restaurant_id) of target
    sqlx::query(
        r#"
        INSERT INTO restaurant_ratings (id, user_id, restaurant_id, stars, created_at, updated_at)
        SELECT uuid_generate_v4(), user_id, $1, stars, created_at, updated_at
        FROM restaurant_ratings
        WHERE restaurant_id = $2
        ON CONFLICT (user_id, restaurant_id) DO NOTHING
        "#,
    )
    .bind(merge_into_id)
    .bind(source_id)
    .execute(&mut *tx)
    .await?;

    // Step 6: Delete source ratings
    sqlx::query("DELETE FROM restaurant_ratings WHERE restaurant_id = $1")
        .bind(source_id)
        .execute(&mut *tx)
        .await?;

    // Step 7: Recalculate avg_rating and rating_count on merge_into restaurant
    sqlx::query(
        r#"
        UPDATE restaurants SET
            avg_rating = (SELECT AVG(stars::float) FROM restaurant_ratings WHERE restaurant_id = $1),
            rating_count = (SELECT COUNT(*) FROM restaurant_ratings WHERE restaurant_id = $1),
            updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(merge_into_id)
    .execute(&mut *tx)
    .await?;

    // Step 7b: images/reports/edit_suggestions reference restaurants
    // polymorphically (entity_type + entity_id, no FK Postgres can enforce)
    // — without repointing these, deleting the source restaurant below left
    // them pointing at a UUID that no longer exists anywhere.
    sqlx::query("UPDATE images SET entity_id = $1 WHERE entity_type = 'restaurant' AND entity_id = $2")
        .bind(merge_into_id)
        .bind(source_id)
        .execute(&mut *tx)
        .await?;
    sqlx::query("UPDATE reports SET entity_id = $1 WHERE entity_type = 'restaurant' AND entity_id = $2")
        .bind(merge_into_id)
        .bind(source_id)
        .execute(&mut *tx)
        .await?;
    sqlx::query("UPDATE edit_suggestions SET entity_id = $1 WHERE entity_type = 'restaurant' AND entity_id = $2")
        .bind(merge_into_id)
        .bind(source_id)
        .execute(&mut *tx)
        .await?;

    // Step 8: Delete source restaurant
    sqlx::query("DELETE FROM restaurants WHERE id = $1")
        .bind(source_id)
        .execute(&mut *tx)
        .await?;

    // Step 9: Commit
    tx.commit().await?;

    Ok(Json(serde_json::json!({ "ok": true, "merged_into": merge_into_id })))
}
