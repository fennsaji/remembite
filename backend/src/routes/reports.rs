use axum::{
    Json, Router,
    extract::{Path, State},
    http::StatusCode,
    routing::post,
};
use sqlx::Row;
use uuid::Uuid;

use crate::{
    AppState,
    auth::middleware::AuthUser,
    dto::{ReportActionRequest, ReportActionResponse, ReportCreateRequest, ReportResponse},
    error::{AppError, AppResult},
};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/", post(create_report))
}

pub fn admin_router() -> Router<AppState> {
    Router::new()
        .route("/reports/:id/action", post(action_report))
}

// ─────────────────────────────────────────────
// Handlers
// ─────────────────────────────────────────────

async fn create_report(
    State(state): State<AppState>,
    user: AuthUser,
    Json(req): Json<ReportCreateRequest>,
) -> AppResult<(StatusCode, Json<ReportResponse>)> {
    if req.entity_type != "restaurant" && req.entity_type != "dish" && req.entity_type != "image" {
        return Err(AppError::BadRequest(
            "entity_type must be 'restaurant', 'dish', or 'image'".to_string(),
        ));
    }

    if req.reason.trim().is_empty() {
        return Err(AppError::BadRequest("reason is required".to_string()));
    }

    let id = Uuid::new_v4();
    let now = chrono::Utc::now();

    sqlx::query(
        r#"
        INSERT INTO reports (id, entity_type, entity_id, reported_by, reason)
        VALUES ($1, $2::entity_type, $3, $4, $5)
        "#,
    )
    .bind(id)
    .bind(&req.entity_type)
    .bind(req.entity_id)
    .bind(user.id)
    .bind(&req.reason)
    .execute(&state.db)
    .await?;

    Ok((
        StatusCode::CREATED,
        Json(ReportResponse {
            id,
            entity_type: req.entity_type,
            entity_id: req.entity_id,
            reason: req.reason,
            status: "open".to_string(),
            created_at: now,
        }),
    ))
}

async fn action_report(
    State(state): State<AppState>,
    user: AuthUser,
    Path(report_id): Path<Uuid>,
    Json(req): Json<ReportActionRequest>,
) -> AppResult<Json<ReportActionResponse>> {
    user.require_admin()?;

    if req.action != "resolved" && req.action != "dismissed" {
        return Err(AppError::BadRequest(
            "action must be 'resolved' or 'dismissed'".to_string(),
        ));
    }

    let result = sqlx::query(
        r#"
        UPDATE reports SET status = $1
        WHERE id = $2 AND status = 'open'
        "#,
    )
    .bind(&req.action)
    .bind(report_id)
    .execute(&state.db)
    .await?;

    if result.rows_affected() == 0 {
        return Err(AppError::NotFound("Report not found or already actioned".to_string()));
    }

    Ok(Json(ReportActionResponse {
        ok: true,
        status: req.action,
    }))
}

pub(crate) async fn list_reports_admin(
    State(state): State<AppState>,
    user: AuthUser,
) -> AppResult<Json<Vec<ReportResponse>>> {
    user.require_admin()?;

    let rows = sqlx::query(
        r#"
        SELECT id, entity_type::text, entity_id, reason, status, created_at
        FROM reports
        WHERE status = 'open'
        ORDER BY created_at DESC
        LIMIT 200
        "#,
    )
    .fetch_all(&state.db)
    .await?;

    let reports = rows
        .into_iter()
        .map(|r| -> Result<ReportResponse, sqlx::Error> {
            Ok(ReportResponse {
                id: r.try_get("id")?,
                entity_type: r.try_get::<String, _>("entity_type")?,
                entity_id: r.try_get("entity_id")?,
                reason: r.try_get("reason")?,
                status: r.try_get("status")?,
                created_at: r.try_get("created_at")?,
            })
        })
        .collect::<Result<Vec<_>, _>>()?;

    Ok(Json(reports))
}
