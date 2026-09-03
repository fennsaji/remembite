//! Refresh-token session management.
//!
//! Refresh tokens are still JWTs, but each issued token is also recorded in
//! `refresh_sessions` so it can be revoked server-side. We never store the
//! token itself — only a SHA-256 hash of it — so a database leak alone does
//! not hand out usable sessions.

use chrono::{DateTime, Utc};
use sha2::{Digest, Sha256};
use sqlx::{PgExecutor, Postgres, Transaction};
use uuid::Uuid;

use crate::error::AppResult;

/// SHA-256 of the token string, lowercase hex. Deterministic (no salt) because
/// lookup is by hash — the token is high-entropy already, so this is a
/// leak-mitigation measure, not a password hash.
pub fn hash_token(token: &str) -> String {
    let digest = Sha256::digest(token.as_bytes());
    let mut out = String::with_capacity(digest.len() * 2);
    for byte in digest.iter() {
        use std::fmt::Write;
        let _ = write!(out, "{byte:02x}");
    }
    out
}

/// State of a looked-up session, as far as the refresh handler cares.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SessionStatus {
    /// Usable — rotate it.
    Active,
    /// Already revoked: either normal rotation or a stolen-token replay.
    /// Callers treat this as reuse and nuke every session for the user.
    Revoked,
    /// Past its expiry — reject, but not evidence of theft.
    Expired,
}

/// Classifies a session row. Pure logic, kept separate so it is unit-testable
/// without a database.
pub fn classify(
    revoked_at: Option<DateTime<Utc>>,
    expires_at: DateTime<Utc>,
    now: DateTime<Utc>,
) -> SessionStatus {
    if revoked_at.is_some() {
        // Reuse detection takes priority: a revoked token being presented is
        // the signal we care about even if it has since expired.
        SessionStatus::Revoked
    } else if expires_at <= now {
        SessionStatus::Expired
    } else {
        SessionStatus::Active
    }
}

/// How long after a rotation a revoked token may be re-presented without
/// being treated as theft.
///
/// Rotation revokes the old token before the new one reaches the client, so a
/// dropped response (flaky mobile network, app killed mid-request) leaves the
/// client legitimately holding a token the server has already retired. Nuking
/// every session for that would sign the user out on all their devices for an
/// ordinary network blip. A thief replaying a stolen token later still trips
/// the reuse check.
pub const REUSE_GRACE: chrono::Duration = chrono::Duration::seconds(60);

/// True if a revoked token is within [`REUSE_GRACE`] of its revocation, i.e.
/// a benign retry of a rotation whose response was lost rather than reuse.
pub fn is_recent_rotation(revoked_at: Option<DateTime<Utc>>, now: DateTime<Utc>) -> bool {
    match revoked_at {
        Some(t) => now >= t && now - t < REUSE_GRACE,
        None => false,
    }
}

/// Records a newly issued refresh token.
pub async fn insert_session<'e, E: PgExecutor<'e>>(
    executor: E,
    user_id: Uuid,
    token: &str,
    expires_at: DateTime<Utc>,
    user_agent: Option<&str>,
) -> AppResult<()> {
    sqlx::query(
        r#"
        INSERT INTO refresh_sessions (id, user_id, token_hash, expires_at, user_agent)
        VALUES ($1, $2, $3, $4, $5)
        "#,
    )
    .bind(Uuid::new_v4())
    .bind(user_id)
    .bind(hash_token(token))
    .bind(expires_at)
    .bind(user_agent)
    .execute(executor)
    .await?;
    Ok(())
}

/// Marks one session revoked (idempotent — re-revoking is a no-op).
pub async fn revoke_by_hash(
    tx: &mut Transaction<'_, Postgres>,
    token_hash: &str,
) -> AppResult<()> {
    sqlx::query(
        "UPDATE refresh_sessions SET revoked_at = NOW() WHERE token_hash = $1 AND revoked_at IS NULL",
    )
    .bind(token_hash)
    .execute(&mut **tx)
    .await?;
    Ok(())
}

/// Revokes every live session for a user (sign-out-everywhere, and the
/// response to refresh-token reuse).
pub async fn revoke_all_for_user<'e, E: PgExecutor<'e>>(
    executor: E,
    user_id: Uuid,
) -> AppResult<u64> {
    let result = sqlx::query(
        "UPDATE refresh_sessions SET revoked_at = NOW() WHERE user_id = $1 AND revoked_at IS NULL",
    )
    .bind(user_id)
    .execute(executor)
    .await?;
    Ok(result.rows_affected())
}

/// Opportunistic cleanup of long-dead rows. Called from the refresh handler
/// rather than a cron job: refresh is low-frequency (once per access-token
/// lifetime per device), the DELETE is index-free but tiny, and without it the
/// table grows unboundedly for the life of the deployment. The 30-day grace
/// past expiry keeps recently-expired rows around long enough to still be
/// recognised as reuse rather than silently "unknown token".
pub async fn prune_expired<'e, E: PgExecutor<'e>>(executor: E) -> AppResult<()> {
    sqlx::query("DELETE FROM refresh_sessions WHERE expires_at < NOW() - INTERVAL '30 days'")
        .execute(executor)
        .await?;
    Ok(())
}
