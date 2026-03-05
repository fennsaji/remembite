use std::collections::HashMap;

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

// ─────────────────────────────────────────────
// Restaurant DTOs
// ─────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct RestaurantCreateRequest {
    pub name: String,
    pub city: String,
    pub latitude: f64,
    pub longitude: f64,
    pub cuisine_type: Option<String>,
    pub google_place_id: Option<String>,
    pub google_rating: Option<f64>,
    pub google_rating_count: Option<i32>,
    pub price_level: Option<i16>,
    pub business_status: Option<String>,
    pub phone_number: Option<String>,
    pub website: Option<String>,
    pub opening_hours: Option<serde_json::Value>,
}

#[derive(Debug, Deserialize)]
pub struct RestaurantPatchRequest {
    pub name: Option<String>,
    pub city: Option<String>,
    pub cuisine_type: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct RestaurantDetailResponse {
    pub id: Uuid,
    pub name: String,
    pub city: String,
    pub latitude: f64,
    pub longitude: f64,
    pub cuisine_type: Option<String>,
    pub avg_rating: Option<f64>,
    pub rating_count: i32,
    pub top_dishes: Vec<DishResponse>,
    pub created_by: Uuid,
    pub created_at: DateTime<Utc>,
    pub google_place_id: Option<String>,
    pub google_rating: Option<f64>,
    pub google_rating_count: Option<i32>,
    pub price_level: Option<i16>,
    pub business_status: Option<String>,
    pub phone_number: Option<String>,
    pub website: Option<String>,
    pub opening_hours: Option<serde_json::Value>,
}

#[derive(Debug, Serialize, Clone)]
pub struct RestaurantSummary {
    pub id: Uuid,
    pub name: String,
    pub city: String,
    pub cuisine_type: Option<String>,
    pub avg_rating: Option<f64>,
    pub rating_count: i32,
    pub latitude: f64,
    pub longitude: f64,
    pub google_rating: Option<f64>,
    pub open_now: Option<bool>,
    pub price_level: Option<i16>,
}

#[derive(Debug, Deserialize)]
pub struct NearbyQuery {
    pub lat: f64,
    pub lng: f64,
    pub radius: Option<f64>, // meters, default 2000
}

#[derive(Debug, Deserialize)]
pub struct DuplicateCheckQuery {
    pub name: String,
    pub lat: f64,
    pub lng: f64,
}

#[derive(Debug, Serialize)]
pub struct DuplicateCheckResponse {
    pub has_duplicate: bool,
    pub candidates: Vec<RestaurantSummary>,
}

// ─────────────────────────────────────────────
// Dish DTOs
// ─────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct DishBatchCreateRequest {
    pub dishes: Vec<DishCreateItem>,
}

#[derive(Debug, Deserialize)]
pub struct DishCreateItem {
    pub name: String,
    pub category: Option<String>,
    pub price: Option<i32>,
}

#[derive(Debug, Serialize, Clone)]
pub struct DishResponse {
    pub id: Uuid,
    pub restaurant_id: Uuid,
    pub name: String,
    pub category: Option<String>,
    pub price: Option<i32>,
    pub attribute_state: String,
    pub community_score: Option<f64>,
    pub vote_count: i32,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct DishDetailResponse {
    pub id: Uuid,
    pub restaurant_id: Uuid,
    pub name: String,
    pub category: Option<String>,
    pub price: Option<i32>,
    pub attribute_state: String,
    pub community_score: Option<f64>,
    pub vote_count: i32,
    pub attribute_priors: Option<AttributePriorResponse>,
    pub is_want_to_try: bool,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct AttributePriorResponse {
    pub spice_score: f64,
    pub sweetness_score: f64,
    pub dish_type: String,
    pub cuisine: String,
    pub final_spice_score: Option<f64>,
    pub final_sweetness_score: Option<f64>,
    pub community_vote_count: i32,
    pub confidence_score: Option<f64>,
}

// ─────────────────────────────────────────────
// Reaction DTOs
// ─────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct ReactionUpsertRequest {
    /// One of: so_yummy | tasty | pretty_good | meh | never_again
    pub reaction: String,
}

#[derive(Debug, Serialize)]
pub struct ReactionSummaryResponse {
    pub total: i64,
    pub breakdown: HashMap<String, i64>,
    pub weighted_score: f64,
}

// ─────────────────────────────────────────────
// Attribute vote DTOs
// ─────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct AttributeVoteRequest {
    /// One of: spice | sweetness
    pub attribute: String,
    /// Value 0.0–1.0
    pub value: f64,
}

// ─────────────────────────────────────────────
// Rating DTOs
// ─────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct RatingUpsertRequest {
    pub stars: i16,
}

#[derive(Debug, Serialize)]
pub struct RatingSummaryResponse {
    pub avg_rating: f64,
    pub rating_count: i64,
}

// ─────────────────────────────────────────────
// Search DTOs
// ─────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct SearchQuery {
    pub q: String,
    #[allow(dead_code)]
    pub lat: Option<f64>,
    #[allow(dead_code)]
    pub lng: Option<f64>,
}

#[derive(Debug, Serialize)]
pub struct SearchResultsResponse {
    pub restaurants: Vec<RestaurantSummary>,
    pub dishes: Vec<DishSearchResult>,
}

#[derive(Debug, Serialize)]
pub struct DishSearchResult {
    pub name: String,
    pub restaurant_count: i32,
    pub restaurant_ids: Vec<Uuid>,
    pub restaurant_names: Vec<String>,
    pub category: Option<String>,
    pub avg_community_score: Option<f64>,
}

// ─────────────────────────────────────────────
// Timeline DTOs
// ─────────────────────────────────────────────

#[derive(Debug, Serialize)]
pub struct TimelineResponse {
    pub entries: Vec<TimelineEntry>,
}

#[derive(Debug, Serialize)]
pub struct TimelineEntry {
    pub restaurant_id: Uuid,
    pub restaurant_name: String,
    pub date: String, // YYYY-MM-DD
    pub reactions: Vec<DishReactionItem>,
}

#[derive(Debug, Serialize)]
pub struct DishReactionItem {
    pub dish_id: Uuid,
    pub dish_name: String,
    pub reaction: String,
    pub reacted_at: DateTime<Utc>,
}

// ─────────────────────────────────────────────
// Edit Suggestion DTOs
// ─────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct EditSuggestionCreateRequest {
    pub entity_type: String, // "restaurant" or "dish"
    pub entity_id: Uuid,
    pub field: String,
    pub proposed_value: String,
}

#[derive(Debug, Serialize)]
pub struct EditSuggestionResponse {
    pub id: Uuid,
    pub entity_type: String,
    pub entity_id: Uuid,
    pub field: String,
    pub proposed_value: String,
    pub suggested_by: Uuid,
    pub status: String,
    pub net_votes: i32,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct EditVoteRequest {
    pub vote: String, // "up" or "down"
}

#[derive(Debug, Serialize)]
pub struct EditVoteResponse {
    pub ok: bool,
    pub applied: bool,
}

// ─────────────────────────────────────────────
// Report DTOs
// ─────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct ReportCreateRequest {
    pub entity_type: String,
    pub entity_id: Uuid,
    pub reason: String,
}

#[derive(Debug, Serialize)]
pub struct ReportResponse {
    pub id: Uuid,
    pub entity_type: String,
    pub entity_id: Uuid,
    pub reason: String,
    pub status: String,
    pub created_at: DateTime<Utc>,
}

// ─────────────────────────────────────────────
// Admin merge
// ─────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct MergeRestaurantRequest {
    pub merge_into_id: Uuid,
}

// ─────────────────────────────────────────────
// Admin report action
// ─────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct ReportActionRequest {
    /// "resolved" or "dismissed"
    pub action: String,
}

#[derive(Debug, Serialize)]
pub struct ReportActionResponse {
    pub ok: bool,
    pub status: String,
}

// ─────────────────────────────────────────────
// Dish Attributes DTO
// ─────────────────────────────────────────────

#[derive(Debug, Serialize)]
pub struct DishAttributesResponse {
    pub attribute_state: String,
    pub llm_spice_score: Option<f64>,
    pub llm_sweetness_score: Option<f64>,
    pub llm_dish_type: Option<String>,
    pub llm_cuisine: Option<String>,
    pub community_spice_avg: Option<f64>,
    pub community_sweetness_avg: Option<f64>,
    pub community_vote_count: i32,
    pub final_spice_score: Option<f64>,
    pub final_sweetness_score: Option<f64>,
    pub confidence_score: Option<f64>,
}

// ─────────────────────────────────────────────
// OCR parse DTOs
// ─────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct OcrParseRequest {
    pub raw_text: String,
    pub restaurant_id: Uuid,
}

#[derive(Debug, Serialize)]
pub struct OcrParseResponse {
    pub dishes: Vec<ParsedDishDto>,
}

#[derive(Debug, Serialize)]
pub struct ParsedDishDto {
    pub name: String,
    pub price_rupees: Option<i32>,
    pub category: Option<String>,
}

// ─────────────────────────────────────────────
// FCM token update
// ─────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct FcmTokenRequest {
    pub token: String,
}

// ─────────────────────────────────────────────
// Compatibility / Taste Intelligence DTOs
// ─────────────────────────────────────────────

#[derive(Debug, Serialize)]
pub struct CompatibilityResponse {
    pub signal: Option<String>,
    pub score: Option<f64>,
    pub reason: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct TasteInsightsResponse {
    pub ready: bool,
    pub reaction_count: i32,
    pub insights: Vec<String>,
}

#[derive(Debug, Serialize)]
pub struct TasteProfileStatusResponse {
    pub reaction_count: i32,
    pub threshold: i32,
    pub progress: f64,
    pub complete: bool,
    pub insights_locked: bool,
}

// ─────────────────────────────────────────────
// Intent DTOs
// ─────────────────────────────────────────────

#[derive(Debug, Serialize)]
pub struct IntentToggleResponse {
    pub active: bool,
}

// ─────────────────────────────────────────────
// Bootstrap DTOs
// ─────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct BootstrapRequest {
    pub reactions: Vec<BootstrapItem>,
}

#[derive(Debug, Deserialize)]
pub struct BootstrapItem {
    #[allow(dead_code)]
    pub dish_name: String,
    pub reaction: String,
    pub spice_score: f64,
    pub sweetness_score: f64,
    pub dish_type: String,
    pub cuisine: String,
}

#[derive(Debug, Serialize)]
pub struct BootstrapResponse {
    pub ok: bool,
}

// ─────────────────────────────────────────────
// Image DTOs
// ─────────────────────────────────────────────

#[derive(Debug, Serialize)]
pub struct ImageResponse {
    pub id: Uuid,
    pub entity_type: String,
    pub entity_id: Uuid,
    pub uploaded_by: Uuid,
    pub r2_key: String,
    pub is_public: bool,
    /// Full CDN URL for public images; None for private (use /images/{id}/url instead)
    pub cdn_url: Option<String>,
    pub created_at: DateTime<Utc>,
}
