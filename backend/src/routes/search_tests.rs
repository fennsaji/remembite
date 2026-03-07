#![cfg(test)]

use std::net::SocketAddr;

use axum::{
    body::Body,
    http::{Request, StatusCode, header},
};
use tower::ServiceExt;

use crate::{
    routes,
    test_helpers::{test_access_token, test_state},
};

const INJECTION_PAYLOADS: &[&str] = &[
    "' OR '1'='1",
    "'; DROP TABLE restaurants; --",
    "' UNION SELECT * FROM users --",
    "1; SELECT pg_sleep(5) --",
    "\\x00",
    "admin'--",
    "' OR 1=1 --",
];

#[tokio::test]
#[ignore = "requires TEST_DATABASE_URL"]
async fn search_sql_injection_returns_200_empty_results() {
    let state = test_state().await;
    let token = test_access_token(false, false, &state.config);

    for payload in INJECTION_PAYLOADS {
        let encoded = urlencoding::encode(payload);
        let app = axum::Router::new()
            .nest("/search", routes::search::router())
            .layer(axum::extract::connect_info::MockConnectInfo(
                SocketAddr::from(([127, 0, 0, 1], 0)),
            ))
            .with_state(state.clone());

        let resp = app
            .oneshot(
                Request::builder()
                    .uri(format!("/search?q={encoded}"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(
            resp.status(),
            StatusCode::OK,
            "SQL injection payload '{payload}' returned non-200: {}",
            resp.status()
        );

        let body = axum::body::to_bytes(resp.into_body(), usize::MAX)
            .await
            .unwrap();
        let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
        assert!(
            json.get("restaurants").is_some(),
            "payload '{payload}': missing 'restaurants' key"
        );
        assert!(
            json.get("dishes").is_some(),
            "payload '{payload}': missing 'dishes' key"
        );
    }
}
