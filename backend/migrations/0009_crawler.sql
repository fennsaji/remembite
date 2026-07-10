-- Crawler infrastructure: system user, unique place index, run tracking,
-- config-driven city list, grid points, enrichment timestamp.

-- System user row (FK target for restaurants/dishes created_by = nil UUID).
-- Must be first so foreign key inserts in later steps succeed.
-- google_id and display_name are NOT NULL in the schema.
INSERT INTO users (id, google_id, email, display_name, created_at, updated_at)
VALUES (
    '00000000-0000-0000-0000-000000000000',
    'system-crawler',
    'system@remembite.internal',
    'Remembite Crawler',
    NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

-- Defensive dedup: if two rows share a google_place_id (added by users before
-- this index existed), keep the oldest and NULL the rest so index creation
-- cannot fail at startup.
UPDATE restaurants r
SET google_place_id = NULL
WHERE google_place_id IS NOT NULL
  AND EXISTS (
      SELECT 1 FROM restaurants older
      WHERE older.google_place_id = r.google_place_id
        AND older.created_at < r.created_at
  );

-- Partial unique index required for ON CONFLICT (google_place_id) DO NOTHING upserts.
CREATE UNIQUE INDEX IF NOT EXISTS restaurants_google_place_id_uidx
    ON restaurants(google_place_id)
    WHERE google_place_id IS NOT NULL;

-- Track crawl job runs for monitoring and admin visibility
CREATE TABLE crawl_runs (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    city              VARCHAR NOT NULL,
    status            VARCHAR NOT NULL DEFAULT 'running',  -- running | completed | failed
    restaurants_found INT NOT NULL DEFAULT 0,
    dishes_found      INT NOT NULL DEFAULT 0,
    started_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at      TIMESTAMPTZ
);

-- Config-driven city list so admin can add cities without redeploying
CREATE TABLE crawler_cities (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR NOT NULL UNIQUE,
    lat_min         DOUBLE PRECISION NOT NULL,
    lat_max         DOUBLE PRECISION NOT NULL,
    lng_min         DOUBLE PRECISION NOT NULL,
    lng_max         DOUBLE PRECISION NOT NULL,
    enabled         BOOL NOT NULL DEFAULT true,
    last_crawled_at TIMESTAMPTZ
);

-- Pre-generated grid points; last_scanned_at drives monthly crawl ordering
-- (NULL = never scanned -> highest priority).
CREATE TABLE crawl_grid_points (
    id              SERIAL PRIMARY KEY,
    city            VARCHAR NOT NULL,
    lat             DOUBLE PRECISION NOT NULL,
    lng             DOUBLE PRECISION NOT NULL,
    last_scanned_at TIMESTAMPTZ,
    scan_count      INT NOT NULL DEFAULT 0
);

-- Track when Place Details were last fetched for a restaurant
ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS enriched_at TIMESTAMPTZ;
