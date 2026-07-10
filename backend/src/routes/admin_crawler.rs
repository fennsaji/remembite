use axum::{
    Json, Router,
    extract::{Path, State},
    http::StatusCode,
    routing::{get, post},
};
use sqlx::Row;

use crate::{
    AppState,
    auth::middleware::AuthUser,
    dto::CrawlRunResponse,
    error::{AppError, AppResult},
};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/crawl", post(trigger_all))
        .route("/crawl/runs", get(list_runs))
        .route("/crawl/:city", post(trigger_city))
}

/// POST /admin/crawl — trigger full crawl for all cities (background, returns immediately)
async fn trigger_all(
    State(state): State<AppState>,
    user: AuthUser,
) -> AppResult<(StatusCode, Json<serde_json::Value>)> {
    user.require_admin()?;

    if state.config.google_places_api_key.is_empty() {
        return Err(AppError::BadRequest(
            "GOOGLE_PLACES_API_KEY not configured".to_string(),
        ));
    }

    if state.crawler.has_running_crawl().await? {
        return Err(AppError::Conflict(
            "A crawl is already running — wait for it to finish".to_string(),
        ));
    }

    let crawler = state.crawler.clone();
    tokio::spawn(async move {
        crawler.run_all_cities().await;
    });

    Ok((
        StatusCode::ACCEPTED,
        Json(serde_json::json!({ "ok": true, "message": "crawl started for all cities" })),
    ))
}

/// POST /admin/crawl/:city — trigger crawl for one city
async fn trigger_city(
    State(state): State<AppState>,
    user: AuthUser,
    Path(city): Path<String>,
) -> AppResult<(StatusCode, Json<serde_json::Value>)> {
    user.require_admin()?;

    if state.config.google_places_api_key.is_empty() {
        return Err(AppError::BadRequest(
            "GOOGLE_PLACES_API_KEY not configured".to_string(),
        ));
    }

    if state.crawler.has_running_crawl().await? {
        return Err(AppError::Conflict(
            "A crawl is already running — wait for it to finish".to_string(),
        ));
    }

    let crawler = state.crawler.clone();
    let city_bg = city.clone();
    tokio::spawn(async move {
        if let Err(e) = crawler.crawl_city(&city_bg).await {
            tracing::error!(city = %city_bg, "manual city crawl failed: {e}");
        }
    });

    Ok((
        StatusCode::ACCEPTED,
        Json(serde_json::json!({ "ok": true, "city": city })),
    ))
}

/// GET /admin/crawl/runs — list 20 most recent crawl runs
async fn list_runs(
    State(state): State<AppState>,
    user: AuthUser,
) -> AppResult<Json<Vec<CrawlRunResponse>>> {
    user.require_admin()?;

    let rows = sqlx::query(
        r#"
        SELECT id, city, status, restaurants_found, dishes_found, started_at, completed_at
        FROM crawl_runs
        ORDER BY started_at DESC
        LIMIT 20
        "#,
    )
    .fetch_all(&state.db)
    .await?;

    let runs = rows
        .into_iter()
        .map(|r| -> Result<CrawlRunResponse, sqlx::Error> {
            Ok(CrawlRunResponse {
                id: r.try_get("id")?,
                city: r.try_get("city")?,
                status: r.try_get("status")?,
                restaurants_found: r.try_get("restaurants_found")?,
                dishes_found: r.try_get("dishes_found")?,
                started_at: r.try_get("started_at")?,
                completed_at: r.try_get("completed_at")?,
            })
        })
        .collect::<Result<Vec<_>, _>>()?;

    Ok(Json(runs))
}
