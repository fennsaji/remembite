use async_trait::async_trait;
use serde::{Deserialize, Serialize};

use crate::error::AppResult;

/// Output of dish classification — stored as probabilistic prior.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DishAttributes {
    /// 0.0 (not spicy) to 1.0 (very spicy)
    pub spice_score: f32,
    /// 0.0 (not sweet) to 1.0 (very sweet)
    pub sweetness_score: f32,
    pub dish_type: String,
    pub cuisine: String,
    /// LLM confidence in this classification, 0.0–1.0
    pub confidence: f32,
}

/// A dish parsed from raw OCR menu text.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParsedDish {
    pub name: String,
    /// Price in rupees, if detected
    pub price_rupees: Option<i32>,
    pub category: Option<String>,
}

/// Abstraction over all LLM providers.
/// Switch providers by swapping the concrete implementation — no business logic changes.
#[async_trait]
pub trait LlmProvider: Send + Sync {
    /// Classify a dish by name and cuisine.
    /// Returns structured attribute scores as probabilistic priors.
    async fn classify_dish(&self, name: &str, cuisine: &str) -> AppResult<DishAttributes>;

    /// Parse raw OCR menu text into structured dish entries.
    async fn parse_menu_ocr(&self, raw_text: &str) -> AppResult<Vec<ParsedDish>>;
}

/// Factory: construct the active LlmProvider from config.
pub fn build_provider(
    provider_name: &str,
    api_key: &str,
) -> Box<dyn LlmProvider> {
    match provider_name {
        "gemini" => Box::new(super::gemini::GeminiProvider::new(api_key.to_string())),
        other => panic!("Unknown LLM_PROVIDER: {other}. Supported: gemini"),
    }
}
