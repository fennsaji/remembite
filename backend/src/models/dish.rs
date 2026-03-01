use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type, PartialEq)]
#[sqlx(type_name = "attribute_state", rename_all = "lowercase")]
pub enum AttributeState {
    Classifying,
    Classified,
    Failed,
}

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct Dish {
    pub id: Uuid,
    pub restaurant_id: Uuid,
    pub name: String,
    pub category: Option<String>,
    pub price: Option<i32>,
    pub created_by: Uuid,
    pub attribute_state: AttributeState,
    pub community_score: Option<f64>,
    pub vote_count: i32,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}
