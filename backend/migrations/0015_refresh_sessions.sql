-- Refresh-token sessions: makes refresh tokens revocable.
-- Refresh tokens used to be bare stateless JWTs, so a stolen one stayed valid
-- for its full lifetime with no way to kill it. Each issued refresh token now
-- gets a row here (keyed by a SHA-256 hash of the token, never the token
-- itself) so sign-out and rotation can revoke it server-side.
CREATE TABLE refresh_sessions (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash   TEXT NOT NULL UNIQUE,
    issued_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at   TIMESTAMPTZ NOT NULL,
    revoked_at   TIMESTAMPTZ,
    user_agent   TEXT,
    last_used_at TIMESTAMPTZ
);

-- Sign-out ("revoke all my sessions") and per-user session listing.
CREATE INDEX idx_refresh_sessions_user_id ON refresh_sessions(user_id);
-- Every /auth/refresh call looks the presented token up by hash.
CREATE INDEX idx_refresh_sessions_token_hash ON refresh_sessions(token_hash);
