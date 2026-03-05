// backend/src/routes/access_control_tests.rs
#![cfg(test)]

/// HTTP-level access control tests for the export endpoint.
/// Tests that private endpoints enforce authentication and Pro gating.
///
/// The fake DB in test_state() (PgPool::connect_lazy) will fail on any real
/// query. Tests that expect 401/402 complete before any DB query, so no real
/// DB is needed.

use axum::{
    body::Body,
    http::{Request, StatusCode, header},
};
use tower::ServiceExt;

use crate::{
    routes,
    test_helpers::{test_access_token, test_state},
};

#[tokio::test]
async fn export_endpoint_requires_auth() {
    let state = test_state().await;
    let app = axum::Router::new()
        .nest("/users/me", routes::export::router())
        .with_state(state);

    let resp = app
        .oneshot(
            Request::builder()
                .uri("/users/me/export")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn export_endpoint_requires_pro() {
    let state = test_state().await;
    let token = test_access_token(false, false, &state.config); // free user
    let app = axum::Router::new()
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

    assert_eq!(resp.status(), StatusCode::PAYMENT_REQUIRED);
}

#[tokio::test]
async fn export_returns_structured_json_not_stack_trace() {
    // Pro user against fake DB — the handler will fail on the first DB query
    // and return a structured error. Verify it's valid JSON with no stack trace.
    let state = test_state().await;
    let token = test_access_token(true, false, &state.config); // pro user
    let app = axum::Router::new()
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

    // With a fake DB (no TEST_DATABASE_URL) this returns 500; with a real DB it
    // returns 200. Either way the response must be structured JSON with no stack trace.
    let status = resp.status();
    assert!(
        status == StatusCode::OK || status == StatusCode::INTERNAL_SERVER_ERROR,
        "Expected 200 or 500, got {status}"
    );

    let body = axum::body::to_bytes(resp.into_body(), usize::MAX)
        .await
        .unwrap();
    let json: serde_json::Value = serde_json::from_slice(&body)
        .expect("Response body must be valid JSON — never a raw stack trace or HTML");

    assert!(
        json.get("stack").is_none(),
        "Response must not leak stack traces: {json}"
    );
    assert!(
        json.get("backtrace").is_none(),
        "Response must not leak backtraces: {json}"
    );

    // No file paths leaked in the message field
    if let Some(msg) = json.get("message").and_then(|v| v.as_str()) {
        assert!(
            !msg.contains("src/"),
            "Error message must not leak source paths: {msg}"
        );
    }
}
