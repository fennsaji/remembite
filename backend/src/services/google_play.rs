use anyhow::{Context, Result};
use chrono::{Duration, Utc};
use jsonwebtoken::{Algorithm, EncodingKey, Header, encode};
use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
pub struct ServiceAccountKey {
    pub client_email: String,
    pub private_key: String,
}

#[derive(Serialize)]
struct ServiceAccountClaims {
    iss: String,
    sub: String,
    aud: String,
    scope: String,
    iat: i64,
    exp: i64,
}

#[derive(Deserialize)]
struct TokenResponse {
    access_token: String,
}

pub async fn get_access_token(
    key_json: &str,
    http: &reqwest::Client,
) -> Result<String> {
    let key: ServiceAccountKey =
        serde_json::from_str(key_json).context("Failed to parse service account JSON")?;

    let now = Utc::now();
    let claims = ServiceAccountClaims {
        iss: key.client_email.clone(),
        sub: key.client_email.clone(),
        aud: "https://oauth2.googleapis.com/token".to_string(),
        scope: "https://www.googleapis.com/auth/androidpublisher".to_string(),
        iat: now.timestamp(),
        exp: (now + Duration::seconds(3600)).timestamp(),
    };

    let encoding_key = EncodingKey::from_rsa_pem(key.private_key.as_bytes())
        .context("Failed to parse RSA private key")?;
    let header = Header::new(Algorithm::RS256);
    let jwt = encode(&header, &claims, &encoding_key).context("Failed to sign JWT")?;

    let resp: TokenResponse = http
        .post("https://oauth2.googleapis.com/token")
        .form(&[
            ("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer"),
            ("assertion", jwt.as_str()),
        ])
        .send()
        .await?
        .error_for_status()?
        .json()
        .await?;

    Ok(resp.access_token)
}

pub async fn verify_subscription(
    package_name: &str,
    _subscription_id: &str, // v2 API: token alone identifies the subscription; kept for clarity at call sites
    purchase_token: &str,
    access_token: &str,
    http: &reqwest::Client,
) -> Result<i64> {
    #[derive(Deserialize)]
    struct LineItem {
        #[serde(rename = "expiryTime")]
        expiry_time: Option<String>,
    }

    #[derive(Deserialize)]
    struct SubscriptionV2 {
        #[serde(rename = "subscriptionState")]
        subscription_state: String,
        #[serde(rename = "lineItems")]
        line_items: Option<Vec<LineItem>>,
    }

    let url = format!(
        "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{}/purchases/subscriptionsv2/tokens/{}",
        package_name, purchase_token
    );

    let resp: SubscriptionV2 = http
        .get(&url)
        .bearer_auth(access_token)
        .send()
        .await?
        .error_for_status()
        .context("Google Play API returned error")?
        .json()
        .await?;

    let active = matches!(
        resp.subscription_state.as_str(),
        "SUBSCRIPTION_STATE_ACTIVE"
            | "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"
            | "SUBSCRIPTION_STATE_CANCELED"
    );

    if !active {
        anyhow::bail!("Subscription state not active: {}", resp.subscription_state);
    }

    let expiry_str = resp
        .line_items
        .as_deref()
        .and_then(|items| items.first())
        .and_then(|item| item.expiry_time.as_deref())
        .ok_or_else(|| anyhow::anyhow!("Subscription has no expiry time in line_items"))?;

    let expiry = chrono::DateTime::parse_from_rfc3339(expiry_str)
        .context("Failed to parse expiry time")?
        .timestamp();

    Ok(expiry)
}
