-- Close the double-redemption race: two accounts verifying the same purchase
-- token concurrently could both pass the old SELECT-then-UPDATE check and
-- both end up Pro. A unique index makes the second UPDATE fail atomically.

-- Defensive dedup: if any token is already shared across rows (from the old
-- racy check), keep the earliest owner and clear the rest so the index can
-- be created.
UPDATE users u
SET purchase_token = NULL
WHERE purchase_token IS NOT NULL
  AND EXISTS (
      SELECT 1 FROM users older
      WHERE older.purchase_token = u.purchase_token
        AND older.created_at < u.created_at
  );

CREATE UNIQUE INDEX IF NOT EXISTS users_purchase_token_uidx
    ON users(purchase_token)
    WHERE purchase_token IS NOT NULL;
