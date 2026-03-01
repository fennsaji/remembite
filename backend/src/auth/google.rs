use serde::Deserialize;

use crate::error::{AppError, AppResult};

/// Verified payload from Google ID token.
#[derive(Debug, Deserialize)]
pub struct GoogleTokenPayload {
    pub sub: String,     // Google user ID
    pub email: String,
    pub name: String,
    pub picture: Option<String>,
}

/// Verifies a Google ID token by calling Google's tokeninfo endpoint.
/// Returns the verified payload on success.
pub async fn verify_google_id_token(
    client: &reqwest::Client,
    id_token: &str,
) -> AppResult<GoogleTokenPayload> {
    let url = format!(
        "https://oauth2.googleapis.com/tokeninfo?id_token={id_token}"
    );

    let resp = client
        .get(&url)
        .send()
        .await
        .map_err(|e| AppError::Internal(anyhow::anyhow!("Google token verify request failed: {e}")))?;

    if !resp.status().is_success() {
        return Err(AppError::Unauthorized(
            "Google token verification failed".to_string(),
        ));
    }

    let payload = resp
        .json::<GoogleTokenPayload>()
        .await
        .map_err(|e| AppError::Internal(anyhow::anyhow!("Failed to parse Google token response: {e}")))?;

    Ok(payload)
}
