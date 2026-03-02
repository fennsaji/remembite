use async_trait::async_trait;
use serde::Deserialize;
use serde_json::json;

use crate::error::{AppError, AppResult};
use super::provider::{DishAttributes, LlmProvider, ParsedDish};

const GEMINI_API_BASE: &str =
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent";

pub struct GeminiProvider {
    api_key: String,
    client: reqwest::Client,
}

impl GeminiProvider {
    pub fn new(api_key: String) -> Self {
        Self {
            api_key,
            client: reqwest::Client::new(),
        }
    }

    async fn generate(&self, prompt: &str) -> AppResult<String> {
        let url = format!("{GEMINI_API_BASE}?key={}", self.api_key);
        let body = json!({
            "contents": [{ "parts": [{ "text": prompt }] }],
            "generationConfig": {
                "responseMimeType": "application/json",
                "temperature": 0.1
            }
        });

        let resp = self
            .client
            .post(&url)
            .json(&body)
            .send()
            .await
            .map_err(|e| AppError::Internal(anyhow::anyhow!("Gemini API request failed: {e}")))?;

        if !resp.status().is_success() {
            let status = resp.status();
            let text = resp.text().await.unwrap_or_default();
            return Err(AppError::Internal(anyhow::anyhow!(
                "Gemini API error {status}: {text}"
            )));
        }

        #[derive(Deserialize)]
        struct GeminiResponse {
            candidates: Vec<Candidate>,
        }
        #[derive(Deserialize)]
        struct Candidate {
            content: Content,
        }
        #[derive(Deserialize)]
        struct Content {
            parts: Vec<Part>,
        }
        #[derive(Deserialize)]
        struct Part {
            text: String,
        }

        let gemini_resp = resp
            .json::<GeminiResponse>()
            .await
            .map_err(|e| AppError::Internal(anyhow::anyhow!("Failed to parse Gemini response: {e}")))?;

        gemini_resp
            .candidates
            .into_iter()
            .next()
            .and_then(|c| c.content.parts.into_iter().next())
            .map(|p| p.text)
            .ok_or_else(|| AppError::Internal(anyhow::anyhow!("Empty Gemini response")))
    }
}

#[async_trait]
impl LlmProvider for GeminiProvider {
    async fn classify_dish(&self, name: &str, cuisine: &str) -> AppResult<DishAttributes> {
        let prompt = format!(
            r#"Classify this dish and return a JSON object with exactly these fields:
{{
  "spice_score": <float 0.0-1.0, where 0=not spicy, 1=extremely spicy>,
  "sweetness_score": <float 0.0-1.0, where 0=not sweet, 1=very sweet>,
  "dish_type": <one of: "starter", "main", "dessert", "beverage", "bread", "side", "snack">,
  "cuisine": <cuisine category, e.g. "North Indian", "South Indian", "Chinese", "Italian">,
  "confidence": <float 0.0-1.0, your confidence in this classification>
}}

Dish: "{name}"
Cuisine context: "{cuisine}"

Return only the JSON object, no explanation."#
        );

        let raw = self.generate(&prompt).await?;
        serde_json::from_str::<DishAttributes>(&raw).map_err(|e| {
            AppError::Internal(anyhow::anyhow!(
                "Failed to parse dish classification response: {e}. Raw: {raw}"
            ))
        })
    }

    async fn parse_menu_ocr(&self, raw_text: &str) -> AppResult<Vec<ParsedDish>> {
        let prompt = format!(
            r#"Extract dish entries from this raw restaurant menu text.
Return a JSON array where each element has:
{{
  "name": <dish name>,
  "price_rupees": <integer price in rupees, or null if not found>,
  "category": <menu section/category if visible, or null>
}}

Rules:
- Skip headers, footers, page numbers, and non-dish lines
- Clean up OCR artifacts in dish names
- Only include actual food/beverage items

Menu text:
{raw_text}

Return only the JSON array, no explanation."#
        );

        let raw = self.generate(&prompt).await?;
        serde_json::from_str::<Vec<ParsedDish>>(&raw).map_err(|e| {
            AppError::Internal(anyhow::anyhow!(
                "Failed to parse OCR menu response: {e}. Raw: {raw}"
            ))
        })
    }
}
