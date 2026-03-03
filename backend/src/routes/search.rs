use std::net::SocketAddr;

use axum::{
    Json, Router,
    extract::{ConnectInfo, Query, State},
    routing::get,
};

use crate::{
    AppState,
    dto::{DishSearchResult, RestaurantSummary, SearchQuery, SearchResultsResponse},
    error::AppResult,
    middleware::rate_limit::check_ip_limit,
};

pub fn router() -> Router<AppState> {
    Router::new().route("/", get(search))
}

async fn search(
    State(state): State<AppState>,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    Query(params): Query<SearchQuery>,
) -> AppResult<Json<SearchResultsResponse>> {
    check_ip_limit(&state.rl_global_ip, addr.ip())?;

    let q = params.q.trim().to_string();
    if q.is_empty() {
        return Ok(Json(SearchResultsResponse {
            restaurants: vec![],
            dishes: vec![],
        }));
    }

    // Search restaurants by name similarity
    let restaurant_rows = sqlx::query(
        r#"
        SELECT id, name, city, cuisine_type, avg_rating, rating_count, latitude, longitude
        FROM restaurants
        WHERE similarity(name, $1) > 0.15 OR name ILIKE $2
        ORDER BY similarity(name, $1) DESC, rating_count DESC
        LIMIT 5
        "#,
    )
    .bind(&q)
    .bind(format!("%{q}%"))
    .fetch_all(&state.db)
    .await?;

    // Search dishes by name similarity
    let dish_rows = sqlx::query(
        r#"
        SELECT d.id, d.name, d.restaurant_id, r.name as restaurant_name,
               d.category, d.community_score
        FROM dishes d
        JOIN restaurants r ON r.id = d.restaurant_id
        WHERE similarity(d.name, $1) > 0.15 OR d.name ILIKE $2
        ORDER BY similarity(d.name, $1) DESC, d.vote_count DESC
        LIMIT 10
        "#,
    )
    .bind(&q)
    .bind(format!("%{q}%"))
    .fetch_all(&state.db)
    .await?;

    use sqlx::Row;

    let restaurants: Vec<RestaurantSummary> = restaurant_rows
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

    let dishes: Vec<DishSearchResult> = dish_rows
        .into_iter()
        .map(|r| DishSearchResult {
            id: r.try_get("id").unwrap(),
            name: r.try_get("name").unwrap(),
            restaurant_id: r.try_get("restaurant_id").unwrap(),
            restaurant_name: r.try_get("restaurant_name").unwrap(),
            category: r.try_get("category").unwrap(),
            community_score: r.try_get("community_score").unwrap(),
        })
        .collect();

    Ok(Json(SearchResultsResponse { restaurants, dishes }))
}
