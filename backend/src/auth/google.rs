use serde::Deserialize;

use crate::error::{AppError, AppResult};

/// Verified payload from Google ID token.
#[derive(Debug, Deserialize)]
pub struct GoogleTokenPayload {
    pub sub: String,     // Google user ID
    pub email: String,
    #[serde(default)]
    pub name: Option<String>,
    pub picture: Option<String>,
    /// OAuth client ID this token was issued for — MUST match ours.
    pub aud: String,
    /// tokeninfo returns this as the string "true"/"false".
    #[serde(default)]
    pub email_verified: Option<String>,
}

/// Verifies a Google ID token by calling Google's tokeninfo endpoint.
///
/// Security: tokeninfo returns 200 for ANY Google-signed ID token, including
/// ones issued to other apps. The `aud` check below is what stops an attacker
/// from replaying a victim's token obtained through a different OAuth client.
pub async fn verify_google_id_token(
    client: &reqwest::Client,
    id_token: &str,
    expected_client_id: &str,
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
        .map_err(|_| AppError::Unauthorized("Malformed Google token payload".to_string()))?;

    if payload.aud != expected_client_id {
        return Err(AppError::Unauthorized(
            "Google token issued for a different application".to_string(),
        ));
    }

    if payload.email_verified.as_deref() != Some("true") {
        return Err(AppError::Unauthorized(
            "Google account email is not verified".to_string(),
        ));
    }

    Ok(payload)
}
