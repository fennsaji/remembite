use axum::{
    Json, Router,
    extract::{Path, State},
    routing::post,
};
use uuid::Uuid;

use crate::{
    AppState,
    auth::middleware::AuthUser,
    dto::{RatingSummaryResponse, RatingUpsertRequest},
    error::{AppError, AppResult},
};

pub fn router() -> Router<AppState> {
    Router::new().route("/", post(upsert_rating))
}

async fn upsert_rating(
    State(state): State<AppState>,
    Path(restaurant_id): Path<Uuid>,
    user: AuthUser,
    Json(req): Json<RatingUpsertRequest>,
) -> AppResult<Json<RatingSummaryResponse>> {
    if req.stars < 1 || req.stars > 5 {
        return Err(AppError::BadRequest("stars must be between 1 and 5".to_string()));
    }

    // Verify restaurant exists
    let exists = sqlx::query("SELECT id FROM restaurants WHERE id = $1")
        .bind(restaurant_id)
        .fetch_optional(&state.db)
        .await?;

    if exists.is_none() {
        return Err(AppError::NotFound(format!("Restaurant {restaurant_id} not found")));
    }

    // Upsert rating in a transaction and recalculate avg
    let mut tx = state.db.begin().await?;

    sqlx::query(
        r#"
        INSERT INTO restaurant_ratings (id, user_id, restaurant_id, stars)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (user_id, restaurant_id) DO UPDATE SET
            stars = EXCLUDED.stars,
            updated_at = NOW()
        "#,
    )
    .bind(Uuid::new_v4())
    .bind(user.id)
    .bind(restaurant_id)
    .bind(req.stars)
    .execute(&mut *tx)
    .await?;

    // Recalculate avg_rating and rating_count on the restaurants row
    sqlx::query(
        r#"
        UPDATE restaurants SET
            avg_rating = (SELECT AVG(stars::float) FROM restaurant_ratings WHERE restaurant_id = $1),
            rating_count = (SELECT COUNT(*) FROM restaurant_ratings WHERE restaurant_id = $1),
            updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(restaurant_id)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;

    // Return updated summary
    let row = sqlx::query(
        "SELECT COALESCE(avg_rating, 0.0) as avg_rating, rating_count FROM restaurants WHERE id = $1",
    )
    .bind(restaurant_id)
    .fetch_one(&state.db)
    .await?;

    use sqlx::Row;
    Ok(Json(RatingSummaryResponse {
        avg_rating: row.try_get("avg_rating")?,
        rating_count: row.try_get::<i32, _>("rating_count")? as i64,
    }))
}
