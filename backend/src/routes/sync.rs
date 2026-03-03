use axum::{Json, Router, extract::State, routing::post};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{AppState, auth::middleware::AuthUser, error::{AppError, AppResult}};

// ── Upload ────────────────────────────────────────────────────────────────────

#[derive(Deserialize)]
pub struct SyncReaction {
    pub dish_id: String,       // UUID as string from Flutter
    pub reaction: String,      // "so_yummy", "tasty", etc.
    pub updated_at: DateTime<Utc>,
}

#[derive(Deserialize)]
pub struct SyncRating {
    pub restaurant_id: String, // UUID as string from Flutter
    pub stars: i16,
    pub updated_at: DateTime<Utc>,
}

#[derive(Deserialize)]
pub struct FullSyncUploadRequest {
    pub reactions: Vec<SyncReaction>,
    pub ratings: Vec<SyncRating>,
}

#[derive(Serialize)]
pub struct SyncUploadResponse {
    pub reactions_upserted: usize,
    pub ratings_upserted: usize,
}

pub async fn upload_full(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<FullSyncUploadRequest>,
) -> AppResult<Json<SyncUploadResponse>> {
    auth.require_pro()?;

    let mut reactions_upserted = 0usize;
    for r in &req.reactions {
        let dish_id = Uuid::parse_str(&r.dish_id)
            .map_err(|_| AppError::BadRequest(format!("Invalid dish_id UUID: {}", r.dish_id)))?;

        let res = sqlx::query(
            r#"
            INSERT INTO dish_reactions (id, user_id, dish_id, reaction, synced_at, updated_at)
            VALUES (uuid_generate_v4(), $1, $2, $3::reaction_type, NOW(), $4)
            ON CONFLICT (user_id, dish_id) DO UPDATE
              SET reaction   = EXCLUDED.reaction,
                  synced_at  = NOW(),
                  updated_at = EXCLUDED.updated_at
              WHERE EXCLUDED.updated_at > dish_reactions.updated_at
            "#,
        )
        .bind(auth.id)
        .bind(dish_id)
        .bind(&r.reaction)
        .bind(r.updated_at)
        .execute(&state.db)
        .await?;
        reactions_upserted += res.rows_affected() as usize;
    }

    let mut ratings_upserted = 0usize;
    for r in &req.ratings {
        let restaurant_id = Uuid::parse_str(&r.restaurant_id)
            .map_err(|_| AppError::BadRequest(format!("Invalid restaurant_id UUID: {}", r.restaurant_id)))?;

        let res = sqlx::query(
            r#"
            INSERT INTO restaurant_ratings (id, user_id, restaurant_id, stars, updated_at)
            VALUES (uuid_generate_v4(), $1, $2, $3, $4)
            ON CONFLICT (user_id, restaurant_id) DO UPDATE
              SET stars      = EXCLUDED.stars,
                  updated_at = EXCLUDED.updated_at
              WHERE EXCLUDED.updated_at > restaurant_ratings.updated_at
            "#,
        )
        .bind(auth.id)
        .bind(restaurant_id)
        .bind(r.stars)
        .bind(r.updated_at)
        .execute(&state.db)
        .await?;
        ratings_upserted += res.rows_affected() as usize;
    }

    Ok(Json(SyncUploadResponse {
        reactions_upserted,
        ratings_upserted,
    }))
}

// ── Download ──────────────────────────────────────────────────────────────────

#[derive(Serialize)]
pub struct SyncReactionDto {
    pub id: String,
    pub dish_id: String,
    pub reaction: String,
    pub updated_at: DateTime<Utc>,
}

#[derive(Serialize)]
pub struct SyncRatingDto {
    pub id: String,
    pub restaurant_id: String,
    pub stars: i16,
    pub updated_at: DateTime<Utc>,
}

#[derive(Serialize)]
pub struct FullSyncDownloadResponse {
    pub reactions: Vec<SyncReactionDto>,
    pub ratings: Vec<SyncRatingDto>,
}

pub async fn download_full(
    State(state): State<AppState>,
    auth: AuthUser,
) -> AppResult<Json<FullSyncDownloadResponse>> {
    auth.require_pro()?;

    let reactions = sqlx::query(
        r#"SELECT id, dish_id, reaction::text as reaction, updated_at FROM dish_reactions WHERE user_id = $1"#,
    )
    .bind(auth.id)
    .fetch_all(&state.db)
    .await?
    .into_iter()
    .map(|r: sqlx::postgres::PgRow| {
        use sqlx::Row;
        SyncReactionDto {
            id: r.get::<Uuid, _>("id").to_string(),
            dish_id: r.get::<Uuid, _>("dish_id").to_string(),
            reaction: r.get("reaction"),
            updated_at: r.get("updated_at"),
        }
    })
    .collect();

    let ratings = sqlx::query(
        r#"SELECT id, restaurant_id, stars, updated_at FROM restaurant_ratings WHERE user_id = $1"#,
    )
    .bind(auth.id)
    .fetch_all(&state.db)
    .await?
    .into_iter()
    .map(|r: sqlx::postgres::PgRow| {
        use sqlx::Row;
        SyncRatingDto {
            id: r.get::<Uuid, _>("id").to_string(),
            restaurant_id: r.get::<Uuid, _>("restaurant_id").to_string(),
            stars: r.get("stars"),
            updated_at: r.get("updated_at"),
        }
    })
    .collect();

    Ok(Json(FullSyncDownloadResponse { reactions, ratings }))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/full", post(upload_full).get(download_full))
}
