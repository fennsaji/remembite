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
| Google Places API | Restaurant discovery + metadata (name, location, hours, phone, website, price level, Google rating) | ✅ Official API, paid per call |
| Zomato / Swiggy listing pages | Menu text extraction | ⚠️ Legally grey (ToS), fragile to UI changes — treated as best-effort only |
| Gemini LLM | Parse raw menu HTML/text into structured `{name, category, price}` | ✅ Already used in existing OCR pipeline |

Menu scraping is **non-fatal** — restaurants are always created even if menu fetch/parse fails. Menu data can be supplemented later via the existing OCR scan feature.

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
2. Divide into 2km grid → list of (lat, lng) grid points
3. For each grid point:
   a. Google Places Nearby Search (type=restaurant, radius=1500m, min_rating=3.5)
   b. Collect unique place_ids
4. For each unique place_id not yet in DB:
   a. Google Places Details API → name, phone, website, hours, price_level, coords
   b. INSERT restaurants ON CONFLICT (google_place_id) DO UPDATE
5. For each newly created restaurant with 0 dishes:
   a. Search Zomato/Swiggy for "{restaurant_name} {city}"
   b. Fetch listing page HTML
   c. Extract menu section text
   d. Call Gemini: "Extract dish names, categories, prices from this menu. Return JSON."
   e. INSERT dishes ON CONFLICT (restaurant_id, name) DO NOTHING
   f. Enqueue Job::ClassifyDish for each new dish
6. Update crawl_runs record with final counts + status=completed
```

### Scheduling

```rust
// In main.rs, after AppState construction:
tokio::spawn(async move {
    let mut interval = tokio::time::interval(Duration::from_secs(7 * 24 * 3600));
    loop {
        interval.tick().await;
        crawler_service.run_all_cities().await;
    }
});
```

First tick fires immediately (to seed on fresh deploy). Subsequent ticks every 7 days.

---

## Database Changes

### New migration: `0009_crawler.sql`

```sql
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
    lat_min         FLOAT NOT NULL,
    lat_max         FLOAT NOT NULL,
    lng_min         FLOAT NOT NULL,
    lng_max         FLOAT NOT NULL,
    enabled         BOOL NOT NULL DEFAULT true,
    last_crawled_at TIMESTAMPTZ
);
```

### Seed data: `0009_crawler_seed.sql`

Initial 18 cities seeded via INSERT statements with bounding boxes:

**Metro cities (8)**: Mumbai, Delhi NCR, Bangalore, Hyderabad, Chennai, Kolkata, Pune, Ahmedabad

**Tier-2 cities (10)**: Jaipur, Lucknow, Surat, Indore, Bhopal, Chandigarh, Kochi, Coimbatore, Visakhapatnam, Nagpur

**No schema changes** to `restaurants` or `dishes` tables — `google_place_id` UNIQUE constraint already exists; dish dedup uses `(restaurant_id, name)`.

---

## New Files

| File | Purpose |
|---|---|
| `backend/migrations/0009_crawler.sql` | `crawl_runs` + `crawler_cities` tables |
| `backend/migrations/0009_crawler_seed.sql` | 18 city bounding boxes |
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
| Zomato/Swiggy fetch fails | Log warn, skip menu — restaurant still created |
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

Google Places charges:
- Nearby Search: $32/1000 requests
- Place Details: $17/1000 requests

Per city (estimated):
- Grid points: ~100 per metro, ~40 per Tier-2 city → ~900 Nearby Search calls total
- Places found: ~5000 restaurants → 5000 Place Details calls
- Total first run: ~$0.03 (Nearby Search) + ~$0.09 (Details) ≈ **$0.12 per city**, **~$2.50 for all 18 cities**

Weekly refresh crawl would be significantly cheaper (skips already-indexed `place_id`s).

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
