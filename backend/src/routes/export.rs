use axum::{Json, Router, extract::State, routing::get};
use serde::Serialize;
use serde_json::Value;
use sqlx::Row;

use crate::{AppState, auth::middleware::AuthUser, error::AppResult};

pub fn router() -> Router<AppState> {
    Router::new().route("/export", get(export_user_data))
}

#[derive(Serialize)]
struct ExportResponse {
    reactions: Vec<Value>,
    ratings: Vec<Value>,
    notes: Vec<Value>,
    favorites: Vec<Value>,
    restaurants: Vec<Value>,
}

async fn export_user_data(
    State(state): State<AppState>,
    user: AuthUser,
) -> AppResult<Json<ExportResponse>> {
    user.require_pro()?;

    // Reactions
    let reactions: Vec<Value> = sqlx::query(
        r#"
        SELECT dr.dish_id::text, d.name as dish_name, dr.reaction::text,
               r.id::text as restaurant_id, r.name as restaurant_name,
               dr.updated_at
        FROM dish_reactions dr
        JOIN dishes d ON d.id = dr.dish_id
        JOIN restaurants r ON r.id = d.restaurant_id
        WHERE dr.user_id = $1
        ORDER BY dr.updated_at DESC
        "#,
    )
    .bind(user.id)
    .fetch_all(&state.db)
    .await?
    .into_iter()
    .map(|row| {
        serde_json::json!({
            "dish_id": row.get::<String, _>("dish_id"),
            "dish_name": row.get::<String, _>("dish_name"),
            "reaction": row.get::<String, _>("reaction"),
            "restaurant_id": row.get::<String, _>("restaurant_id"),
            "restaurant_name": row.get::<String, _>("restaurant_name"),
            "reacted_at": row.get::<chrono::DateTime<chrono::Utc>, _>("updated_at").to_rfc3339(),
        })
    })
    .collect();

    // Ratings
    let ratings: Vec<Value> = sqlx::query(
        r#"
        SELECT rr.restaurant_id::text, r.name as restaurant_name,
               rr.stars, rr.updated_at
        FROM restaurant_ratings rr
        JOIN restaurants r ON r.id = rr.restaurant_id
        WHERE rr.user_id = $1
        ORDER BY rr.updated_at DESC
        "#,
    )
    .bind(user.id)
    .fetch_all(&state.db)
    .await?
    .into_iter()
    .map(|row| {
        serde_json::json!({
            "restaurant_id": row.get::<String, _>("restaurant_id"),
            "restaurant_name": row.get::<String, _>("restaurant_name"),
            "stars": row.get::<i16, _>("stars"),
            "rated_at": row.get::<chrono::DateTime<chrono::Utc>, _>("updated_at").to_rfc3339(),
        })
    })
    .collect();

    // Notes — table not yet migrated; return empty for forward-compatibility
    let notes: Vec<Value> = vec![];

    // Favorites
    let favorites: Vec<Value> = sqlx::query(
        r#"
        SELECT df.dish_id::text, d.name as dish_name,
               r.id::text as restaurant_id, r.name as restaurant_name,
               df.created_at
        FROM favorites df
        JOIN dishes d ON d.id = df.dish_id
        JOIN restaurants r ON r.id = d.restaurant_id
        WHERE df.user_id = $1
        ORDER BY df.created_at DESC
        "#,
    )
    .bind(user.id)
    .fetch_all(&state.db)
    .await?
    .into_iter()
    .map(|row| {
        serde_json::json!({
            "dish_id": row.get::<String, _>("dish_id"),
            "dish_name": row.get::<String, _>("dish_name"),
            "restaurant_id": row.get::<String, _>("restaurant_id"),
            "restaurant_name": row.get::<String, _>("restaurant_name"),
            "favorited_at": row.get::<chrono::DateTime<chrono::Utc>, _>("created_at").to_rfc3339(),
        })
    })
    .collect();

    // Restaurants (visited = have a reaction or rating from user)
    let restaurants: Vec<Value> = sqlx::query(
        r#"
        SELECT DISTINCT r.id::text, r.name, r.city, r.cuisine_type,
               r.latitude, r.longitude
        FROM restaurants r
        WHERE EXISTS (
            SELECT 1 FROM dishes d
            JOIN dish_reactions dr ON dr.dish_id = d.id
            WHERE d.restaurant_id = r.id AND dr.user_id = $1
        )
        OR EXISTS (
            SELECT 1 FROM restaurant_ratings rr
            WHERE rr.restaurant_id = r.id AND rr.user_id = $1
        )
        ORDER BY r.name
        "#,
    )
    .bind(user.id)
    .fetch_all(&state.db)
    .await?
    .into_iter()
    .map(|row| {
        serde_json::json!({
            "id": row.get::<String, _>("id"),
            "name": row.get::<String, _>("name"),
            "city": row.get::<String, _>("city"),
            "cuisine_type": row.get::<Option<String>, _>("cuisine_type"),
            "latitude": row.get::<f64, _>("latitude"),
            "longitude": row.get::<f64, _>("longitude"),
        })
    })
    .collect();

    Ok(Json(ExportResponse { reactions, ratings, notes, favorites, restaurants }))
}
