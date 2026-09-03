use axum::{
    Json, Router,
    extract::{Query, State},
    routing::post,
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{AppState, auth::middleware::AuthUser, error::{AppError, AppResult}};

// ── Upload ────────────────────────────────────────────────────────────────────

#[derive(Deserialize)]
pub struct SyncReaction {
    pub dish_id: String,       // UUID as string from Flutter
    pub reaction: String,      // "so_yummy", "tasty", etc.
    #[serde(default)]
    pub notes: Option<String>, // private note; None never erases an existing one
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
            INSERT INTO dish_reactions (id, user_id, dish_id, reaction, notes, synced_at, updated_at)
            VALUES (uuid_generate_v4(), $1, $2, $3::reaction_type, $4, NOW(), $5)
            ON CONFLICT (user_id, dish_id) DO UPDATE
              SET reaction   = EXCLUDED.reaction,
                  notes      = COALESCE(EXCLUDED.notes, dish_reactions.notes),
                  synced_at  = NOW(),
                  updated_at = EXCLUDED.updated_at
              WHERE EXCLUDED.updated_at > dish_reactions.updated_at
            "#,
        )
        .bind(auth.id)
        .bind(dish_id)
        .bind(&r.reaction)
        .bind(&r.notes)
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
    pub notes: Option<String>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Serialize)]
pub struct SyncRatingDto {
    pub id: String,
    pub restaurant_id: String,
    pub stars: i16,
    pub updated_at: DateTime<Utc>,
}

/// Cursor + page-size params for the incremental download.
///
/// All fields are optional so an older client that calls `GET /sync/full`
/// with no query string keeps working: it gets a full download, just paged.
#[derive(Deserialize)]
pub struct SyncDownloadQuery {
    /// Only return rows strictly newer than this point. RFC3339.
    pub since: Option<DateTime<Utc>>,
    /// Tie-breaker half of the compound cursor: with `since`, rows are
    /// filtered on `(updated_at, id) > (since, since_id)`. Sent back by the
    /// server as `next_since_id`. Absent → plain `updated_at > since`.
    pub since_id: Option<Uuid>,
    /// Page size, per collection. Default 500, clamped to 1..=2000.
    pub limit: Option<i64>,
}

pub const DEFAULT_SYNC_LIMIT: i64 = 500;
pub const MAX_SYNC_LIMIT: i64 = 2000;

/// Clamp a client-supplied page size into 1..=MAX_SYNC_LIMIT, defaulting when
/// absent. A zero or negative limit would otherwise produce an endless
/// `has_more` loop on the client.
pub fn clamp_limit(requested: Option<i64>) -> i64 {
    requested.unwrap_or(DEFAULT_SYNC_LIMIT).clamp(1, MAX_SYNC_LIMIT)
}

/// One row's position in the total order the download pages through.
pub type Cursor = (DateTime<Utc>, Uuid);

/// Pick the cursor to hand back to the client given the last row seen in each
/// collection and whether each still has rows queued.
///
/// The two collections live in different tables but share one cursor, so the
/// next cursor must not skip past anything either of them still owes:
///   * both still have rows  → the *minimum* of the two last rows. The other
///     collection re-sends a few rows next page; upserts are idempotent so
///     that is harmless, and nothing is ever lost.
///   * only one has rows     → that collection's last row (the exhausted one
///     has nothing beyond it by definition).
///   * neither has rows      → the maximum seen, so a later resync starts
///     from the true high-water mark. `None` when the page was empty, in
///     which case the caller keeps its previous cursor.
pub fn next_cursor(
    last_reaction: Option<Cursor>,
    reactions_more: bool,
    last_rating: Option<Cursor>,
    ratings_more: bool,
) -> Option<Cursor> {
    match (reactions_more, ratings_more) {
        (true, true) => match (last_reaction, last_rating) {
            (Some(a), Some(b)) => Some(a.min(b)),
            (a, b) => a.or(b),
        },
        (true, false) => last_reaction.or(last_rating),
        (false, true) => last_rating.or(last_reaction),
        (false, false) => match (last_reaction, last_rating) {
            (Some(a), Some(b)) => Some(a.max(b)),
            (a, b) => a.or(b),
        },
    }
}

#[derive(Serialize)]
pub struct FullSyncDownloadResponse {
    // Existing fields — unchanged shape for older clients.
    pub reactions: Vec<SyncReactionDto>,
    pub ratings: Vec<SyncRatingDto>,
    // Additive cursor fields. Older clients ignore them.
    /// Feed back as `?since=` on the next call. `None` only when the page was
    /// empty (client should keep whatever cursor it already had).
    pub next_since: Option<DateTime<Utc>>,
    /// Feed back as `?since_id=` alongside `next_since`.
    pub next_since_id: Option<Uuid>,
    /// True when at least one collection filled its page — call again.
    pub has_more: bool,
}

pub async fn download_full(
    State(state): State<AppState>,
    auth: AuthUser,
    Query(q): Query<SyncDownloadQuery>,
) -> AppResult<Json<FullSyncDownloadResponse>> {
    auth.require_pro()?;

    let limit = clamp_limit(q.limit);
    // Compound cursor. When since_id is absent (first page, or an older
    // client), the id half degrades to the zero UUID so the comparison is
    // just `updated_at > since`.
    let since = q.since;
    let since_id = q.since_id.unwrap_or(Uuid::nil());

    // (updated_at, id) row-value comparison gives a stable total order across
    // rows sharing a timestamp — plain `updated_at > since` would drop ties.
    let reaction_rows = sqlx::query(
        r#"SELECT id, dish_id, reaction::text as reaction, notes, updated_at
             FROM dish_reactions
            WHERE user_id = $1
              AND ($2::timestamptz IS NULL OR (updated_at, id) > ($2, $3))
            ORDER BY updated_at ASC, id ASC
            LIMIT $4"#,
    )
    .bind(auth.id)
    .bind(since)
    .bind(since_id)
    .bind(limit)
    .fetch_all(&state.db)
    .await?;

    let rating_rows = sqlx::query(
        r#"SELECT id, restaurant_id, stars, updated_at
             FROM restaurant_ratings
            WHERE user_id = $1
              AND ($2::timestamptz IS NULL OR (updated_at, id) > ($2, $3))
            ORDER BY updated_at ASC, id ASC
            LIMIT $4"#,
    )
    .bind(auth.id)
    .bind(since)
    .bind(since_id)
    .bind(limit)
    .fetch_all(&state.db)
    .await?;

    let reactions_more = reaction_rows.len() as i64 == limit;
    let ratings_more = rating_rows.len() as i64 == limit;

    use sqlx::Row;
    let reactions: Vec<SyncReactionDto> = reaction_rows
        .into_iter()
        .map(|r: sqlx::postgres::PgRow| SyncReactionDto {
            id: r.get::<Uuid, _>("id").to_string(),
            dish_id: r.get::<Uuid, _>("dish_id").to_string(),
            reaction: r.get("reaction"),
            notes: r.get("notes"),
            updated_at: r.get("updated_at"),
        })
        .collect();

    let ratings: Vec<SyncRatingDto> = rating_rows
        .into_iter()
        .map(|r: sqlx::postgres::PgRow| SyncRatingDto {
            id: r.get::<Uuid, _>("id").to_string(),
            restaurant_id: r.get::<Uuid, _>("restaurant_id").to_string(),
            stars: r.get("stars"),
            updated_at: r.get("updated_at"),
        })
        .collect();

    let last_reaction = reactions
        .last()
        .map(|r| (r.updated_at, Uuid::parse_str(&r.id).unwrap_or(Uuid::nil())));
    let last_rating = ratings
        .last()
        .map(|r| (r.updated_at, Uuid::parse_str(&r.id).unwrap_or(Uuid::nil())));

    let cursor = next_cursor(last_reaction, reactions_more, last_rating, ratings_more);

    Ok(Json(FullSyncDownloadResponse {
        reactions,
        ratings,
        next_since: cursor.map(|c| c.0),
        next_since_id: cursor.map(|c| c.1),
        has_more: reactions_more || ratings_more,
    }))
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

    // ── Cursor / paging ───────────────────────────────────────────────────

    use super::{DEFAULT_SYNC_LIMIT, MAX_SYNC_LIMIT, clamp_limit, next_cursor};
    use chrono::{DateTime, TimeZone, Utc};

    fn ts(secs: i64) -> DateTime<Utc> {
        Utc.timestamp_opt(secs, 0).unwrap()
    }

    #[test]
    fn clamp_limit_defaults_when_absent() {
        assert_eq!(clamp_limit(None), DEFAULT_SYNC_LIMIT);
    }

    #[test]
    fn clamp_limit_caps_at_max() {
        assert_eq!(clamp_limit(Some(999_999)), MAX_SYNC_LIMIT);
        assert_eq!(clamp_limit(Some(MAX_SYNC_LIMIT)), MAX_SYNC_LIMIT);
    }

    #[test]
    fn clamp_limit_rejects_zero_and_negative() {
        // A limit of 0 would return an empty page forever while has_more
        // stayed true — the client would spin.
        assert_eq!(clamp_limit(Some(0)), 1);
        assert_eq!(clamp_limit(Some(-10)), 1);
    }

    #[test]
    fn clamp_limit_passes_through_valid_values() {
        assert_eq!(clamp_limit(Some(1)), 1);
        assert_eq!(clamp_limit(Some(250)), 250);
    }

    #[test]
    fn next_cursor_empty_page_is_none() {
        assert_eq!(next_cursor(None, false, None, false), None);
    }

    #[test]
    fn next_cursor_takes_min_when_both_have_more() {
        let a = (ts(100), Uuid::nil());
        let b = (ts(50), Uuid::nil());
        // Advancing to the later of the two would skip the ratings still owed.
        assert_eq!(next_cursor(Some(a), true, Some(b), true), Some(b));
    }

    #[test]
    fn next_cursor_takes_max_when_both_exhausted() {
        let a = (ts(100), Uuid::nil());
        let b = (ts(50), Uuid::nil());
        assert_eq!(next_cursor(Some(a), false, Some(b), false), Some(a));
    }

    #[test]
    fn next_cursor_follows_the_collection_that_has_more() {
        let a = (ts(100), Uuid::nil());
        let b = (ts(500), Uuid::nil());
        // Ratings are exhausted, so nothing lies beyond them: safe to sit at
        // the reactions cursor even though it is older.
        assert_eq!(next_cursor(Some(a), true, Some(b), false), Some(a));
        assert_eq!(next_cursor(Some(b), false, Some(a), true), Some(a));
    }

    #[test]
    fn next_cursor_breaks_ties_on_id() {
        let lo = Uuid::parse_str("00000000-0000-0000-0000-000000000001").unwrap();
        let hi = Uuid::parse_str("00000000-0000-0000-0000-0000000000ff").unwrap();
        // Same timestamp: the id half decides, so a page boundary landing in
        // the middle of a tie group cannot lose or repeat rows.
        assert_eq!(
            next_cursor(Some((ts(10), hi)), true, Some((ts(10), lo)), true),
            Some((ts(10), lo))
        );
    }

    #[test]
    fn next_cursor_handles_one_empty_collection() {
        let a = (ts(100), Uuid::nil());
        assert_eq!(next_cursor(Some(a), true, None, false), Some(a));
        assert_eq!(next_cursor(None, false, Some(a), true), Some(a));
    }
}
