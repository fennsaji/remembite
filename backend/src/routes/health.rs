use axum::{Json, extract::State};
use serde_json::{Value, json};

use crate::AppState;

pub async fn health_check(State(state): State<AppState>) -> Json<Value> {
    // Ping database
    let db_ok = sqlx::query("SELECT 1")
        .execute(&state.db)
        .await
        .is_ok();

    Json(json!({
        "status": if db_ok { "ok" } else { "degraded" },
        "database": if db_ok { "ok" } else { "error" },
        "version": env!("CARGO_PKG_VERSION"),
    }))
}
