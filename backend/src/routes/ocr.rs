use axum::{Json, Router, extract::State, routing::post};

use crate::{
    AppState,
    auth::middleware::AuthUser,
    dto::{OcrParseRequest, OcrParseResponse, ParsedDishDto},
    error::{AppError, AppResult},
    middleware::rate_limit::check_user_limit,
};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/parse", post(parse_ocr))
}

async fn parse_ocr(
    State(state): State<AppState>,
    user: AuthUser,
    Json(req): Json<OcrParseRequest>,
) -> AppResult<Json<OcrParseResponse>> {
    // Rate limit: reuse edit_suggestions limiter (20/hr per user)
    check_user_limit(&state.rl_edit_suggestions, user.id)?;

    // Reject oversized payloads before hitting the LLM
    if req.raw_text.len() > 50_000 {
        return Err(AppError::BadRequest(
            "raw_text exceeds maximum length of 50,000 characters".to_string(),
        ));
    }

    tracing::info!(
        restaurant_id = %req.restaurant_id,
        text_len = req.raw_text.len(),
        "OCR parse request"
    );

    // Synchronous LLM call per Phase 4 spec. For high-volume menus in future phases,
    // consider converting to async job dispatch with ParseMenuOcr job + FCM notification.
    let parsed = state.llm.parse_menu_ocr(&req.raw_text).await?;

    let dishes = parsed
        .into_iter()
        .map(|d| ParsedDishDto {
            name: d.name,
            price_rupees: d.price_rupees,
            category: d.category,
        })
        .collect();

    Ok(Json(OcrParseResponse { dishes }))
}
