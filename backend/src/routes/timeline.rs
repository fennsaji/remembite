use axum::{Json, Router, extract::State, routing::get};
use std::collections::BTreeMap;

use crate::{
    AppState,
    auth::middleware::AuthUser,
    dto::{DishReactionItem, TimelineEntry, TimelineResponse},
    error::AppResult,
};

pub fn router() -> Router<AppState> {
    Router::new().route("/timeline", get(get_timeline))
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

    // Group by (restaurant_id, visit_date)
    // Key: (restaurant_id, visit_date, restaurant_name)
    let mut groups: BTreeMap<(String, String), (String, Vec<DishReactionItem>)> = BTreeMap::new();

    for row in rows {
        let restaurant_id: uuid::Uuid = row.try_get("restaurant_id")?;
        let restaurant_name: String = row.try_get("restaurant_name")?;
        let visit_date: chrono::NaiveDate = row.try_get("visit_date")?;
        let date_str = visit_date.format("%Y-%m-%d").to_string();

        let key = (restaurant_id.to_string(), date_str.clone());
        let entry = groups
            .entry(key)
            .or_insert_with(|| (restaurant_name.clone(), vec![]));

        entry.1.push(DishReactionItem {
            dish_id: row.try_get("dish_id")?,
            dish_name: row.try_get("dish_name")?,
            reaction: row.try_get("reaction")?,
            reacted_at: row.try_get("reacted_at")?,
        });
    }

    // Convert to sorted entries (newest first by key — BTreeMap is sorted ascending so reverse)
    let entries: Vec<TimelineEntry> = groups
        .into_iter()
        .rev()
        .map(|((restaurant_id_str, date), (restaurant_name, reactions))| TimelineEntry {
            restaurant_id: restaurant_id_str.parse().unwrap(),
            restaurant_name,
            date,
            reactions,
        })
        .collect();

    Ok(Json(TimelineResponse { entries }))
}
