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
    pub fcm_server_key: String,
    pub server_host: String,
    pub server_port: u16,
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
            fcm_server_key: env_or("FCM_SERVER_KEY", ""),
            server_host: env_or("SERVER_HOST", "0.0.0.0"),
            server_port: parse_env("SERVER_PORT", 8080)?,
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
