//! Test utilities — compiled only in test builds.
#![cfg(test)]

use std::sync::Arc;

use sqlx::PgPool;
use uuid::Uuid;

use crate::{
    AppState,
    auth::jwt::{Claims, TokenKind, issue_access_token, issue_refresh_token},
    config::Config,
    jobs::{InProcessQueue, JobQueue},
    llm::provider::build_provider,
    middleware::rate_limit::{new_ip_limiter, new_per_user_limiter},
};

/// Builds a test AppState.
///
/// For tests that don't hit the DB the lazy pool will never actually connect.
/// For tests that DO need a real DB, set the `TEST_DATABASE_URL` environment
/// variable before running (those tests should be marked `#[ignore]` by
/// default so CI doesn't require a live Postgres instance).
pub async fn test_state() -> AppState {
    let db = if let Ok(url) = std::env::var("TEST_DATABASE_URL") {
        PgPool::connect(&url)
            .await
            .expect("TEST_DATABASE_URL connection failed")
    } else {
        PgPool::connect_lazy("postgres://localhost/nonexistent_test_db_remembite")
            .expect("connect_lazy should not fail")
    };

    let config = Arc::new(Config {
        database_url: "postgres://localhost/test".into(),
        jwt_secret: "test-secret-at-least-32-chars-long!".into(),
        jwt_access_expiry_hours: 1,
        jwt_refresh_expiry_days: 7,
        google_client_id: "fake-google-client-id".into(),
        llm_provider: "gemini".into(),
        gemini_api_key: "fake-gemini-key".into(),
        r2_account_id: "fake".into(),
        r2_access_key_id: "fake".into(),
        r2_secret_access_key: "fake".into(),
        r2_bucket: "fake-bucket".into(),
        r2_public_url: "https://fake.r2.dev".into(),
        fcm_service_account_json: "".into(),
        fcm_project_id: "".into(),
        server_host: "127.0.0.1".into(),
        server_port: 8080,
        google_play_package_name: "com.test.remembite".into(),
        google_play_service_account_json: "{}".into(),
        google_pubsub_webhook_token: "test-webhook-token".into(),
        bayesian_prior_weight: 5.0,
    });

    let llm = Arc::from(build_provider("gemini", "fake-gemini-key"));

    let (queue, receiver) = InProcessQueue::new(16);
    let job_queue: Arc<dyn JobQueue> = queue;
    // Keep the channel open — drain jobs without executing them
    tokio::spawn(async move {
        let mut rx = receiver;
        while rx.recv().await.is_some() {}
    });

    // Minimal fake S3 client — won't make real network calls in tests.
    let s3_creds =
        aws_sdk_s3::config::Credentials::new("fake", "fake", None, None, "test");
    let s3_config = aws_sdk_s3::Config::builder()
        .behavior_version(aws_sdk_s3::config::BehaviorVersion::latest())
        .credentials_provider(s3_creds)
        .region(aws_sdk_s3::config::Region::new("auto"))
        .endpoint_url("https://fake.r2.cloudflarestorage.com")
        .force_path_style(true)
        .build();
    let s3 = Arc::new(aws_sdk_s3::Client::from_conf(s3_config));

    AppState {
        db,
        config,
        llm,
        job_queue,
        http: reqwest::Client::new(),
        s3,
        rl_uploads: new_per_user_limiter(10),
        rl_reactions: new_per_user_limiter(100),
        rl_restaurant_create: new_per_user_limiter(10),
        rl_edit_suggestions: new_per_user_limiter(20),
        rl_global_ip: new_ip_limiter(60),
    }
}

/// Issue a valid test access token signed with `config.jwt_secret`.
pub fn test_access_token(pro: bool, admin: bool, config: &Config) -> String {
    issue_access_token(
        Uuid::new_v4(),
        "test@example.com",
        pro,
        admin,
        &config.jwt_secret,
        1,
    )
    .expect("test access token issue failed")
}

/// Issue an access token whose `exp` is in January 1970 — always expired.
///
/// Uses the same `Claims` / `TokenKind` types as production so the signature
/// is valid; only the expiry timestamp is in the past.
pub fn expired_access_token(config: &Config) -> String {
    use jsonwebtoken::{EncodingKey, Header, encode};

    let claims = Claims {
        sub: Uuid::new_v4(),
        email: "expired@example.com".into(),
        pro: false,
        admin: false,
        exp: 1_000_000,  // Unix timestamp = Jan 12 1970 — always in the past
        iat: 999_999,
        kind: TokenKind::Access,
    };

    encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(config.jwt_secret.as_bytes()),
    )
    .expect("expired token encode failed")
}

/// Issue a refresh token.
///
/// Protected API endpoints must reject this (they require `kind == Access`).
pub fn test_refresh_token(config: &Config) -> String {
    issue_refresh_token(
        Uuid::new_v4(),
        "test@example.com",
        false,
        false,
        &config.jwt_secret,
        7,
    )
    .expect("test refresh token issue failed")
}
