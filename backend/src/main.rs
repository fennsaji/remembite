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

#[cfg(test)]
mod test_helpers;

use std::sync::Arc;

use axum::{Router, extract::DefaultBodyLimit, routing::{get, post}};
use aws_sdk_s3::Client as S3Client;
use sqlx::PgPool;
use tower_http::{cors::{AllowOrigin, CorsLayer}, trace::TraceLayer};
use tracing_subscriber::{EnvFilter, fmt, prelude::*};

use crate::{
    config::Config,
    jobs::{InProcessQueue, JobQueue},
    llm::{LlmProvider, provider::build_provider},
    middleware::rate_limit::{
        IpRateLimiter, UserRateLimiter, new_ip_limiter, new_per_user_limiter,
    },
    services::crawler::CrawlerService,
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
    pub crawler: Arc<CrawlerService>,
    pub rl_uploads: UserRateLimiter,           // 10/hr
    // Rate limiters
    pub rl_reactions: UserRateLimiter,        // 100/hr
    pub rl_restaurant_create: UserRateLimiter, // 10/hr
    pub rl_edit_suggestions: UserRateLimiter,  // 20/hr
    pub rl_reports: UserRateLimiter,           // 20/hr
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

    // Shared outbound HTTP client (AppState + crawler)
    let http = reqwest::Client::new();

    // Crawler service (restaurant seeding + lazy Place Details enrichment)
    let crawler = Arc::new(CrawlerService::new(
        db.clone(),
        http.clone(),
        llm.clone(),
        config.clone(),
        job_queue.clone(),
    ));

    // App state
    let state = AppState {
        db,
        config: config.clone(),
        llm,
        job_queue,
        http,
        s3,
        crawler: crawler.clone(),
        rl_uploads: new_per_user_limiter(10),
        rl_reactions: new_per_user_limiter(100),
        rl_restaurant_create: new_per_user_limiter(10),
        rl_edit_suggestions: new_per_user_limiter(20),
        rl_reports: new_per_user_limiter(20),
        rl_global_ip: new_ip_limiter(60),
    };

    // governor's keyed limiters keep an entry per key forever unless pruned —
    // the IP-keyed one sees every scanner/bot that touches /search, so sweep
    // idle keys hourly to keep memory bounded.
    {
        let s = state.clone();
        tokio::spawn(async move {
            loop {
                tokio::time::sleep(std::time::Duration::from_secs(3600)).await;
                for l in [
                    &s.rl_uploads,
                    &s.rl_reactions,
                    &s.rl_restaurant_create,
                    &s.rl_edit_suggestions,
                    &s.rl_reports,
                ] {
                    l.retain_recent();
                    l.shrink_to_fit();
                }
                s.rl_global_ip.retain_recent();
                s.rl_global_ip.shrink_to_fit();
            }
        });
    }

    // The job queue lives only in this process's memory, so a restart or
    // crash loses every queued ClassifyDish and strands its dish in
    // `classifying` forever with nothing to retry it. Re-enqueue anything
    // that has sat there too long, on boot and periodically after.
    {
        let s = state.clone();
        tokio::spawn(async move {
            loop {
                if let Err(e) = requeue_stuck_classifications(&s).await {
                    tracing::error!("failed to re-enqueue stuck classifications: {e}");
                }
                tokio::time::sleep(std::time::Duration::from_secs(900)).await;
            }
        });
    }

    // Spawn job worker
    let worker_state = Arc::new(state.clone());
    tokio::spawn(jobs::worker::run_worker(receiver, worker_state));

    // Spawn edit suggestion expiry loop
    let expiry_db = state.db.clone();
    tokio::spawn(routes::edit_suggestions::run_expiry_loop(expiry_db));

    // Monthly crawler — DB-backed scheduler. tokio::time::interval would re-fire
    // on every restart and burn Google Places quota; checking crawl_runs makes
    // restarts after a recent crawl a no-op.
    if config.crawler_enabled && !config.google_places_api_key.is_empty() {
        let crawler_bg = crawler.clone();
        tokio::spawn(async move {
            loop {
                let last_run: Option<chrono::DateTime<chrono::Utc>> = sqlx::query_scalar(
                    "SELECT MAX(completed_at) FROM crawl_runs WHERE status = 'completed'",
                )
                .fetch_optional(&crawler_bg.db)
                .await
                .ok()
                .flatten();

                let should_run = last_run
                    .map(|t| chrono::Utc::now() - t > chrono::Duration::days(30))
                    .unwrap_or(true); // no previous run → run on first deploy

                if should_run {
                    tracing::info!("monthly crawler starting");
                    crawler_bg.run_all_cities().await;
                }

                // Re-check hourly; crawl only fires when >30 days have elapsed
                tokio::time::sleep(std::time::Duration::from_secs(3600)).await;
            }
        });
    }

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
            .merge(routes::images::admin_router())
            .merge(routes::admin_crawler::router()))
        // Reports
        .nest("/reports", routes::reports::router())
        // Images
        .nest("/images", routes::images::router())
        .layer(TraceLayer::new_for_http())
        .layer(cors_layer(&config))
        // Axum's built-in 2 MB body cap rejected 2–5 MB camera photos with a
        // bare 413 before images.rs's own 5 MB check ever ran. Allow the
        // documented limit plus multipart framing overhead.
        .layer(DefaultBodyLimit::max(6 * 1024 * 1024))
        .with_state(state);

    let addr = format!("{}:{}", config.server_host, config.server_port);
    tracing::info!("Listening on {addr}");
    let listener = tokio::net::TcpListener::bind(&addr).await?;
    // Drain in-flight requests on SIGTERM (every `docker compose up -d`
    // replacement) instead of cutting them off mid-response.
    axum::serve(listener, app.into_make_service_with_connect_info::<std::net::SocketAddr>())
        .with_graceful_shutdown(shutdown_signal())
        .await?;

    Ok(())
}

async fn shutdown_signal() {
    let ctrl_c = async {
        let _ = tokio::signal::ctrl_c().await;
    };
    #[cfg(unix)]
    let terminate = async {
        match tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate()) {
            Ok(mut sig) => {
                sig.recv().await;
            }
            Err(_) => std::future::pending::<()>().await,
        }
    };
    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();
    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }
    tracing::info!("shutdown signal received, draining");
}

/// Re-enqueue `ClassifyDish` for dishes left in `classifying` past the point
/// where an in-flight job could still be working on them (the worker retries
/// for well under a minute before marking a dish `failed`).
async fn requeue_stuck_classifications(state: &AppState) -> anyhow::Result<()> {
    use sqlx::Row;

    let rows = sqlx::query(
        r#"
        SELECT d.id, d.name, COALESCE(r.cuisine_type, 'Indian') AS cuisine
        FROM dishes d
        JOIN restaurants r ON r.id = d.restaurant_id
        WHERE d.attribute_state = 'classifying'
          AND d.updated_at < NOW() - INTERVAL '10 minutes'
        ORDER BY d.updated_at
        LIMIT 100
        "#,
    )
    .fetch_all(&state.db)
    .await?;

    if rows.is_empty() {
        return Ok(());
    }
    tracing::warn!("re-enqueuing {} stuck dish classification(s)", rows.len());

    for row in rows {
        let dish_id: uuid::Uuid = row.try_get("id")?;
        let dish_name: String = row.try_get("name")?;
        let cuisine: String = row.try_get("cuisine")?;
        // Bump updated_at so the next sweep doesn't pick the same dish up
        // again while this attempt is still in flight.
        sqlx::query("UPDATE dishes SET updated_at = NOW() WHERE id = $1")
            .bind(dish_id)
            .execute(&state.db)
            .await?;
        if let Err(e) = state
            .job_queue
            .enqueue(jobs::queue::Job::ClassifyDish {
                dish_id,
                dish_name,
                cuisine,
            })
            .await
        {
            tracing::error!("failed to enqueue ClassifyDish for {dish_id}: {e}");
        }
    }
    Ok(())
}

/// CORS was `permissive()`, which sent `Access-Control-Allow-Origin: *` on a
/// bearer-token API — any web page could call it cross-origin with a token it
/// had obtained. The mobile clients are not browsers and are unaffected by
/// CORS either way, so the default is now an empty allow-list; set
/// CORS_ALLOWED_ORIGINS if a browser client is ever added.
fn cors_layer(config: &Config) -> CorsLayer {
    use axum::http::{HeaderValue, header};
    let methods = [
        axum::http::Method::GET,
        axum::http::Method::POST,
        axum::http::Method::PATCH,
        axum::http::Method::DELETE,
        axum::http::Method::OPTIONS,
    ];
    let headers = [header::AUTHORIZATION, header::CONTENT_TYPE];

    if config.cors_allowed_origins.is_empty() {
        return CorsLayer::new()
            .allow_origin(AllowOrigin::list(std::iter::empty()))
            .allow_methods(methods)
            .allow_headers(headers);
    }

    let origins: Vec<HeaderValue> = config
        .cors_allowed_origins
        .iter()
        .filter_map(|o| match HeaderValue::from_str(o) {
            Ok(v) => Some(v),
            Err(_) => {
                tracing::warn!("ignoring malformed CORS origin: {o}");
                None
            }
        })
        .collect();
    tracing::info!("CORS allow-list: {:?}", config.cors_allowed_origins);
    CorsLayer::new()
        .allow_origin(AllowOrigin::list(origins))
        .allow_methods(methods)
        .allow_headers(headers)
}
