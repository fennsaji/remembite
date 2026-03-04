use std::net::SocketAddr;

use uuid::Uuid;

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

    // Search restaurants — text similarity (50%) + avg_rating (30%) + popularity via log(rating_count) (20%)
    let restaurant_rows = sqlx::query(
        r#"
        SELECT id, name, city, cuisine_type, avg_rating, rating_count, latitude, longitude,
               google_rating, price_level
        FROM restaurants
        WHERE similarity(name, $1) > 0.15 OR name ILIKE $2
        ORDER BY (
            (similarity(name, $1) * 0.5)
            + (COALESCE(avg_rating, 0.0) / 5.0 * 0.3)
            + (LN(1.0 + rating_count) * 0.2)
        ) DESC, rating_count DESC
        LIMIT 5
        "#,
    )
    .bind(&q)
    .bind(format!("%{q}%"))
    .fetch_all(&state.db)
    .await?;

    // Search dishes — grouped by dish name, showing count of restaurants offering it
    // Ranking: text similarity (50%) + avg community_score (30%) + popularity via log(sum vote_count) (20%)
    let dish_rows = sqlx::query(
        r#"
        SELECT
            MAX(d.name) AS name,
            COUNT(DISTINCT r.id)::int AS restaurant_count,
            array_agg(DISTINCT r.id::text || '|' || r.name) AS restaurant_pairs,
            MAX(d.category) AS category,
            AVG(d.community_score) AS avg_community_score
        FROM dishes d
        JOIN restaurants r ON r.id = d.restaurant_id
        WHERE similarity(d.name, $1) > 0.15 OR d.name ILIKE $2
        GROUP BY LOWER(TRIM(d.name))
        ORDER BY (
            (similarity(MAX(d.name), $1) * 0.5)
            + (COALESCE(AVG(d.community_score), 0.0) / 5.0 * 0.3)
            + (LN(1.0 + SUM(d.vote_count)::float) * 0.2)
        ) DESC
        LIMIT 10
        "#,
    )
    .bind(&q)
    .bind(format!("%{q}%"))
    .fetch_all(&state.db)
    .await?;

    use sqlx::Row;

    let mut restaurants: Vec<RestaurantSummary> = Vec::with_capacity(restaurant_rows.len());
    for r in restaurant_rows {
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
            open_now: None,
            price_level: r.try_get("price_level")?,
        });
    }

    let dishes: Vec<DishSearchResult> = dish_rows
        .into_iter()
        .map(|r| -> Result<DishSearchResult, sqlx::Error> {
            let pairs: Vec<String> = r.try_get::<Option<Vec<String>>, _>("restaurant_pairs")?
                .unwrap_or_default();
            let mut restaurant_ids: Vec<Uuid> = Vec::with_capacity(pairs.len());
            let mut restaurant_names: Vec<String> = Vec::with_capacity(pairs.len());
            for pair in &pairs {
                // UUID is always exactly 36 chars; '|' at index 36; name from index 37.
                // Slicing by fixed offset means restaurant names containing '|' are safe.
                if pair.len() < 36 {
                    return Err(sqlx::Error::Decode("restaurant_pairs: pair too short".into()));
                }
                let id = pair[..36].parse::<Uuid>().map_err(|e| sqlx::Error::Decode(Box::new(e)))?;
                let name = if pair.len() > 37 { pair[37..].to_string() } else { String::new() };
                restaurant_ids.push(id);
                restaurant_names.push(name);
            }
            Ok(DishSearchResult {
                name: r.try_get("name")?,
                restaurant_count: r.try_get("restaurant_count")?,
                restaurant_ids,
                restaurant_names,
                category: r.try_get("category")?,
                avg_community_score: r.try_get("avg_community_score")?,
            })
        })
        .collect::<Result<Vec<_>, _>>()?;

    Ok(Json(SearchResultsResponse { restaurants, dishes }))
}
