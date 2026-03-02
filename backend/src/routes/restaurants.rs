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
        DishResponse, DuplicateCheckQuery, DuplicateCheckResponse, NearbyQuery,
        RestaurantCreateRequest, RestaurantDetailResponse, RestaurantPatchRequest,
        RestaurantSummary,
    },
    error::{AppError, AppResult},
};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/", post(create_restaurant))
        .route("/nearby", get(nearby_restaurants))
        .route("/duplicate-check", get(duplicate_check))
        .route("/:id", get(get_restaurant).patch(update_restaurant))
}

async fn create_restaurant(
    State(state): State<AppState>,
    user: AuthUser,
    Json(req): Json<RestaurantCreateRequest>,
) -> AppResult<(StatusCode, Json<RestaurantDetailResponse>)> {
    if req.name.trim().is_empty() {
        return Err(AppError::BadRequest("Restaurant name is required".to_string()));
    }

    let id = Uuid::new_v4();

    sqlx::query(
        r#"
        INSERT INTO restaurants (id, name, city, latitude, longitude, cuisine_type, created_by)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        "#,
    )
    .bind(id)
    .bind(&req.name)
    .bind(&req.city)
    .bind(req.latitude)
    .bind(req.longitude)
    .bind(&req.cuisine_type)
    .bind(user.id)
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
    };

    Ok((StatusCode::CREATED, Json(response)))
}

async fn get_restaurant(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> AppResult<Json<RestaurantDetailResponse>> {
    let row = sqlx::query(
        "SELECT id, name, city, latitude, longitude, cuisine_type, created_by, avg_rating, rating_count, created_at FROM restaurants WHERE id = $1",
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
    let radius = params.radius.unwrap_or(2000.0); // default 2km

    // Bounding box approximation (1 degree lat ≈ 111km)
    let lat_delta = radius / 111_000.0;
    let lng_delta = radius / (111_000.0 * (params.lat.to_radians().cos()).max(0.001));

    let rows = sqlx::query(
        r#"
        SELECT id, name, city, cuisine_type, avg_rating, rating_count, latitude, longitude
        FROM restaurants
        WHERE latitude BETWEEN $1 AND $2
          AND longitude BETWEEN $3 AND $4
        ORDER BY rating_count DESC
        LIMIT 30
        "#,
    )
    .bind(params.lat - lat_delta)
    .bind(params.lat + lat_delta)
    .bind(params.lng - lng_delta)
    .bind(params.lng + lng_delta)
    .fetch_all(&state.db)
    .await?;

    use sqlx::Row;
    let restaurants: Vec<RestaurantSummary> = rows
        .into_iter()
        .map(|r| RestaurantSummary {
            id: r.try_get("id").unwrap(),
            name: r.try_get("name").unwrap(),
            city: r.try_get("city").unwrap(),
            cuisine_type: r.try_get("cuisine_type").unwrap(),
            avg_rating: r.try_get("avg_rating").unwrap(),
            rating_count: r.try_get("rating_count").unwrap(),
            latitude: r.try_get("latitude").unwrap(),
            longitude: r.try_get("longitude").unwrap(),
        })
        .collect();

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
        SELECT id, name, city, cuisine_type, avg_rating, rating_count, latitude, longitude
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
    let candidates: Vec<RestaurantSummary> = rows
        .into_iter()
        .map(|r| RestaurantSummary {
            id: r.try_get("id").unwrap(),
            name: r.try_get("name").unwrap(),
            city: r.try_get("city").unwrap(),
            cuisine_type: r.try_get("cuisine_type").unwrap(),
            avg_rating: r.try_get("avg_rating").unwrap(),
            rating_count: r.try_get("rating_count").unwrap(),
            latitude: r.try_get("latitude").unwrap(),
            longitude: r.try_get("longitude").unwrap(),
        })
        .collect();

    let has_duplicate = !candidates.is_empty();
    Ok(Json(DuplicateCheckResponse { has_duplicate, candidates }))
}
