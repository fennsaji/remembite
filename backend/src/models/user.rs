use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct User {
    pub id: Uuid,
    pub google_id: String,
    pub email: String,
    pub display_name: String,
    pub avatar_url: Option<String>,
    pub pro_status: bool,
    pub pro_expires_at: Option<DateTime<Utc>>,
    pub is_admin: bool,
    pub fcm_token: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}
