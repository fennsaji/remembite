//! Mock LLM provider for tests only.
#![cfg(test)]
#![allow(dead_code)]

use async_trait::async_trait;

use crate::{
    error::AppResult,
    llm::provider::{DishAttributes, LlmProvider, ParsedDish},
};

/// A mock LLM that returns a configurable result for every call.
pub struct MockLlm {
    pub classify_result: fn() -> AppResult<DishAttributes>,
}

#[async_trait]
impl LlmProvider for MockLlm {
    async fn classify_dish(&self, _name: &str, _cuisine: &str) -> AppResult<DishAttributes> {
        (self.classify_result)()
    }

    async fn parse_menu_ocr(&self, _raw_text: &str) -> AppResult<Vec<ParsedDish>> {
        Ok(vec![])
    }
}

pub fn always_succeed() -> MockLlm {
    MockLlm {
        classify_result: || {
            Ok(DishAttributes {
                spice_score: 0.5,
                sweetness_score: 0.3,
                dish_type: "curry".into(),
                cuisine: "indian".into(),
                confidence: 0.9,
            })
        },
    }
}

pub fn always_fail() -> MockLlm {
    MockLlm {
        classify_result: || {
            Err(crate::error::AppError::Internal(anyhow::anyhow!(
                "Gemini 503 Service Unavailable"
            )))
        },
    }
}
