#![cfg(test)]

use axum::{
    Router,
    body::Body,
    http::{Request, StatusCode, header},
    routing::get,
};
use tower::ServiceExt;

use crate::{
    AppState,
    auth::middleware::AuthUser,
    error::AppResult,
    test_helpers::{expired_access_token, test_access_token, test_refresh_token, test_state},
};

// Minimal protected handler for testing
async fn protected(_user: AuthUser) -> AppResult<axum::Json<serde_json::Value>> {
    Ok(axum::Json(serde_json::json!({ "ok": true })))
}

async fn build_protected_router() -> (Router, AppState) {
    let state = test_state().await;
    let app = Router::new()
        .route("/protected", get(protected))
        .with_state(state.clone());
    (app, state)
}

#[tokio::test]
async fn valid_access_token_returns_200() {
    let (app, state) = build_protected_router().await;
    let token = test_access_token(false, false, &state.config);

    let resp = app
        .oneshot(
            Request::builder()
                .uri("/protected")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(resp.status(), StatusCode::OK);
}

#[tokio::test]
async fn missing_token_returns_401() {
    let (app, _) = build_protected_router().await;

    let resp = app
        .oneshot(
            Request::builder()
                .uri("/protected")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn expired_token_returns_401() {
    let (app, state) = build_protected_router().await;
    let token = expired_access_token(&state.config);

    let resp = app
        .oneshot(
            Request::builder()
                .uri("/protected")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn refresh_token_rejected_as_access_returns_401() {
    let (app, state) = build_protected_router().await;
    let token = test_refresh_token(&state.config);

    let resp = app
        .oneshot(
            Request::builder()
                .uri("/protected")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn invalid_jwt_returns_401() {
    let (app, _) = build_protected_router().await;

    let resp = app
        .oneshot(
            Request::builder()
                .uri("/protected")
                .header(header::AUTHORIZATION, "Bearer not.a.valid.jwt")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn error_response_contains_no_stack_trace() {
    let (app, _) = build_protected_router().await;

    let resp = app
        .oneshot(
            Request::builder()
                .uri("/protected")
                .header(header::AUTHORIZATION, "Bearer bad.token.here")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);

    let body = axum::body::to_bytes(resp.into_body(), usize::MAX).await.unwrap();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();

    // Structured error only — no implementation details
    assert!(json.get("error").is_some(), "must have 'error' key");
    assert!(json.get("message").is_some(), "must have 'message' key");
    assert!(json.get("stack").is_none(), "must NOT have 'stack' key");
    assert!(json.get("backtrace").is_none(), "must NOT have 'backtrace'");

    let msg = json["message"].as_str().unwrap_or("");
    assert!(!msg.contains("src/"), "must not leak file paths");
    assert!(!msg.contains("panicked"), "must not leak panic info");
}

#[tokio::test]
async fn free_user_on_pro_endpoint_returns_402() {
    // Use the real /users/me/export route which calls user.require_pro()
    use crate::routes;

    let state = test_state().await;
    let token = test_access_token(false, false, &state.config); // pro=false

    let app = Router::new()
        .nest("/users/me", routes::export::router())
        .with_state(state);

    let resp = app
        .oneshot(
            Request::builder()
                .uri("/users/me/export")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(resp.status(), StatusCode::PAYMENT_REQUIRED); // 402
}
