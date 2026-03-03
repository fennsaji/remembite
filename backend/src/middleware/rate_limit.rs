use std::{net::IpAddr, num::NonZeroU32, sync::Arc};

use governor::{
    DefaultKeyedRateLimiter, Quota, RateLimiter,
    clock::{Clock, DefaultClock},
};
use uuid::Uuid;

use crate::error::{AppError, AppResult};

// ── Type aliases ─────────────────────────────────────────────────────────────

pub type UserRateLimiter = Arc<DefaultKeyedRateLimiter<Uuid>>;
pub type IpRateLimiter = Arc<DefaultKeyedRateLimiter<IpAddr>>;

// ── Constructors ──────────────────────────────────────────────────────────────

/// Create a per-user keyed rate limiter allowing `per_hour` requests per hour.
pub fn new_per_user_limiter(per_hour: u32) -> UserRateLimiter {
    Arc::new(RateLimiter::keyed(Quota::per_hour(
        NonZeroU32::new(per_hour).expect("per_hour must be non-zero"),
    )))
}

/// Create a per-IP keyed rate limiter allowing `per_minute` requests per minute.
pub fn new_ip_limiter(per_minute: u32) -> IpRateLimiter {
    Arc::new(RateLimiter::keyed(Quota::per_minute(
        NonZeroU32::new(per_minute).expect("per_minute must be non-zero"),
    )))
}

// ── Check helpers ─────────────────────────────────────────────────────────────

/// Check whether the given `user_id` is within the per-user rate limit.
/// Returns `AppError::RateLimitedWithRetry(secs)` when the limit is exceeded.
pub fn check_user_limit(limiter: &UserRateLimiter, user_id: Uuid) -> AppResult<()> {
    match limiter.check_key(&user_id) {
        Ok(_) => Ok(()),
        Err(not_until) => {
            let now = DefaultClock::default().now();
            let wait_secs = not_until.wait_time_from(now).as_secs();
            Err(AppError::RateLimitedWithRetry(wait_secs))
        }
    }
}

/// Check whether the given `ip` is within the global IP rate limit.
/// Returns `AppError::RateLimitedWithRetry(secs)` when the limit is exceeded.
pub fn check_ip_limit(limiter: &IpRateLimiter, ip: IpAddr) -> AppResult<()> {
    match limiter.check_key(&ip) {
        Ok(_) => Ok(()),
        Err(not_until) => {
            let now = DefaultClock::default().now();
            let wait_secs = not_until.wait_time_from(now).as_secs();
            Err(AppError::RateLimitedWithRetry(wait_secs))
        }
    }
}
