ALTER TABLE restaurants
  ADD COLUMN IF NOT EXISTS google_place_id    TEXT,
  ADD COLUMN IF NOT EXISTS google_rating      DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS google_rating_count INT,
  ADD COLUMN IF NOT EXISTS price_level        SMALLINT,
  ADD COLUMN IF NOT EXISTS business_status    TEXT,
  ADD COLUMN IF NOT EXISTS phone_number       TEXT,
  ADD COLUMN IF NOT EXISTS website            TEXT,
  ADD COLUMN IF NOT EXISTS opening_hours      JSONB;
