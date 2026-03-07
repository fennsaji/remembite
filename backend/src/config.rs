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
    pub bayesian_prior_weight: f64,  // k constant (default 5.0)
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
            // Dev default — MUST be overridden via GOOGLE_PUBSUB_WEBHOOK_TOKEN in production
            google_pubsub_webhook_token: env_or("GOOGLE_PUBSUB_WEBHOOK_TOKEN", "dev-webhook-token"),
            bayesian_prior_weight: parse_env("BAYESIAN_PRIOR_WEIGHT", 5.0f64)?,
        })
    }
}

fn require_env(key: &str) -> anyhow::Result<String> {
    std::env::var(key).with_context(|| format!("Missing required env var: {key}"))
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
