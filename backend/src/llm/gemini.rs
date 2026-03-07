use async_trait::async_trait;
use serde::Deserialize;
use serde_json::json;

use crate::error::{AppError, AppResult};
use super::provider::{DishAttributes, LlmProvider, ParsedDish};

const GEMINI_API_BASE: &str =
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent";

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
        struct UsageMetadata {
            #[serde(default)]
            prompt_token_count: u32,
            #[serde(default)]
            candidates_token_count: u32,
        }
        #[derive(Deserialize)]
        struct GeminiResponse {
            candidates: Vec<Candidate>,
            #[serde(default)]
            usage_metadata: Option<UsageMetadata>,
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

        if let Some(usage) = &gemini_resp.usage_metadata {
            tracing::info!(
                prompt_tokens = usage.prompt_token_count,
                candidate_tokens = usage.candidates_token_count,
                "Gemini token usage"
            );
        }

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
  "spice_score": <float 0.0-1.0>,
  "sweetness_score": <float 0.0-1.0>,
  "dish_type": <one of: "starter", "main", "dessert", "beverage", "bread", "side", "snack">,
  "cuisine": <cuisine category, e.g. "North Indian", "South Indian", "Chinese", "Italian">,
  "confidence": <float 0.0-1.0, your confidence in this classification>
}}

Spice scale — use EXACTLY these anchors, nothing in between:
  0.0 = zero heat, no chilli at all (Curd Rice, Idli, Plain Naan, Gulab Jamun, any dessert/sweet)
  0.2 = barely perceptible warmth (Mild Korma, Butter Chicken with low chilli, Coconut milk curries)
  0.5 = moderate heat, clearly spicy but bearable (Chicken Tikka Masala, Dal Tadka, Pav Bhaji)
  0.8 = hot, uncomfortable for many (Kolhapuri, Chettinad, Andhra-style curries)
  1.0 = extreme heat (Vindaloo, Laal Maas, Naga-chilli dishes)
  Use 0.0 whenever the dish is genuinely not spicy. Do NOT use 0.1 or 0.2 as a hedge for neutral dishes.

Sweetness scale — use EXACTLY these anchors:
  0.0 = no sweetness at all (Biryani, Dal, Samosa, Roti, any savoury dish)
  0.2 = faint sweetness (Mango Lassi lightly sweetened, sweet-sour chutneys)
  0.5 = noticeably sweet (Kheer, Payasam, Shrikhand)
  0.8 = very sweet (Gulab Jamun, Rasgulla, Jalebi)
  1.0 = extremely sweet (Motichoor Ladoo, Imarti)
  Use 0.0 for any savoury, salty, or spicy dish with no sweet component. Do NOT use 0.1 or 0.2 as a hedge.

Dish: "{name}"
Cuisine context: "{cuisine}"

Return only the JSON object, no explanation."#
        );

        let raw = self.generate(&prompt).await?;
        if let Ok(attrs) = serde_json::from_str::<DishAttributes>(&raw) {
            return Ok(attrs);
        }
        // Retry once on parse failure
        tracing::warn!("Gemini response parse failed on first attempt, retrying. Raw: {raw}");
        let raw2 = self.generate(&prompt).await?;
        serde_json::from_str::<DishAttributes>(&raw2).map_err(|e| {
            AppError::Internal(anyhow::anyhow!(
                "Failed to parse dish classification response after retry: {e}. Raw: {raw2}"
            ))
        })
    }

    async fn parse_menu_ocr(&self, raw_text: &str) -> AppResult<Vec<ParsedDish>> {
        let prompt = format!(
            r#"You are extracting dishes from a restaurant menu. The menu may be from anywhere in India. Dish names may appear in English, Hindi, Tamil, Telugu, Kannada, Malayalam, Bengali, Marathi, Gujarati, Punjabi, or their romanized/transliterated forms. Treat ALL of these as valid dish names.

Extract every food and beverage item and return a JSON array. Each element must have:
{{
  "name": <dish name — preserve the name as written on the menu, fix OCR noise only>,
  "price_rupees": <integer price in rupees, or null>,
  "category": <see category rules below>
}}

Category rules (in priority order):
1. If the menu has a clear section header above the dish (e.g. "STARTERS", "MAIN COURSE", "SOUPS", "BREADS", "DESSERTS", "BEVERAGES", "BIRYANI", "THALI"), use that as the category — clean up OCR noise, fix capitalisation (Title Case), translate regional-language headers to English (e.g. "Nashta" → "Snacks", "Chawal" → "Rice")
2. If no section header is present or the header is ambiguous, infer the category from the dish name itself using culinary knowledge. Use one of these standard categories: Starters, Soups, Salads, Main Course, Breads, Rice & Biryani, Noodles & Pasta, Snacks, Desserts, Beverages, Juices, Combos & Thalis, Sides
3. Never leave category as null — always assign a best-guess category

What counts as a dish:
- Any named food or drink item, regardless of language or script
- Regional dishes by any name: Idli, Dosa, Vada, Uttapam, Appam, Puttu, Pongal, Kozhukattai, Rasam, Sambar, Avial, Biryani, Pulao, Paratha, Naan, Roti, Kulcha, Pav Bhaji, Misal Pav, Vada Pav, Poha, Upma, Sabudana Khichdi, Dal Makhani, Butter Chicken, Chole, Rajma, Kadhi, Dhokla, Khandvi, Fafda, Thepla, Undhiyu, Dal Baati Churma, Laal Maas, Ghevar, Mishti Doi, Rasgulla, Sandesh, Macher Jhol, Kosha Mangsho, Hilsa dishes, Dum Aloo, Rogan Josh, Yakhni, Gushtaba, Kofta, Seekh Kabab, Tikka, Nihari, Haleem, Keema, and any other named dish
- If a dish name appears in a regional script (Devanagari, Tamil, Telugu, Kannada, etc.), transliterate it to Roman script
- Dishes with suffixes like "Special", "Royal", "Masala", "Tadka", "Dum", "Fry", etc. are individual dishes — include them

What to skip:
- Section headers alone (e.g. "STARTERS", "MAIN COURSE", "BEVERAGES") unless they appear as a dish name
- Standalone prices, percentages, tax lines (e.g. "GST 5%", "Service charge 10%")
- Page numbers, table numbers, restaurant name, address, phone, website, QR code text
- Descriptions or ingredient lists that follow a dish name (the dish name itself should be included)
- Duplicate dish names within the same category — keep only the first occurrence
- Repeated dishes across multiple scanned pages — deduplicate by name+category (case-insensitive)

Menu text:
{raw_text}

Return only the JSON array, no explanation."#
        );

        let raw = self.generate(&prompt).await?;
        if let Ok(dishes) = serde_json::from_str::<Vec<ParsedDish>>(&raw) {
            return Ok(dishes);
        }
        // Retry once on parse failure
        tracing::warn!("Gemini OCR response parse failed on first attempt, retrying. Raw: {raw}");
        let raw2 = self.generate(&prompt).await?;
        serde_json::from_str::<Vec<ParsedDish>>(&raw2).map_err(|e| {
            AppError::Internal(anyhow::anyhow!(
                "Failed to parse OCR menu response after retry: {e}. Raw: {raw2}"
            ))
        })
    }
}
