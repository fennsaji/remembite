#![cfg(test)]

use crate::llm::mock::{always_fail, always_succeed};

#[test]
fn mock_classify_succeed_returns_ok() {
    let mock = always_succeed();
    let result = (mock.classify_result)();
    assert!(result.is_ok(), "always_succeed mock must return Ok");
    let attrs = result.unwrap();
    assert!(attrs.spice_score >= 0.0 && attrs.spice_score <= 1.0);
    assert!(attrs.sweetness_score >= 0.0 && attrs.sweetness_score <= 1.0);
    assert!(attrs.confidence >= 0.0 && attrs.confidence <= 1.0);
    assert!(!attrs.dish_type.is_empty());
    assert!(!attrs.cuisine.is_empty());
}

#[test]
fn mock_classify_fail_returns_err_with_503_message() {
    let mock = always_fail();
    let result = (mock.classify_result)();
    assert!(result.is_err(), "always_fail mock must return Err");
    let err = result.unwrap_err().to_string();
    assert!(
        err.contains("503"),
        "Error message should mention 503 (simulating Gemini outage): got '{err}'"
    );
}
