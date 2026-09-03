use anyhow::Context;

#[derive(Debug, Clone)]
pub struct Config {
    pub database_url: String,
    pub jwt_secret: String,
    pub jwt_access_expiry_hours: u64,
    pub jwt_refresh_expiry_days: u64,
    pub google_client_id: String,
    pub llm_provider: String,
    pub gemini_api_key: String,
    pub r2_account_id: String,
    pub r2_access_key_id: String,
    pub r2_secret_access_key: String,
    pub r2_bucket: String,
    pub r2_public_url: String,
    pub fcm_service_account_json: String, // Firebase service account JSON (full JSON string)
    pub fcm_project_id: String,            // Firebase project ID
    pub server_host: String,
    pub server_port: u16,
    pub google_play_package_name: String,
    pub google_play_service_account_json: String,
    pub google_pubsub_webhook_token: String,
    /// Browser origins permitted to call this API. Empty = none (the normal
    /// case: the mobile clients are not browsers and ignore CORS entirely).
    pub cors_allowed_origins: Vec<String>,
    pub bayesian_prior_weight: f64,  // k constant (default 5.0)
    pub google_places_api_key: String,
    pub crawler_enabled: bool,
    pub crawler_min_rating: f64,
    pub crawler_grid_step_km: f64,
}

impl Config {
    pub fn from_env() -> anyhow::Result<Self> {
        dotenvy::dotenv().ok();
        Ok(Config {
            database_url: require_env("DATABASE_URL")?,
            jwt_secret: require_env("JWT_SECRET")?,
            jwt_access_expiry_hours: parse_env("JWT_ACCESS_EXPIRY_HOURS", 24)?,
            jwt_refresh_expiry_days: parse_env("JWT_REFRESH_EXPIRY_DAYS", 30)?,
            google_client_id: require_env("GOOGLE_CLIENT_ID")?,
            llm_provider: env_or("LLM_PROVIDER", "gemini"),
            gemini_api_key: require_env("GEMINI_API_KEY")?,
            r2_account_id: env_or("R2_ACCOUNT_ID", ""),
            r2_access_key_id: env_or("R2_ACCESS_KEY_ID", ""),
            r2_secret_access_key: env_or("R2_SECRET_ACCESS_KEY", ""),
            r2_bucket: env_or("R2_BUCKET", "remembite-images"),
            r2_public_url: env_or("R2_PUBLIC_URL", ""),
            fcm_service_account_json: env_or("FCM_SERVICE_ACCOUNT_JSON", ""),
            fcm_project_id: env_or("FCM_PROJECT_ID", ""),
            server_host: env_or("SERVER_HOST", "0.0.0.0"),
            server_port: parse_env("SERVER_PORT", 8080)?,
            google_play_package_name: env_or("GOOGLE_PLAY_PACKAGE_NAME", "com.fennsaji.remembite"),
            // Dev default ("{}") — MUST be set to real service account JSON via GOOGLE_PLAY_SERVICE_ACCOUNT_JSON in production
            google_play_service_account_json: env_or("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", "{}"),
            // Required outside development (APP_ENV != "development"); a
            // predictable dev default would let anyone forge Play webhooks.
            google_pubsub_webhook_token: if is_dev_env() {
                env_or("GOOGLE_PUBSUB_WEBHOOK_TOKEN", "dev-webhook-token")
            } else {
                require_env("GOOGLE_PUBSUB_WEBHOOK_TOKEN")?
            },
            // Comma-separated, e.g. "https://remembite.app,https://admin.remembite.app".
            cors_allowed_origins: env_or("CORS_ALLOWED_ORIGINS", "")
                .split(',')
                .map(str::trim)
                .filter(|o| !o.is_empty())
                .map(str::to_string)
                .collect(),
            bayesian_prior_weight: parse_env("BAYESIAN_PRIOR_WEIGHT", 5.0f64)?,
            google_places_api_key: env_or("GOOGLE_PLACES_API_KEY", ""),
            crawler_enabled: env_or("CRAWLER_ENABLED", "true") == "true",
            crawler_min_rating: parse_env("CRAWLER_MIN_RATING", 3.5f64)?,
            crawler_grid_step_km: parse_env("CRAWLER_GRID_STEP_KM", 2.0f64)?,
        })
    }
}

/// `APP_ENV` selects dev-only defaults. Anything other than an explicit
/// "development"/"dev"/"local" is treated as production so a missing var
/// fails closed.
fn is_dev_env() -> bool {
    matches!(
        env_or("APP_ENV", "production").trim().to_ascii_lowercase().as_str(),
        "development" | "dev" | "local"
    )
}

fn require_env(key: &str) -> anyhow::Result<String> {
    let v = std::env::var(key).with_context(|| format!("Missing required env var: {key}"))?;
    // An unset CI secret still writes `KEY=` into .env.api, and `env::var`
    // returns Ok("") for that — which would silently boot with an empty
    // secret (an empty webhook token matches an empty `?token=`).
    if v.trim().is_empty() {
        anyhow::bail!("Required env var {key} is set but empty");
    }
    Ok(v)
}

fn env_or(key: &str, default: &str) -> String {
    std::env::var(key).unwrap_or_else(|_| default.to_string())
}

fn parse_env<T: std::str::FromStr>(key: &str, default: T) -> anyhow::Result<T>
where
    T::Err: std::fmt::Display,
{
    match std::env::var(key) {
        Ok(val) => val
            .parse()
            .map_err(|e| anyhow::anyhow!("Invalid value for {key}: {e}")),
        Err(_) => Ok(default),
    }
}
