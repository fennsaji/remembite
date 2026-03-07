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

    if req.name.trim().is_empty() {
        return Err(AppError::BadRequest("Restaurant name is required".to_string()));
    }

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

    sqlx::query(
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
    .await?;

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

    // Step 4: Move all dishes from source to merge_into
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

    // Step 8: Delete source restaurant
    sqlx::query("DELETE FROM restaurants WHERE id = $1")
        .bind(source_id)
        .execute(&mut *tx)
        .await?;

    // Step 9: Commit
    tx.commit().await?;

    Ok(Json(serde_json::json!({ "ok": true, "merged_into": merge_into_id })))
}
