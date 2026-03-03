ALTER TABLE users ADD COLUMN IF NOT EXISTS purchase_token TEXT;
CREATE INDEX IF NOT EXISTS idx_users_purchase_token ON users(purchase_token) WHERE purchase_token IS NOT NULL;
