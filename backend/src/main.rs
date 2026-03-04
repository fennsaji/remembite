mod auth;
mod config;
mod db;
mod dto;
mod error;
mod jobs;
mod llm;
mod middleware;
mod models;
mod routes;
mod services;

use std::sync::Arc;

use axum::{Router, routing::{get, post}};
use aws_sdk_s3::Client as S3Client;
use sqlx::PgPool;
use tower_http::{cors::CorsLayer, trace::TraceLayer};
use tracing_subscriber::{EnvFilter, fmt, prelude::*};

use crate::{
    config::Config,
    jobs::{InProcessQueue, JobQueue},
    llm::{LlmProvider, provider::build_provider},
    middleware::rate_limit::{
        IpRateLimiter, UserRateLimiter, new_ip_limiter, new_per_user_limiter,
    },
};

/// Shared application state — cloned cheaply per request via Arc.
#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    pub config: Arc<Config>,
    pub llm: Arc<dyn LlmProvider>,
    pub job_queue: Arc<dyn JobQueue>,
    pub http: reqwest::Client,
    pub s3: Arc<S3Client>,
    pub rl_uploads: UserRateLimiter,           // 10/hr
    // Rate limiters
    pub rl_reactions: UserRateLimiter,        // 100/hr
    pub rl_restaurant_create: UserRateLimiter, // 10/hr
    pub rl_edit_suggestions: UserRateLimiter,  // 20/hr
    pub rl_global_ip: IpRateLimiter,           // 60/min (search + unauthenticated)
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Logging
    tracing_subscriber::registry()
        .with(fmt::layer().json())
        .with(EnvFilter::from_default_env())
        .init();

    // Config
    let config = Arc::new(Config::from_env()?);
    tracing::info!("Starting remembite-backend v{}", env!("CARGO_PKG_VERSION"));

    // Database pool
    let db = PgPool::connect(&config.database_url).await?;
    sqlx::migrate!("./migrations").run(&db).await?;
    tracing::info!("Database connected and migrations applied");

    // LLM provider
    let llm: Arc<dyn LlmProvider> =
        Arc::from(build_provider(&config.llm_provider, &config.gemini_api_key));

    // Job queue + worker
    let (queue, receiver) = InProcessQueue::new(512);
    let job_queue: Arc<dyn JobQueue> = queue;

    // S3 client for Cloudflare R2
    let s3_creds = aws_sdk_s3::config::Credentials::new(
        &config.r2_access_key_id,
        &config.r2_secret_access_key,
        None, None, "r2",
    );
    let s3_config = aws_sdk_s3::Config::builder()
        .behavior_version(aws_sdk_s3::config::BehaviorVersion::latest())
        .credentials_provider(s3_creds)
        .region(aws_sdk_s3::config::Region::new("auto"))
        .endpoint_url(format!(
            "https://{}.r2.cloudflarestorage.com",
            config.r2_account_id
        ))
        .force_path_style(true)
        .build();
    let s3 = Arc::new(S3Client::from_conf(s3_config));

    // App state
    let state = AppState {
        db,
        config: config.clone(),
        llm,
        job_queue,
        http: reqwest::Client::new(),
        s3,
        rl_uploads: new_per_user_limiter(10),
        rl_reactions: new_per_user_limiter(100),
        rl_restaurant_create: new_per_user_limiter(10),
        rl_edit_suggestions: new_per_user_limiter(20),
        rl_global_ip: new_ip_limiter(60),
    };

    // Spawn job worker
    let worker_state = Arc::new(state.clone());
    tokio::spawn(jobs::worker::run_worker(receiver, worker_state));

    // Spawn edit suggestion expiry loop
    let expiry_db = state.db.clone();
    tokio::spawn(routes::edit_suggestions::run_expiry_loop(expiry_db));

    // Router
    let app = Router::new()
        // Health
        .route("/health", get(routes::health_check))
        // Auth
        .route("/auth/google", post(routes::auth::google_auth))
        .merge(routes::auth::router())
        // Restaurants
        .nest("/restaurants", routes::restaurants::router())
        // Dishes nested under restaurant
        .nest("/restaurants/:id/dishes", routes::dishes::restaurant_dishes_router())
        // Dishes standalone
        .nest("/dishes", routes::dishes::dishes_router())
        // Ratings
        .nest("/restaurants/:id/ratings", routes::ratings::router())
        // Search
        .nest("/search", routes::search::router())
        // Timeline (under /users/me)
        .nest("/users/me", routes::timeline::router())
        // Export (under /users/me)
        .nest("/users/me", routes::export::router())
        // Payments
        .nest("/payments", routes::payments::router())
        // Webhooks
        .nest("/webhooks", routes::webhooks::router())
        // Sync
        .nest("/sync", routes::sync::router())
        // OCR
        .nest("/ocr", routes::ocr::router())
        // Edit suggestions
        .nest("/edit-suggestions", routes::edit_suggestions::router())
        // Admin routes (approve/reject suggestions, list reports, merge restaurants, report actions, recompute)
        .nest("/admin", routes::edit_suggestions::admin_router()
            .merge(routes::restaurants::admin_router())
            .merge(routes::reports::admin_router())
            .merge(routes::dishes::admin_router())
            .merge(routes::images::admin_router()))
        // Reports
        .nest("/reports", routes::reports::router())
        // Images
        .nest("/images", routes::images::router())
        .layer(TraceLayer::new_for_http())
        .layer(CorsLayer::permissive())
        .with_state(state);

    let addr = format!("{}:{}", config.server_host, config.server_port);
    tracing::info!("Listening on {addr}");
    let listener = tokio::net::TcpListener::bind(&addr).await?;
    axum::serve(listener, app.into_make_service_with_connect_info::<std::net::SocketAddr>()).await?;

    Ok(())
}
