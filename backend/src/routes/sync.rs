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

const VALID_REACTIONS: [&str; 5] = ["so_yummy", "tasty", "pretty_good", "meh", "never_again"];

pub async fn upload_full(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<FullSyncUploadRequest>,
) -> AppResult<Json<SyncUploadResponse>> {
    auth.require_pro()?;

    // Validate everything up front so a bad row 400s before any write happens,
    // rather than mid-batch.
    for r in &req.reactions {
        Uuid::parse_str(&r.dish_id)
            .map_err(|_| AppError::BadRequest(format!("Invalid dish_id UUID: {}", r.dish_id)))?;
        if !VALID_REACTIONS.contains(&r.reaction.as_str()) {
            return Err(AppError::BadRequest(format!("Invalid reaction: {}", r.reaction)));
        }
    }
    for r in &req.ratings {
        Uuid::parse_str(&r.restaurant_id).map_err(|_| {
            AppError::BadRequest(format!("Invalid restaurant_id UUID: {}", r.restaurant_id))
        })?;
        if !(1..=5).contains(&r.stars) {
            return Err(AppError::BadRequest(format!(
                "stars must be between 1 and 5, got {}",
                r.stars
            )));
        }
    }

    // Single transaction: a dish_id/restaurant_id that doesn't exist on the
    // server (FK violation — e.g. a locally-created row never synced) fails
    // the whole batch atomically instead of committing everything before it
    // and silently dropping the rest.
    let mut tx = state.db.begin().await?;

    let mut reactions_upserted = 0usize;
    for r in &req.reactions {
        let dish_id = Uuid::parse_str(&r.dish_id).expect("validated above");

        let insert_result = sqlx::query(
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
        .execute(&mut *tx)
        .await;

        let res = map_fk_violation(insert_result, "dish_id does not exist on the server")?;
        reactions_upserted += res.rows_affected() as usize;
    }

    let mut ratings_upserted = 0usize;
    for r in &req.ratings {
        let restaurant_id = Uuid::parse_str(&r.restaurant_id).expect("validated above");

        let insert_result = sqlx::query(
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
        .execute(&mut *tx)
        .await;

        let res = map_fk_violation(insert_result, "restaurant_id does not exist on the server")?;
        ratings_upserted += res.rows_affected() as usize;
    }

    tx.commit().await?;

    Ok(Json(SyncUploadResponse {
        reactions_upserted,
        ratings_upserted,
    }))
}

/// FK/check-constraint violations from bad client data are a 400, not a 500 —
/// everything else (connection errors, etc.) still propagates as-is.
fn map_fk_violation(
    result: Result<sqlx::postgres::PgQueryResult, sqlx::Error>,
    message: &str,
) -> AppResult<sqlx::postgres::PgQueryResult> {
    if let Err(sqlx::Error::Database(db_err)) = &result {
        if db_err.is_foreign_key_violation() || db_err.is_check_violation() {
            return Err(AppError::BadRequest(message.to_string()));
        }
    }
    Ok(result?)
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

#[cfg(test)]
mod tests {
    use crate::auth::middleware::AuthUser;
    use crate::error::AppError;
    use uuid::Uuid;

    fn make_user(pro: bool) -> AuthUser {
        AuthUser {
            id: Uuid::new_v4(),
            email: "sync_test@test.com".to_string(),
            pro,
            admin: false,
        }
    }

    /// upload_full begins with `auth.require_pro()?` — verify that a non-Pro
    /// user would be rejected before any DB work is attempted.
    #[test]
    fn upload_full_requires_pro() {
        let user = make_user(false);
        assert!(
            matches!(user.require_pro(), Err(AppError::UpgradeRequired)),
            "POST /sync/full must return UpgradeRequired for non-Pro users"
        );
    }

    /// A Pro user must pass the require_pro gate for upload_full.
    #[test]
    fn upload_full_allows_pro_user() {
        let user = make_user(true);
        assert!(
            user.require_pro().is_ok(),
            "POST /sync/full must not reject Pro users"
        );
    }

    /// download_full also begins with `auth.require_pro()?` — same enforcement.
    #[test]
    fn download_full_requires_pro() {
        let user = make_user(false);
        assert!(
            matches!(user.require_pro(), Err(AppError::UpgradeRequired)),
            "GET /sync/full must return UpgradeRequired for non-Pro users"
        );
    }

    /// A Pro user must pass the require_pro gate for download_full.
    #[test]
    fn download_full_allows_pro_user() {
        let user = make_user(true);
        assert!(
            user.require_pro().is_ok(),
            "GET /sync/full must not reject Pro users"
        );
    }
}
