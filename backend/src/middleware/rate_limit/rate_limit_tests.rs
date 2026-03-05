#![cfg(test)]

use std::net::IpAddr;
use uuid::Uuid;

use crate::{
    error::AppError,
    middleware::rate_limit::{check_ip_limit, check_user_limit, new_ip_limiter, new_per_user_limiter},
};

#[test]
fn allows_up_to_quota() {
    let limiter = new_per_user_limiter(3);
    let user = Uuid::new_v4();
    assert!(check_user_limit(&limiter, user).is_ok());
    assert!(check_user_limit(&limiter, user).is_ok());
    assert!(check_user_limit(&limiter, user).is_ok());
}

#[test]
fn rejects_over_quota() {
    let limiter = new_per_user_limiter(3);
    let user = Uuid::new_v4();
    for _ in 0..3 {
        let _ = check_user_limit(&limiter, user);
    }
    let result = check_user_limit(&limiter, user);
    assert!(matches!(result, Err(AppError::RateLimitedWithRetry(_))));
}

#[test]
fn per_user_isolation() {
    let limiter = new_per_user_limiter(1);
    let user_a = Uuid::new_v4();
    let user_b = Uuid::new_v4();
    let _ = check_user_limit(&limiter, user_a);
    assert!(matches!(
        check_user_limit(&limiter, user_a),
        Err(AppError::RateLimitedWithRetry(_))
    ));
    // user_b has its own independent quota
    assert!(check_user_limit(&limiter, user_b).is_ok());
}

#[test]
fn ip_limit_rejects_over_quota() {
    let limiter = new_ip_limiter(2);
    let ip: IpAddr = "127.0.0.1".parse().unwrap();
    assert!(check_ip_limit(&limiter, ip).is_ok());
    assert!(check_ip_limit(&limiter, ip).is_ok());
    let result = check_ip_limit(&limiter, ip);
    assert!(matches!(result, Err(AppError::RateLimitedWithRetry(_))));
}

#[test]
fn retry_after_is_positive() {
    let limiter = new_per_user_limiter(1);
    let user = Uuid::new_v4();
    let _ = check_user_limit(&limiter, user);
    match check_user_limit(&limiter, user) {
        Err(AppError::RateLimitedWithRetry(secs)) => {
            assert!(secs > 0, "Retry-After must be > 0 seconds");
        }
        other => panic!("Expected RateLimitedWithRetry, got {other:?}"),
    }
}
