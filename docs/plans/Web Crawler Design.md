# Web Crawler — Design Document

**Date**: 2026-03-06
**Status**: Approved
**Phase**: New (Phase 9 candidate)

---

## Problem

Remembite's restaurant database is currently empty. Users must manually add restaurants before they can record any dish reactions. This creates a cold-start problem: new users open the app, see no restaurants nearby, and churn before experiencing any value.

## Goal

Pre-seed the database with top-rated restaurants (≥3.5 stars) from 18 major Indian cities, and where possible, pre-populate their menus so community intelligence can start accumulating immediately.

---

## Data Sources

| Source | Usage | Legal status |
|---|---|---|
| Google Places Nearby Search (Legacy API) | Restaurant discovery — returns place_id, name, coords, rating, price_level, business_status | ⚠️ Official API; persistent storage violates ToS Section 3.2.3 — accepted risk (see Legal Risks) |
| Google Places Details API | Lazy per-restaurant enrichment on user visit — returns phone, website, opening_hours | ⚠️ Same ToS risk as Nearby Search — accepted |
| Restaurant's own website | Menu data — only source. URL comes from Place Details `website` field (populated at enrichment time). | ✅ Legal — restaurant's own public content |
| Gemini LLM | Parse raw menu HTML/text into structured `{name, category, price}` | ✅ Already used in existing OCR pipeline |
| User OCR | Long-tail menu data for restaurants the crawler misses | ✅ Existing pipeline |

Menu scraping is **non-fatal** — restaurants are always created even if menu fetch/parse fails. Menu data can be supplemented later via the existing OCR scan feature.

---

## Legal Risks

| Risk | Likelihood | Severity | Mitigation |
|---|---|---|---|
| Google suspends API key (ToS: persistent storage) | Low — Google targets competitors, not small restaurant apps | High — app breaks | Re-fetch + refresh records every 90 days (lazy enrichment); proper attribution |
| Restaurant website scraping ToS violation | Very low — it's their own public menu data | Low | None needed |

**Decision**: Accept Google ToS risk at current stage. Revisit when approaching 10k MAU or if a C&D is received.

---

## Architecture

### Component: `CrawlerService`

New file: `backend/src/services/crawler.rs`

```
CrawlerService {
    db: PgPool,
    http: reqwest::Client,
    llm: Arc<dyn LlmProvider>,
    config: Arc<Config>,
}
```

**Initialization**: created in `main.rs` alongside `AppState`. On startup, `tokio::spawn` a weekly background interval task. Also exposed via admin API for on-demand runs.

### Pipeline (per city)

```
1. Load city bounding box from crawler_cities table
2. Select next ~1,560 crawl_grid_points (last_scanned_at IS NULL OR < 4 months ago)
3. For each grid point:
   a. Google Places Legacy Nearby Search (type=restaurant, radius=1500m, min_rating=3.5)
   b. For each result: collect place_id, name, coords, rating, user_ratings_total, price_level, business_status
   c. Update crawl_grid_points.last_scanned_at = NOW()
4. For each unique place_id not yet in DB:
   a. INSERT restaurant with Nearby Search fields: name, coords, google_place_id, rating, price_level, business_status
   b. ON CONFLICT (google_place_id) DO NOTHING
5. Update crawl_runs record with final counts + status=completed

Menu seeding and Place Details are NOT called during the crawl — see "Place Details Enrichment" section below.
```

### Scheduling

DB-backed monthly scheduler — avoids the `tokio::time::interval` problem (server restarts reset the timer and fire immediately on next start, consuming quota on every deploy):

```rust
// In main.rs, after AppState construction:
tokio::spawn(async move {
    loop {
        // Check last successful crawl completion time
        let last_run: Option<chrono::DateTime<chrono::Utc>> = sqlx::query_scalar(
            "SELECT MAX(completed_at) FROM crawl_runs WHERE status = 'completed'"
        )
        .fetch_optional(&crawler_bg.db)
        .await.ok().flatten();

        let should_run = last_run
            .map(|t| chrono::Utc::now() - t > chrono::Duration::days(30))
            .unwrap_or(true); // No previous run → run immediately on first deploy

        if should_run {
            tracing::info!("monthly crawler starting");
            crawler_bg.run_all_cities().await;
        }
        // Poll every hour; actual crawl only runs when >30 days since last
        tokio::time::sleep(Duration::from_secs(3600)).await;
    }
});
```

This means:
- Fresh deploy with no crawl history → runs immediately
- Restarts after that → skips until 30 days have elapsed
- `CRAWLER_ENABLED=false` skips the spawn entirely (for local dev)

---

## Database Changes

### New migration: `0009_crawler.sql`

```sql
-- System user for crawler-created data (FK target for restaurants.created_by)
-- UUID nil (all zeros) is the conventional "system" actor.
INSERT INTO users (id, email, display_name, created_at, updated_at)
VALUES (
    '00000000-0000-0000-0000-000000000000',
    'system@remembite.internal',
    'Remembite Crawler',
    NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

-- Partial unique index on google_place_id (required for ON CONFLICT upsert)
-- Only enforces uniqueness when the column is non-null.
CREATE UNIQUE INDEX IF NOT EXISTS restaurants_google_place_id_uidx
    ON restaurants(google_place_id)
    WHERE google_place_id IS NOT NULL;

-- Track crawl jobs for monitoring and deduplication
CREATE TABLE crawl_runs (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    city              VARCHAR NOT NULL,
    status            VARCHAR NOT NULL DEFAULT 'running',  -- running | completed | failed
    restaurants_found INT NOT NULL DEFAULT 0,
    dishes_found      INT NOT NULL DEFAULT 0,
    started_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at      TIMESTAMPTZ
);

-- Config-driven city list (admin can add cities without code deploy)
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

-- Pre-generated grid points for all 18 cities (~5,500 rows).
-- Crawler processes these in order, budget-capped per monthly run.
CREATE TABLE crawl_grid_points (
    id              SERIAL PRIMARY KEY,
    city            VARCHAR NOT NULL,
    lat             DOUBLE PRECISION NOT NULL,
    lng             DOUBLE PRECISION NOT NULL,
    last_scanned_at TIMESTAMPTZ,   -- NULL = never scanned; drives crawl ordering
    scan_count      INT NOT NULL DEFAULT 0
);

-- enriched_at on restaurants table
ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS enriched_at TIMESTAMPTZ;
```

### Seed data: `0010_crawler_seed.sql`

Initial 18 cities seeded via INSERT statements with bounding boxes:

**Metro cities (8)**: Mumbai, Delhi NCR, Bangalore, Hyderabad, Chennai, Kolkata, Pune, Ahmedabad

**Tier-2 cities (10)**: Jaipur, Lucknow, Surat, Indore, Bhopal, Chandigarh, Kochi, Coimbatore, Visakhapatnam, Nagpur

**No schema changes** to `restaurants` or `dishes` tables — `google_place_id` UNIQUE constraint already exists; dish dedup uses `(restaurant_id, name)`.

---

## New Files

| File | Purpose |
|---|---|
| `backend/migrations/0009_crawler.sql` | System user, partial UNIQUE index, `crawl_runs`, `crawler_cities`, `crawl_grid_points` tables, `enriched_at` column |
| `backend/migrations/0010_crawler_seed.sql` | 18 city bounding boxes |
| `backend/src/services/crawler.rs` | `CrawlerService` implementation |
| `backend/src/routes/admin_crawler.rs` | Admin HTTP endpoints |

## Modified Files

| File | Change |
|---|---|
| `backend/src/main.rs` | Spawn weekly background task; register admin crawler routes |
| `backend/src/config.rs` | Add `google_places_api_key: String` |
| `backend/src/services/mod.rs` | Expose `pub mod crawler` |
| `backend/src/routes/mod.rs` (or `main.rs`) | Register `admin_crawler::router()` |

---

## Menu Seeding Strategy

### Source

For each newly crawled restaurant with 0 dishes:

**1. Restaurant's own website (only source — legal)**
- URL comes from Google Places Details API `website` field, populated lazily at first user visit (enrichment)
- Triggered only when `enriched_at IS NULL` AND `dish_count = 0`
- Try `{website}/menu` first, then `{website}` root
- Extract all visible text using `scraper` HTML parser (strips scripts/styles/nav/footer)
- Minimum 200 chars of text required to proceed
- Expected coverage: ~20–30% (restaurants that have their own website AND include a parseable menu page)

**2. User OCR (long-tail — always available)**
- Existing pipeline handles restaurants the crawler misses
- Not part of the crawler — passive contribution from users scanning menus in-restaurant
- Covers the remaining ~70–80% of restaurants over time

**Note on Zomato/Swiggy**: Not viable. Zomato pages are client-side rendered (JS loads the menu after initial page load), reqwest receives an empty shell HTML. Bot protection (Cloudflare) blocks automated requests. URL structure requires an area slug not predictable from restaurant names alone. Dropped entirely.

### LLM Parsing

Extracted text (≤4,000 chars) passed to `LlmProvider::parse_menu_ocr` (existing Gemini pipeline):
- Returns `Vec<ParsedDish>` with `name`, `category: Option<String>`, `price_rupees: Option<i32>`
- On parse failure or empty result: log warn, skip dishes — restaurant still created
- Each new dish: `INSERT ON CONFLICT (restaurant_id, name) DO NOTHING` → enqueue `Job::ClassifyDish`

### Expected Coverage

| Source | Hit rate | Notes |
|---|---|---|
| Restaurant own website | ~20–30% | Restaurants with own website that includes a parseable menu page |
| No menu seeded (0 dishes) | ~70–80% | Menu populated by users via OCR over time |

Menu seeding is strictly **best-effort** — the crawler always creates the restaurant record regardless of menu outcome.

---

## Place Details Enrichment (On User Visit)

Place Details API is **not called during the crawl**. It is called lazily when a user views a restaurant page.

**Trigger** (in `GET /restaurants/:id`):
```
IF restaurant.enriched_at IS NULL
OR restaurant.enriched_at < NOW() - INTERVAL '90 days'
THEN:
  1. Fetch Place Details → update phone, website, opening_hours, enriched_at
  2. IF dish_count = 0 AND website IS NOT NULL:
       → attempt menu seeding (fetch website → Gemini parse → insert dishes)
```

This means:
- Crawler cost = **$0** (Nearby Search only, within 5,000 free events/month)
- Place Details cost = only for restaurants users actually visit
- Menu seeding happens the first time a user opens a restaurant page — not proactively
- 90-day refresh cycle satisfies Google ToS "not stored indefinitely"

---

## Monthly Budget Model

| Item | Monthly cost | Notes |
|---|---|---|
| Nearby Search (Legacy) | **$0** | 1,560 grid points/month within the 5,000 free events/month limit |
| Place Details (lazy enrichment) | **~$0–6** | Only for restaurants users actually visit; <150 calls/month early-stage × $0.040 |
| **Total crawler cost** | **$0** | |

Full city coverage completes in ~4 months (~5,500 grid points / ~1,560 per month). Crawler then restarts the cycle, picking up new restaurants and satisfying ToS data refresh requirement.

**Note on free credit**: As of March 2025, Google replaced the $200/month free credit with per-SKU free tiers. Nearby Search Pro: 5,000 free events/month. Place Details: no free tier — billed at $0.040/1,000 requests. At early-stage user counts, Place Details cost is negligible.

---

## Admin API

All endpoints require admin JWT.

```
POST /admin/crawl              — trigger crawl for all enabled cities (returns immediately, runs in background)
POST /admin/crawl/:city        — trigger crawl for one city by name (e.g., "Mumbai")
GET  /admin/crawl/runs         — list 20 most recent crawl_runs (id, city, status, counts, timestamps)
```

---

## Error Handling

| Failure | Behavior |
|---|---|
| Google Places API 429 | Exponential backoff: 100ms → 200ms → 400ms (max 3 retries), then skip grid point |
| Place Details API failure | Log warn, skip restaurant (don't create partial record) |
| Website fetch fails or returns < 200 chars | Log debug, skip menu — restaurant still created |
| Gemini parse returns malformed JSON | Log warn, skip dishes — restaurant still created |
| Individual restaurant error | Catch, log, continue to next restaurant |
| Entire city crawl panics | Catch at city level, set `crawl_runs.status = 'failed'`, continue to next city |

---

## Config

New env vars to add to `.env.example` and `Config` struct:

```
GOOGLE_PLACES_API_KEY=        # Required for restaurant discovery
CRAWLER_ENABLED=true          # Set false to disable background scheduler
CRAWLER_MIN_RATING=3.5        # Minimum Google rating to include a restaurant
CRAWLER_GRID_STEP_KM=2.0      # Grid density for city coverage
```

---

## Cost Estimate (Google Places API)

Google Places API pricing (as of March 2025 — new per-SKU model, $200/month credit removed):

| SKU | Price | Free tier |
|---|---|---|
| Nearby Search Pro (Legacy) | $0.032/request | 5,000 free events/month |
| Place Details | $0.040/request | None |

**Nearby Search cost:**
- 1,560 grid points/month within the 5,000 free events/month limit
- Monthly cost: **$0**

**Place Details cost (lazy enrichment on user visits):**
- Only triggered when `enriched_at IS NULL OR < 90 days`
- Early-stage: <150 calls/month = **~$6/month**
- Grows with user count; scales with actual usage

**Total crawler cost: $0/month.** Place Details is a product cost, not a crawler cost — it only runs when users generate value.

---

## Non-Goals

- No web frontend for crawler management (admin API only)
- No Apple Maps or other data sources in v1
- No real-time streaming results — crawl runs fully before restaurants appear
- No user-facing notification when new restaurants are added to their city

---

## Success Criteria

1. After initial crawl: ≥500 restaurants per metro city, ≥200 per Tier-2 city in DB
2. ≥40% of restaurants have at least 5 pre-populated dishes
3. `cargo check` clean, weekly cron fires without crashing API
4. Admin can check crawl status via `GET /admin/crawl/runs`
