use axum::{
    Json, Router,
    extract::{Path, Query, State},
    http::StatusCode,
    routing::{get, post},
};
use chrono::Utc;
use sqlx::{PgPool, Row};
use uuid::Uuid;

use crate::{
    AppState,
    auth::middleware::AuthUser,
    dto::{
        EditSuggestionCreateRequest, EditSuggestionResponse, EditVoteRequest, EditVoteResponse,
    },
    error::{AppError, AppResult},
    middleware::rate_limit::check_user_limit,
    routes::reports::list_reports_admin,
};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/", get(list_suggestions).post(create_suggestion))
        .route("/:id/vote", post(vote_suggestion))
}

pub fn admin_router() -> Router<AppState> {
    Router::new()
        .route("/edit-suggestions/:id/approve", post(admin_approve))
        .route("/edit-suggestions/:id/reject", post(admin_reject))
        .route("/reports", get(list_reports_admin))
}

// ─────────────────────────────────────────────
// Query params for listing suggestions
// ─────────────────────────────────────────────

#[derive(Debug, serde::Deserialize)]
pub struct ListSuggestionsQuery {
    pub entity_id: Option<Uuid>,
    pub entity_type: Option<String>,
}

// ─────────────────────────────────────────────
// Handlers
// ─────────────────────────────────────────────

async fn create_suggestion(
    State(state): State<AppState>,
    user: AuthUser,
    Json(req): Json<EditSuggestionCreateRequest>,
) -> AppResult<(StatusCode, Json<EditSuggestionResponse>)> {
    check_user_limit(&state.rl_edit_suggestions, user.id)?;

    // Validate entity_type
    if req.entity_type != "restaurant" && req.entity_type != "dish" {
        return Err(AppError::BadRequest(
            "entity_type must be 'restaurant' or 'dish'".to_string(),
        ));
    }

    if req.field.trim().is_empty() {
        return Err(AppError::BadRequest("field is required".to_string()));
    }

    if req.proposed_value.trim().is_empty() {
        return Err(AppError::BadRequest("proposed_value is required".to_string()));
    }

    // Validate field is allowed for entity_type
    validate_field(&req.entity_type, &req.field)?;

    let id = Uuid::new_v4();
    let now = Utc::now();

    sqlx::query(
        r#"
        INSERT INTO edit_suggestions (id, entity_type, entity_id, field, proposed_value, suggested_by)
        VALUES ($1, $2::entity_type, $3, $4, $5, $6)
        "#,
    )
    .bind(id)
    .bind(&req.entity_type)
    .bind(req.entity_id)
    .bind(&req.field)
    .bind(&req.proposed_value)
    .bind(user.id)
    .execute(&state.db)
    .await?;

    Ok((
        StatusCode::CREATED,
        Json(EditSuggestionResponse {
            id,
            entity_type: req.entity_type,
            entity_id: req.entity_id,
            field: req.field,
            proposed_value: req.proposed_value,
            suggested_by: user.id,
            status: "pending".to_string(),
            net_votes: 0,
            created_at: now,
        }),
    ))
}

async fn list_suggestions(
    State(state): State<AppState>,
    Query(params): Query<ListSuggestionsQuery>,
) -> AppResult<Json<Vec<EditSuggestionResponse>>> {
    let rows = match (&params.entity_id, &params.entity_type) {
        (Some(eid), Some(etype)) => {
            sqlx::query(
                r#"
                SELECT id, entity_type::text, entity_id, field, proposed_value, suggested_by,
                       status::text, net_votes, created_at
                FROM edit_suggestions
                WHERE entity_id = $1 AND entity_type = $2::entity_type
                  AND status = 'pending'::edit_status
                ORDER BY created_at DESC
                "#,
            )
            .bind(eid)
            .bind(etype)
            .fetch_all(&state.db)
            .await?
        }
        (Some(eid), None) => {
            sqlx::query(
                r#"
                SELECT id, entity_type::text, entity_id, field, proposed_value, suggested_by,
                       status::text, net_votes, created_at
                FROM edit_suggestions
                WHERE entity_id = $1
                  AND status = 'pending'::edit_status
                ORDER BY created_at DESC
                "#,
            )
            .bind(eid)
            .fetch_all(&state.db)
            .await?
        }
        _ => {
            sqlx::query(
                r#"
                SELECT id, entity_type::text, entity_id, field, proposed_value, suggested_by,
                       status::text, net_votes, created_at
                FROM edit_suggestions
                WHERE status = 'pending'::edit_status
                ORDER BY created_at DESC
                LIMIT 100
                "#,
            )
            .fetch_all(&state.db)
            .await?
        }
    };

    let suggestions = rows
        .into_iter()
        .map(|r| -> Result<EditSuggestionResponse, sqlx::Error> {
            Ok(EditSuggestionResponse {
                id: r.try_get("id")?,
                entity_type: r.try_get::<String, _>("entity_type")?,
                entity_id: r.try_get("entity_id")?,
                field: r.try_get("field")?,
                proposed_value: r.try_get("proposed_value")?,
                suggested_by: r.try_get("suggested_by")?,
                status: r.try_get::<String, _>("status")?,
                net_votes: r.try_get("net_votes")?,
                created_at: r.try_get("created_at")?,
            })
        })
        .collect::<Result<Vec<_>, _>>()?;

    Ok(Json(suggestions))
}

async fn vote_suggestion(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    user: AuthUser,
    Json(req): Json<EditVoteRequest>,
) -> AppResult<Json<EditVoteResponse>> {
    if req.vote != "up" && req.vote != "down" {
        return Err(AppError::BadRequest(
            "vote must be 'up' or 'down'".to_string(),
        ));
    }

    // Fetch suggestion — ensure it exists and is still pending within its window
    let row = sqlx::query(
        r#"
        SELECT id, entity_type::text, entity_id, field, proposed_value, status::text, net_votes, expires_at
        FROM edit_suggestions
        WHERE id = $1
        "#,
    )
    .bind(id)
    .fetch_optional(&state.db)
    .await?
    .ok_or_else(|| AppError::NotFound(format!("Suggestion {id} not found")))?;

    let status: String = row.try_get("status")?;
    if status != "pending" {
        return Err(AppError::BadRequest(format!(
            "Suggestion is already {status}"
        )));
    }

    let expires_at: chrono::DateTime<Utc> = row.try_get("expires_at")?;
    if Utc::now() > expires_at {
        return Err(AppError::BadRequest(
            "Suggestion has expired".to_string(),
        ));
    }

    let mut tx = state.db.begin().await?;

    // Upsert vote (user can change their vote)
    sqlx::query(
        r#"
        INSERT INTO edit_approvals (id, suggestion_id, user_id, vote)
        VALUES ($1, $2, $3, $4::vote_direction)
        ON CONFLICT (suggestion_id, user_id) DO UPDATE SET
            vote = EXCLUDED.vote
        "#,
    )
    .bind(Uuid::new_v4())
    .bind(id)
    .bind(user.id)
    .bind(&req.vote)
    .execute(&mut *tx)
    .await?;

    // Recalculate net_votes
    sqlx::query(
        r#"
        UPDATE edit_suggestions SET
            net_votes = (
                SELECT COALESCE(SUM(CASE WHEN vote = 'up' THEN 1 ELSE -1 END), 0)
                FROM edit_approvals
                WHERE suggestion_id = $1
            ),
            updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(id)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;

    // Re-fetch updated suggestion to check auto-apply condition
    let updated_row = sqlx::query(
        r#"
        SELECT net_votes, expires_at, entity_type::text, entity_id, field, proposed_value
        FROM edit_suggestions
        WHERE id = $1
        "#,
    )
    .bind(id)
    .fetch_one(&state.db)
    .await?;

    let net_votes: i32 = updated_row.try_get("net_votes")?;
    let expires_at: chrono::DateTime<Utc> = updated_row.try_get("expires_at")?;
    let within_window = Utc::now() <= expires_at;

    let applied = if net_votes >= 3 && within_window {
        apply_edit(&state.db, id).await?;
        true
    } else {
        false
    };

    Ok(Json(EditVoteResponse { ok: true, applied }))
}

async fn admin_approve(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    user: AuthUser,
) -> AppResult<Json<EditVoteResponse>> {
    user.require_admin()?;

    // Verify suggestion exists and is pending
    let row = sqlx::query(
        "SELECT id, status::text FROM edit_suggestions WHERE id = $1",
    )
    .bind(id)
    .fetch_optional(&state.db)
    .await?
    .ok_or_else(|| AppError::NotFound(format!("Suggestion {id} not found")))?;

    let status: String = row.try_get("status")?;
    if status != "pending" {
        return Err(AppError::BadRequest(format!(
            "Suggestion is already {status}"
        )));
    }

    apply_edit(&state.db, id).await?;

    Ok(Json(EditVoteResponse { ok: true, applied: true }))
}

async fn admin_reject(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    user: AuthUser,
) -> AppResult<Json<EditVoteResponse>> {
    user.require_admin()?;

    let result = sqlx::query(
        r#"
        UPDATE edit_suggestions
        SET status = 'rejected'::edit_status, updated_at = NOW()
        WHERE id = $1 AND status = 'pending'::edit_status
        "#,
    )
    .bind(id)
    .execute(&state.db)
    .await?;

    if result.rows_affected() == 0 {
        // Either not found or not pending
        let exists = sqlx::query("SELECT id FROM edit_suggestions WHERE id = $1")
            .bind(id)
            .fetch_optional(&state.db)
            .await?;

        if exists.is_none() {
            return Err(AppError::NotFound(format!("Suggestion {id} not found")));
        }

        return Err(AppError::BadRequest(
            "Suggestion is not in pending state".to_string(),
        ));
    }

    Ok(Json(EditVoteResponse { ok: true, applied: false }))
}

// ─────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────

/// Validate that the field is allowed for the given entity_type.
fn validate_field(entity_type: &str, field: &str) -> AppResult<()> {
    let allowed = match entity_type {
        "restaurant" => &["name", "city", "cuisine_type"][..],
        "dish" => &["name", "category"][..],
        _ => {
            return Err(AppError::BadRequest(format!(
                "Unknown entity_type: {entity_type}"
            )))
        }
    };

    if allowed.contains(&field) {
        Ok(())
    } else {
        Err(AppError::BadRequest(format!(
            "Field '{field}' is not editable for entity_type '{entity_type}'"
        )))
    }
}

/// Apply an edit suggestion: update the target table, then mark the suggestion approved.
async fn apply_edit(db: &PgPool, suggestion_id: Uuid) -> AppResult<()> {
    // Fetch the suggestion details
    let row = sqlx::query(
        r#"
        SELECT entity_type::text, entity_id, field, proposed_value
        FROM edit_suggestions
        WHERE id = $1
        "#,
    )
    .bind(suggestion_id)
    .fetch_optional(db)
    .await?
    .ok_or_else(|| AppError::NotFound(format!("Suggestion {suggestion_id} not found")))?;

    let entity_type: String = row.try_get("entity_type")?;
    let entity_id: Uuid = row.try_get("entity_id")?;
    let field: String = row.try_get("field")?;
    let proposed_value: String = row.try_get("proposed_value")?;

    // Apply the change to the correct table using a safe field whitelist
    match (entity_type.as_str(), field.as_str()) {
        ("restaurant", "name") => {
            sqlx::query(
                "UPDATE restaurants SET name = $1, updated_at = NOW() WHERE id = $2",
            )
            .bind(&proposed_value)
            .bind(entity_id)
            .execute(db)
            .await?;
        }
        ("restaurant", "city") => {
            sqlx::query(
                "UPDATE restaurants SET city = $1, updated_at = NOW() WHERE id = $2",
            )
            .bind(&proposed_value)
            .bind(entity_id)
            .execute(db)
            .await?;
        }
        ("restaurant", "cuisine_type") => {
            sqlx::query(
                "UPDATE restaurants SET cuisine_type = $1, updated_at = NOW() WHERE id = $2",
            )
            .bind(&proposed_value)
            .bind(entity_id)
            .execute(db)
            .await?;
        }
        ("dish", "name") => {
            sqlx::query(
                "UPDATE dishes SET name = $1, updated_at = NOW() WHERE id = $2",
            )
            .bind(&proposed_value)
            .bind(entity_id)
            .execute(db)
            .await?;
        }
        ("dish", "category") => {
            sqlx::query(
                "UPDATE dishes SET category = $1, updated_at = NOW() WHERE id = $2",
            )
            .bind(&proposed_value)
            .bind(entity_id)
            .execute(db)
            .await?;
        }
        _ => {
            return Err(AppError::BadRequest(format!(
                "Unknown field '{field}' for entity_type '{entity_type}'"
            )));
        }
    }

    // Mark suggestion as approved — guard prevents double-apply under concurrent calls
    sqlx::query(
        r#"
        UPDATE edit_suggestions
        SET status = 'approved'::edit_status, updated_at = NOW()
        WHERE id = $1 AND status = 'pending'::edit_status
        "#,
    )
    .bind(suggestion_id)
    .execute(db)
    .await?;

    Ok(())
}

// ─────────────────────────────────────────────
// Background expiry loop
// ─────────────────────────────────────────────

/// Runs forever, expiring stale pending suggestions every 60 seconds.
pub async fn run_expiry_loop(db: PgPool) {
    loop {
        tokio::time::sleep(tokio::time::Duration::from_secs(60)).await;

        let result = sqlx::query(
            r#"
            UPDATE edit_suggestions
            SET status = 'expired'::edit_status, updated_at = NOW()
            WHERE status = 'pending'::edit_status AND expires_at < NOW()
            "#,
        )
        .execute(&db)
        .await;

        match result {
            Ok(r) => {
                let expired = r.rows_affected();
                if expired > 0 {
                    tracing::info!("Expired {expired} edit suggestion(s)");
                }
            }
            Err(e) => {
                tracing::error!("Error running expiry loop: {e}");
            }
        }
    }
}
