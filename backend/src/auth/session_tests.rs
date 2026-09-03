#![cfg(test)]

use chrono::{Duration, Utc};

use crate::auth::{
    jwt::issue_refresh_token_with_jti,
    session::{REUSE_GRACE, SessionStatus, classify, hash_token, is_recent_rotation},
};

#[test]
fn hash_is_deterministic() {
    assert_eq!(hash_token("abc"), hash_token("abc"));
}

#[test]
fn hash_differs_for_different_tokens() {
    assert_ne!(hash_token("abc"), hash_token("abd"));
}

#[test]
fn hash_is_64_hex_chars() {
    let h = hash_token("some.jwt.token");
    assert_eq!(h.len(), 64);
    assert!(h.chars().all(|c| c.is_ascii_hexdigit() && !c.is_uppercase()));
}

#[test]
fn hash_matches_known_sha256_vector() {
    // SHA-256("abc") — guards against silently swapping the algorithm.
    assert_eq!(
        hash_token("abc"),
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    );
}

#[test]
fn hash_never_contains_the_raw_token() {
    let token = "supersecrettokenvalue";
    assert!(!hash_token(token).contains(token));
}

#[test]
fn live_session_is_active() {
    let now = Utc::now();
    assert_eq!(classify(None, now + Duration::days(1), now), SessionStatus::Active);
}

#[test]
fn past_expiry_is_expired() {
    let now = Utc::now();
    assert_eq!(classify(None, now - Duration::seconds(1), now), SessionStatus::Expired);
}

#[test]
fn exactly_at_expiry_is_expired() {
    let now = Utc::now();
    assert_eq!(classify(None, now, now), SessionStatus::Expired);
}

#[test]
fn revoked_session_is_revoked() {
    let now = Utc::now();
    assert_eq!(
        classify(Some(now - Duration::hours(1)), now + Duration::days(1), now),
        SessionStatus::Revoked
    );
}

#[test]
fn revoked_takes_priority_over_expired() {
    // Reuse detection must fire even for a token that has since expired —
    // presenting a revoked token is the theft signal we act on.
    let now = Utc::now();
    assert_eq!(
        classify(Some(now - Duration::days(2)), now - Duration::days(1), now),
        SessionStatus::Revoked
    );
}

#[test]
fn refresh_tokens_issued_back_to_back_are_unique() {
    // Without the jti, identical claims minted in the same second would
    // produce identical tokens and collide on token_hash's UNIQUE index.
    let user = uuid::Uuid::new_v4();
    let (a, jti_a, _) =
        issue_refresh_token_with_jti(user, "a@b.com", false, false, "secret-key", 30).unwrap();
    let (b, jti_b, _) =
        issue_refresh_token_with_jti(user, "a@b.com", false, false, "secret-key", 30).unwrap();
    assert_ne!(jti_a, jti_b);
    assert_ne!(a, b);
    assert_ne!(hash_token(&a), hash_token(&b));
}

#[test]
fn issued_refresh_token_still_verifies_as_a_refresh_token() {
    // The extra jti field must not break decoding into `Claims`.
    let user = uuid::Uuid::new_v4();
    let (token, _, expires_at) =
        issue_refresh_token_with_jti(user, "a@b.com", true, false, "secret-key", 30).unwrap();
    let claims = crate::auth::jwt::verify_token(&token, "secret-key").unwrap();
    assert_eq!(claims.sub, user);
    assert_eq!(claims.kind, crate::auth::jwt::TokenKind::Refresh);
    assert!(claims.pro);
    assert_eq!(claims.exp, expires_at.timestamp());
}

#[test]
fn recent_rotation_is_within_grace_window() {
    let now = Utc::now();
    // Just rotated — a lost response, not theft.
    assert!(is_recent_rotation(Some(now - chrono::Duration::seconds(5)), now));
    // Long past the window — treat as reuse.
    assert!(!is_recent_rotation(
        Some(now - chrono::Duration::seconds(300)),
        now
    ));
    // Never revoked.
    assert!(!is_recent_rotation(None, now));
    // Exactly at the boundary is outside the window.
    assert!(!is_recent_rotation(Some(now - REUSE_GRACE), now));
}
