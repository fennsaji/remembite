-- Remembite – Initial Schema
-- Run via: sqlx migrate run

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
-- PostGIS optional for geo queries — enable if available:
-- CREATE EXTENSION IF NOT EXISTS postgis;

-- Enums
CREATE TYPE attribute_state AS ENUM ('classifying', 'classified', 'failed');
CREATE TYPE reaction_type AS ENUM ('so_yummy', 'tasty', 'pretty_good', 'meh', 'never_again');
CREATE TYPE edit_status AS ENUM ('pending', 'approved', 'rejected', 'expired');
CREATE TYPE vote_direction AS ENUM ('up', 'down');
CREATE TYPE entity_type AS ENUM ('restaurant', 'dish');
CREATE TYPE attribute_name AS ENUM ('spice', 'sweetness');

-- ─────────────────────────────────────────────
-- users
-- ─────────────────────────────────────────────
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    google_id       TEXT NOT NULL UNIQUE,
    email           TEXT NOT NULL,
    display_name    TEXT NOT NULL,
    avatar_url      TEXT,
    pro_status      BOOLEAN NOT NULL DEFAULT FALSE,
    pro_expires_at  TIMESTAMPTZ,
    is_admin        BOOLEAN NOT NULL DEFAULT FALSE,
    fcm_token       TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_google_id ON users(google_id);

-- ─────────────────────────────────────────────
-- restaurants
-- ─────────────────────────────────────────────
CREATE TABLE restaurants (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            TEXT NOT NULL,
    city            TEXT NOT NULL,
    latitude        DOUBLE PRECISION NOT NULL,
    longitude       DOUBLE PRECISION NOT NULL,
    cuisine_type    TEXT,
    created_by      UUID NOT NULL REFERENCES users(id),
    avg_rating      DOUBLE PRECISION,
    rating_count    INTEGER NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_restaurants_name_trgm ON restaurants USING gin(name gin_trgm_ops);
CREATE INDEX idx_restaurants_location ON restaurants(latitude, longitude);
CREATE INDEX idx_restaurants_created_by ON restaurants(created_by);

-- ─────────────────────────────────────────────
-- dishes
-- ─────────────────────────────────────────────
CREATE TABLE dishes (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    restaurant_id    UUID NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
    name             TEXT NOT NULL,
    category         TEXT,
    price            INTEGER, -- in rupees
    created_by       UUID NOT NULL REFERENCES users(id),
    attribute_state  attribute_state NOT NULL DEFAULT 'classifying',
    community_score  DOUBLE PRECISION, -- computed: weighted reaction score
    vote_count       INTEGER NOT NULL DEFAULT 0,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_dishes_restaurant_id ON dishes(restaurant_id);
CREATE INDEX idx_dishes_name_trgm ON dishes USING gin(name gin_trgm_ops);
CREATE INDEX idx_dishes_community_score ON dishes(restaurant_id, community_score DESC NULLS LAST);

-- ─────────────────────────────────────────────
-- restaurant_ratings
-- ─────────────────────────────────────────────
CREATE TABLE restaurant_ratings (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id),
    restaurant_id   UUID NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
    stars           SMALLINT NOT NULL CHECK (stars BETWEEN 1 AND 5),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, restaurant_id)
);

CREATE INDEX idx_restaurant_ratings_restaurant ON restaurant_ratings(restaurant_id);

-- ─────────────────────────────────────────────
-- dish_reactions
-- ─────────────────────────────────────────────
CREATE TABLE dish_reactions (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES users(id),
    dish_id     UUID NOT NULL REFERENCES dishes(id) ON DELETE CASCADE,
    reaction    reaction_type NOT NULL,
    synced_at   TIMESTAMPTZ, -- null = pending sync to cloud
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, dish_id)
);

CREATE INDEX idx_dish_reactions_user ON dish_reactions(user_id);
CREATE INDEX idx_dish_reactions_dish ON dish_reactions(dish_id);
CREATE INDEX idx_dish_reactions_user_updated ON dish_reactions(user_id, reaction, updated_at DESC);

-- ─────────────────────────────────────────────
-- dish_attribute_votes
-- ─────────────────────────────────────────────
CREATE TABLE dish_attribute_votes (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES users(id),
    dish_id     UUID NOT NULL REFERENCES dishes(id) ON DELETE CASCADE,
    attribute   attribute_name NOT NULL,
    value       DOUBLE PRECISION NOT NULL CHECK (value BETWEEN 0.0 AND 1.0),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, dish_id, attribute)
);

CREATE INDEX idx_attribute_votes_dish ON dish_attribute_votes(dish_id);

-- ─────────────────────────────────────────────
-- dish_attribute_priors (LLM output)
-- ─────────────────────────────────────────────
CREATE TABLE dish_attribute_priors (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    dish_id             UUID NOT NULL REFERENCES dishes(id) ON DELETE CASCADE,
    spice_score         DOUBLE PRECISION NOT NULL,
    sweetness_score     DOUBLE PRECISION NOT NULL,
    dish_type           TEXT NOT NULL,
    cuisine             TEXT NOT NULL,
    confidence          DOUBLE PRECISION NOT NULL DEFAULT 0.5,
    -- Bayesian final scores (k=5, recomputed on each vote)
    final_spice_score   DOUBLE PRECISION,
    final_sweetness_score DOUBLE PRECISION,
    community_vote_count INTEGER NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (dish_id)
);

-- ─────────────────────────────────────────────
-- edit_suggestions
-- ─────────────────────────────────────────────
CREATE TABLE edit_suggestions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_type     entity_type NOT NULL,
    entity_id       UUID NOT NULL,
    field           TEXT NOT NULL, -- e.g. 'name', 'location', 'cuisine_type'
    proposed_value  TEXT NOT NULL,
    suggested_by    UUID NOT NULL REFERENCES users(id),
    status          edit_status NOT NULL DEFAULT 'pending',
    net_votes       INTEGER NOT NULL DEFAULT 0,
    expires_at      TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '7 days'),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_edit_suggestions_entity ON edit_suggestions(entity_type, entity_id, status);

-- ─────────────────────────────────────────────
-- edit_approvals
-- ─────────────────────────────────────────────
CREATE TABLE edit_approvals (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    suggestion_id   UUID NOT NULL REFERENCES edit_suggestions(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id),
    vote            vote_direction NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (suggestion_id, user_id)
);

-- ─────────────────────────────────────────────
-- user_taste_vectors
-- ─────────────────────────────────────────────
CREATE TABLE user_taste_vectors (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                 UUID NOT NULL REFERENCES users(id) UNIQUE,
    spice_preference        DOUBLE PRECISION NOT NULL DEFAULT 0.5,
    sweetness_preference    DOUBLE PRECISION NOT NULL DEFAULT 0.5,
    cuisine_distribution    JSONB NOT NULL DEFAULT '{}',
    dish_type_distribution  JSONB NOT NULL DEFAULT '{}',
    reaction_count          INTEGER NOT NULL DEFAULT 0,
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_taste_vectors_user ON user_taste_vectors(user_id);

-- ─────────────────────────────────────────────
-- favorites
-- ─────────────────────────────────────────────
CREATE TABLE favorites (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES users(id),
    dish_id     UUID NOT NULL REFERENCES dishes(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, dish_id)
);

CREATE INDEX idx_favorites_user ON favorites(user_id);

-- ─────────────────────────────────────────────
-- images
-- ─────────────────────────────────────────────
CREATE TABLE images (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_type  entity_type NOT NULL,
    entity_id    UUID NOT NULL,
    uploaded_by  UUID NOT NULL REFERENCES users(id),
    r2_key       TEXT NOT NULL UNIQUE,
    is_public    BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at   TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_images_entity ON images(entity_type, entity_id);

-- ─────────────────────────────────────────────
-- admin_flags (abuse detection)
-- ─────────────────────────────────────────────
CREATE TABLE admin_flags (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES users(id),
    reason      TEXT NOT NULL,
    metadata    JSONB,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
