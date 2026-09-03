use axum::{Json, extract::State, http::StatusCode};
use serde_json::{Value, json};

use crate::AppState;

/// Returns 503 when the database is unreachable so Docker's `curl -f`
/// healthcheck (which only inspects the status code) actually trips and
/// `restart: unless-stopped` can recover the container.
pub async fn health_check(State(state): State<AppState>) -> (StatusCode, Json<Value>) {
    // Ping database
    let db_ok = sqlx::query("SELECT 1")
        .execute(&state.db)
        .await
        .is_ok();

    let status = if db_ok { StatusCode::OK } else { StatusCode::SERVICE_UNAVAILABLE };
    (
        status,
        Json(json!({
            "status": if db_ok { "ok" } else { "degraded" },
            "database": if db_ok { "ok" } else { "error" },
            "version": env!("CARGO_PKG_VERSION"),
        })),
    )
}
