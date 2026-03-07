# Web Crawler Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Pre-seed Remembite's database with top-rated restaurants from 18 Indian cities via Google Places API, and parse their menus using website scraping + Gemini LLM.

**Architecture:** A `CrawlerService` module inside the existing backend (`backend/src/services/crawler.rs`) runs as a DB-backed monthly background task. The pipeline per city: Google Places **Legacy** Nearby Search → restaurant upsert (Nearby Search data only). Place Details, menu seeding, and `seed_dishes` are **not called during the crawl** — they are triggered lazily from `GET /restaurants/:id` when `enriched_at IS NULL OR < 90 days`. Admin endpoints allow on-demand crawl triggers and run monitoring.

**Legal context:** Storing Google Places data: ToS grey area, low enforcement risk at this scale. Restaurant own website scraping: legal. Zomato/Swiggy scraping: dropped — not viable (CSR, bot protection). See design doc for full risk assessment.

**Cost model:** Crawler cost = $0/month (Nearby Search only, within 5,000 free events/month). Place Details cost = ~$0–6/month early-stage, only for restaurants users actually visit (90-day lazy enrichment).

**Tech Stack:** Rust/Axum, SQLx (PostgreSQL), `reqwest` (HTTP), `scraper` crate (HTML parsing), existing `LlmProvider::parse_menu_ocr`, existing `Job::ClassifyDish` queue.

---

## Before You Start

```bash
cd backend && cargo check   # must be clean before starting
```

Key files to understand first (read-only, don't modify yet):
- `backend/src/config.rs` — `Config` struct (you'll add fields)
- `backend/src/services/mod.rs` — add `pub mod crawler;` here
- `backend/src/llm/provider.rs` — `LlmProvider` trait; `parse_menu_ocr` is what we use for menus
- `backend/src/jobs/mod.rs` — `Job` enum; `ClassifyDish` is what we enqueue after creating dishes
- `backend/src/main.rs` — where AppState is built and routes registered
- `backend/src/routes/dishes.rs` — look for how dishes are inserted (ON CONFLICT pattern)
- `backend/src/dto/mod.rs` — add `CrawlRunResponse` here

---

## Task 1: Add `scraper` crate dependency

**Files:**
- Modify: `backend/Cargo.toml`

The `scraper` crate parses HTML to extract text content from restaurant websites.

**Step 1: Add the dependency**

Open `backend/Cargo.toml` and add to `[dependencies]`:
```toml
scraper = "0.25"
```

**Step 2: Verify it compiles**

```bash
cd backend && cargo check
```
Expected: 0 errors (new dep downloads, no code changes yet).

**Step 3: Commit**
```bash
git add backend/Cargo.toml backend/Cargo.lock
git commit -m "chore: add scraper HTML parser dependency for web crawler"
```

---

## Task 2: Database migration — crawler tables

**Files:**
- Create: `backend/migrations/0009_crawler.sql`

**Step 1: Create the migration file**

```sql
-- backend/migrations/0009_crawler.sql

-- System user row (FK target for restaurants/dishes created_by = nil UUID)
-- Must be first so foreign key inserts in later steps succeed.
INSERT INTO users (id, email, display_name, created_at, updated_at)
VALUES (
    '00000000-0000-0000-0000-000000000000',
    'system@remembite.internal',
    'Remembite Crawler',
    NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

-- Partial unique index required for ON CONFLICT (google_place_id) DO NOTHING upserts.
-- google_place_id was added in an earlier migration as a plain nullable column (no UNIQUE).
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

-- Pre-generated grid points (~5,500 rows total for 18 cities).
-- last_scanned_at drives monthly crawl ordering (NULL = never scanned → highest priority).
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
```

**Step 2: Verify migration file is syntactically valid**

The migration runs automatically on startup (`sqlx::migrate!`). Check that the file is in the migrations directory and named with the correct sequence number:
```bash
ls backend/migrations/ | sort
```
Expected: `0009_crawler.sql` is the latest file.

**Step 3: Commit**
```bash
git add backend/migrations/0009_crawler.sql
git commit -m "feat(crawler): system user, UNIQUE index, crawl_runs, crawler_cities, crawl_grid_points tables"
```

---

## Task 3: Seed 18 cities

**Files:**
- Create: `backend/migrations/0010_crawler_seed.sql`

These INSERT statements populate `crawler_cities` with bounding boxes for 8 metro + 10 Tier-2 cities. Bounding boxes are approximate city extents in decimal degrees. The `crawl_grid_points` table will be populated programmatically by the first crawl run (the `CrawlerService` generates and inserts grid points on first use), but `crawler_cities` must exist first.

**Step 1: Create the seed migration**

```sql
-- backend/migrations/0010_crawler_seed.sql

INSERT INTO crawler_cities (name, lat_min, lat_max, lng_min, lng_max) VALUES
-- Metro cities
('Mumbai',          18.89, 19.27, 72.77, 73.03),
('Delhi NCR',       28.40, 28.88, 76.84, 77.57),
('Bangalore',       12.83, 13.14, 77.46, 77.75),
('Hyderabad',       17.27, 17.60, 78.25, 78.60),
('Chennai',         12.90, 13.23, 80.15, 80.30),
('Kolkata',         22.47, 22.65, 88.29, 88.43),
('Pune',            18.43, 18.64, 73.76, 73.98),
('Ahmedabad',       22.95, 23.13, 72.49, 72.68),
-- Tier-2 cities
('Jaipur',          26.79, 26.98, 75.71, 75.90),
('Lucknow',         26.79, 26.96, 80.88, 81.05),
('Surat',           21.10, 21.27, 72.77, 72.94),
('Indore',          22.63, 22.78, 75.79, 75.93),
('Bhopal',          23.16, 23.32, 77.33, 77.50),
('Chandigarh',      30.65, 30.77, 76.72, 76.86),
('Kochi',            9.91, 10.05, 76.22, 76.36),
('Coimbatore',      10.96, 11.08, 76.92, 77.06),
('Visakhapatnam',   17.64, 17.78, 83.17, 83.30),
('Nagpur',          21.07, 21.22, 79.00, 79.15)
ON CONFLICT (name) DO NOTHING;
```

**Step 2: Verify sequence order**
```bash
ls backend/migrations/ | sort
```
Expected: `0009_crawler.sql` then `0010_crawler_seed.sql` as the last two files.

**Step 3: Commit**
```bash
git add backend/migrations/0010_crawler_seed.sql
git commit -m "feat(crawler): seed 18 Indian cities with bounding boxes"
```

---

## Task 4: Config — add Google Places API key and crawler settings

**Files:**
- Modify: `backend/src/config.rs`
- Modify: `.env.example`

**Step 1: Add fields to `Config` struct**

In `backend/src/config.rs`, add these fields to the `Config` struct after `bayesian_prior_weight`:
```rust
pub google_places_api_key: String,
pub crawler_enabled: bool,
pub crawler_min_rating: f64,
pub crawler_grid_step_km: f64,
```

**Step 2: Add parsing in `Config::from_env()`**

In the `Ok(Config { ... })` block, add after `bayesian_prior_weight`:
```rust
google_places_api_key: env_or("GOOGLE_PLACES_API_KEY", ""),
crawler_enabled: env_or("CRAWLER_ENABLED", "true") == "true",
crawler_min_rating: parse_env("CRAWLER_MIN_RATING", 3.5f64)?,
crawler_grid_step_km: parse_env("CRAWLER_GRID_STEP_KM", 2.0f64)?,
```

**Step 3: Update `.env.example`**

Add these lines to `.env.example`:
```
# Web Crawler
GOOGLE_PLACES_API_KEY=           # Required for restaurant discovery
CRAWLER_ENABLED=true             # Set false to disable background scheduler
CRAWLER_MIN_RATING=3.5           # Minimum Google rating to import
CRAWLER_GRID_STEP_KM=2.0         # Grid density (2km = overlapping 1500m circles)
```

**Step 4: Verify it compiles**
```bash
cd backend && cargo check
```
Expected: 0 errors.

**Step 5: Commit**
```bash
git add backend/src/config.rs .env.example
git commit -m "feat(crawler): add Google Places API key and crawler config vars"
```

---

## Task 5: DTO — add `CrawlRunResponse`

**Files:**
- Modify: `backend/src/dto/mod.rs`

**Step 1: Add after the Bootstrap DTOs section (end of file)**

```rust
// ─────────────────────────────────────────────
// Crawler DTOs
// ─────────────────────────────────────────────

#[derive(Debug, Serialize)]
pub struct CrawlRunResponse {
    pub id: Uuid,
    pub city: String,
    pub status: String,
    pub restaurants_found: i32,
    pub dishes_found: i32,
    pub started_at: chrono::DateTime<chrono::Utc>,
    pub completed_at: Option<chrono::DateTime<chrono::Utc>>,
}
```

**Step 2: Verify**
```bash
cd backend && cargo check
```
Expected: 0 errors.

**Step 3: Commit**
```bash
git add backend/src/dto/mod.rs
git commit -m "feat(crawler): add CrawlRunResponse DTO"
```

---

## Task 6: `CrawlerService` skeleton + grid math

**Files:**
- Create: `backend/src/services/crawler.rs`
- Modify: `backend/src/services/mod.rs`

This task creates the service struct and implements the grid generation logic — the only pure function in the crawler, so we write a unit test for it.

**Step 1: Write the failing unit test first**

Create `backend/src/services/crawler.rs` with just the test (TDD):

```rust
use std::sync::Arc;
use sqlx::PgPool;
use crate::{config::Config, llm::provider::LlmProvider};

pub struct CrawlerService {
    pub db: PgPool,
    pub http: reqwest::Client,
    pub llm: Arc<dyn LlmProvider>,
    pub config: Arc<Config>,
}

impl CrawlerService {
    pub fn new(
        db: PgPool,
        http: reqwest::Client,
        llm: Arc<dyn LlmProvider>,
        config: Arc<Config>,
    ) -> Self {
        Self { db, http, llm, config }
    }
}

/// Generate a grid of (lat, lng) points covering a bounding box at the given step size.
/// step_km: distance between grid points in km (2.0 = good overlap with 1500m search radius)
pub fn grid_points(
    lat_min: f64, lat_max: f64,
    lng_min: f64, lng_max: f64,
    step_km: f64,
) -> Vec<(f64, f64)> {
    let lat_step = step_km / 111.0;
    let mid_lat = (lat_min + lat_max) / 2.0;
    let lng_step = step_km / (111.0 * mid_lat.to_radians().cos()).max(0.001);

    let mut points = Vec::new();
    let mut lat = lat_min;
    while lat <= lat_max {
        let mut lng = lng_min;
        while lng <= lng_max {
            points.push((lat, lng));
            lng += lng_step;
        }
        lat += lat_step;
    }
    points
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn grid_points_covers_bbox() {
        // Bangalore bounding box
        let points = grid_points(12.83, 13.14, 77.46, 77.75, 2.0);

        // Must have at least 1 point
        assert!(!points.is_empty(), "grid must not be empty");

        // All points must be within the bounding box
        for (lat, lng) in &points {
            assert!(*lat >= 12.83 && *lat <= 13.14, "lat {lat} out of range");
            assert!(*lng >= 77.46 && *lng <= 77.75, "lng {lng} out of range");
        }

        // A 2km grid over a ~35x30km city should produce ~200-400 points
        assert!(points.len() > 50, "too few points: {}", points.len());
        assert!(points.len() < 1000, "too many points: {}", points.len());
    }

    #[test]
    fn grid_points_single_point_bbox() {
        // Degenerate case: lat_min == lat_max, lng_min == lng_max
        let points = grid_points(12.97, 12.97, 77.59, 77.59, 2.0);
        assert_eq!(points.len(), 1);
        assert!((points[0].0 - 12.97).abs() < 0.001);
        assert!((points[0].1 - 77.59).abs() < 0.001);
    }
}
```

**Step 2: Add module to `services/mod.rs`**

```rust
// add this line to backend/src/services/mod.rs
pub mod crawler;
```

**Step 3: Run the tests to verify they pass**

```bash
cd backend && cargo test services::crawler::tests -- --nocapture
```
Expected: 2 tests pass. If they fail, check the `lat_step` and `lng_step` math.

**Step 4: Commit**
```bash
git add backend/src/services/crawler.rs backend/src/services/mod.rs
git commit -m "feat(crawler): CrawlerService skeleton + grid_points with tests"
```

---

## Task 7: Google Places Nearby Search API

**Files:**
- Modify: `backend/src/services/crawler.rs`

This implements the HTTP call to the Google Places Nearby Search endpoint. Add these private types and the method to `crawler.rs`.

**Step 1: Add serde types for Google Places API response (private, top of file)**

Add these after the imports:

```rust
use serde::Deserialize;

// ── Google Places API response types (private) ──────────────────────────────

#[derive(Deserialize)]
struct PlacesNearbyResponse {
    results: Vec<NearbyResult>,
    #[serde(default)]
    next_page_token: Option<String>,
}

#[derive(Deserialize)]
struct NearbyResult {
    place_id: String,
    #[serde(default)]
    name: String,
    #[serde(default)]
    rating: Option<f64>,
    #[serde(default)]
    user_ratings_total: Option<i64>,
    #[serde(default)]
    price_level: Option<i64>,
    #[serde(default)]
    business_status: Option<String>,
    geometry: Option<PlaceGeometry>,
}

#[derive(Deserialize)]
struct PlaceDetailsResponse {
    result: PlaceDetail,
}

#[derive(Deserialize, Default)]
struct PlaceDetail {
    #[serde(default)]
    name: String,
    #[serde(default)]
    formatted_phone_number: Option<String>,
    #[serde(default)]
    website: Option<String>,
    #[serde(default)]
    price_level: Option<i64>,
    #[serde(default)]
    rating: Option<f64>,
    #[serde(default)]
    user_ratings_total: Option<i64>,
    #[serde(default)]
    business_status: Option<String>,
    #[serde(default)]
    opening_hours: Option<serde_json::Value>,
    geometry: Option<PlaceGeometry>,
}

#[derive(Deserialize)]
struct PlaceGeometry {
    location: LatLng,
}

#[derive(Deserialize)]
struct LatLng {
    lat: f64,
    lng: f64,
}
```

**Step 2: Add `nearby_search()` method to `impl CrawlerService`**

```rust
impl CrawlerService {
    // ... existing new() ...

    /// Call Google Places Legacy Nearby Search. Returns results filtered to min_rating.
    /// Handles a single page; caller paginates via next_page_token if needed.
    async fn nearby_search(
        &self,
        lat: f64,
        lng: f64,
        next_page_token: Option<&str>,
    ) -> anyhow::Result<(Vec<NearbyResult>, Option<String>)> {
        let url = if let Some(token) = next_page_token {
            format!(
                "https://maps.googleapis.com/maps/api/place/nearbysearch/json\
                 ?pagetoken={token}&key={key}",
                key = self.config.google_places_api_key,
            )
        } else {
            format!(
                "https://maps.googleapis.com/maps/api/place/nearbysearch/json\
                 ?location={lat},{lng}&radius=1500&type=restaurant&key={key}",
                key = self.config.google_places_api_key,
            )
        };

        let resp: PlacesNearbyResponse = self
            .http
            .get(&url)
            .send()
            .await?
            .json()
            .await?;

        let min_rating = self.config.crawler_min_rating;
        let results: Vec<NearbyResult> = resp
            .results
            .into_iter()
            .filter(|r| r.rating.unwrap_or(0.0) >= min_rating)
            .collect();

        Ok((results, resp.next_page_token))
    }
}
```

**Step 3: Verify**
```bash
cd backend && cargo check
```
Expected: 0 errors.

**Step 4: Commit**
```bash
git add backend/src/services/crawler.rs
git commit -m "feat(crawler): Google Places Nearby Search API call"
```

---

## Task 8: Restaurant upsert from Nearby Search data

**Files:**
- Modify: `backend/src/services/crawler.rs`

The crawler inserts restaurants using only the fields returned by Nearby Search — no Place Details call during crawl. `website`, `phone_number`, and `opening_hours` are left NULL; they are populated lazily when the first user views the restaurant page (see "Place Details enrichment" in the design doc).

**Step 1: Add `place_details()` method** (used by `restaurants.rs` enrichment handler, not by the crawler itself)

```rust
impl CrawlerService {
    // ... previous methods ...

    /// Fetch full details for a single place_id. Called from GET /restaurants/:id enrichment,
    /// NOT from the crawl pipeline.
    pub async fn place_details(&self, place_id: &str) -> anyhow::Result<Option<PlaceDetail>> {
        let fields = "name,formatted_phone_number,website,price_level,rating,\
                      user_ratings_total,business_status,opening_hours,geometry";
        let url = format!(
            "https://maps.googleapis.com/maps/api/place/details/json\
             ?place_id={place_id}&fields={fields}&key={key}",
            key = self.config.google_places_api_key,
        );

        let resp: PlaceDetailsResponse = self
            .http
            .get(&url)
            .send()
            .await?
            .json()
            .await?;

        if resp.result.name.is_empty() {
            return Ok(None);
        }
        Ok(Some(resp.result))
    }
}
```

**Step 2: Add `upsert_restaurant()` method**

Takes a `NearbyResult` (from Nearby Search). `city` is passed from the `crawler_cities` row.

```rust
impl CrawlerService {
    async fn upsert_restaurant(
        &self,
        result: &NearbyResult,
        city: &str,
    ) -> anyhow::Result<Option<uuid::Uuid>> {
        let geo = match &result.geometry {
            Some(g) => g,
            None => {
                tracing::warn!(place_id = %result.place_id, "no geometry, skipping");
                return Ok(None);
            }
        };

        let id = uuid::Uuid::new_v4();

        // System user (nil UUID = 00000000-0000-0000-0000-000000000000)
        // This FK reference is valid because migration 0009 inserts the system user row first.
        let system_user = uuid::Uuid::nil();

        sqlx::query(
            r#"
            INSERT INTO restaurants (
                id, name, city, latitude, longitude, created_by,
                google_place_id, google_rating, google_rating_count,
                price_level, business_status
            )
            VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
            ON CONFLICT (google_place_id) DO NOTHING
            "#,
        )
        .bind(id)
        .bind(&result.name)
        .bind(city)
        .bind(geo.location.lat)
        .bind(geo.location.lng)
        .bind(system_user)
        .bind(&result.place_id)
        .bind(result.rating)
        .bind(result.user_ratings_total.map(|n| n as i32))
        .bind(result.price_level.map(|n| n as i16))
        .bind(&result.business_status)
        .execute(&self.db)
        .await?;

        // Re-fetch the ID (handles ON CONFLICT DO NOTHING race condition)
        let actual_id: uuid::Uuid = sqlx::query_scalar(
            "SELECT id FROM restaurants WHERE google_place_id = $1",
        )
        .bind(&result.place_id)
        .fetch_one(&self.db)
        .await?;

        Ok(Some(actual_id))
    }
}
```

**Step 3: Verify**
```bash
cd backend && cargo check
```
Expected: 0 errors.

**Step 4: Commit**
```bash
git add backend/src/services/crawler.rs
git commit -m "feat(crawler): place_details method + restaurant upsert from Nearby Search data"
```

---

## Task 9: Menu fetch (restaurant website only)

**Files:**
- Modify: `backend/src/services/crawler.rs`

Menu scraping is **best-effort**: returns `None` if scraping fails. The crawler continues regardless.

The only strategy: restaurant's own `website` field (from Place Details). No Zomato/Swiggy fallback — both are client-side rendered and blocked by bot protection; see design doc.

**Step 1: Add imports at the top of `crawler.rs`**

```rust
use scraper::{Html, Selector};
```

**Step 2: Add `extract_text()` helper (private, outside `impl` block)**

```rust
/// Extract visible text from an HTML page, ignoring scripts/styles/nav/footer.
fn extract_text(html: &str) -> String {
    let doc = Html::parse_document(html);
    let body_sel = Selector::parse("body").unwrap();

    let mut text = String::new();
    if let Some(body) = doc.select(&body_sel).next() {
        for node in body.text() {
            let trimmed = node.trim();
            if !trimmed.is_empty() {
                text.push_str(trimmed);
                text.push(' ');
            }
        }
    }
    // Truncate to 4000 chars to stay within LLM context
    text.chars().take(4000).collect()
}
```

**Step 3: Add `fetch_menu_text()` and `fetch_html()` methods to `impl CrawlerService`**

```rust
impl CrawlerService {
    /// Attempt to fetch menu text for a restaurant from its own website.
    /// Returns None if no website, fetch fails, or text is too short to be useful.
    async fn fetch_menu_text(
        &self,
        website: Option<&str>,
    ) -> Option<String> {
        let site = website?;

        // Try {website}/menu first, then root page
        let menu_url = format!("{}/menu", site.trim_end_matches('/'));
        if let Ok(html) = self.fetch_html(&menu_url).await {
            let text = extract_text(&html);
            if text.len() > 200 {
                return Some(text);
            }
        }
        if let Ok(html) = self.fetch_html(site).await {
            let text = extract_text(&html);
            if text.len() > 200 {
                return Some(text);
            }
        }

        None
    }

    /// Fetch a URL and return the HTML body. Returns Err on non-200 or timeout.
    async fn fetch_html(&self, url: &str) -> anyhow::Result<String> {
        let resp = self
            .http
            .get(url)
            .header("User-Agent", "Mozilla/5.0 (compatible; Remembite-Crawler/1.0)")
            .timeout(std::time::Duration::from_secs(10))
            .send()
            .await?;

        if !resp.status().is_success() {
            anyhow::bail!("HTTP {} for {url}", resp.status());
        }

        Ok(resp.text().await?)
    }
}
```

**Step 4: Verify**
```bash
cd backend && cargo check
```
Expected: 0 errors.

**Step 5: Commit**
```bash
git add backend/src/services/crawler.rs
git commit -m "feat(crawler): menu fetch from restaurant own website"
```

---

## Task 10: LLM menu parse + dish upsert

**Files:**
- Modify: `backend/src/services/crawler.rs`

**Step 1: Add `seed_dishes()` method**

This method: (1) checks if the restaurant already has dishes, (2) fetches menu text, (3) calls `parse_menu_ocr`, (4) upserts dishes, (5) enqueues `ClassifyDish` for each new dish.

```rust
use crate::jobs::Job;

impl CrawlerService {
    /// Seed dishes for a restaurant if it has none. Returns count of dishes created.
    async fn seed_dishes(
        &self,
        restaurant_id: uuid::Uuid,
        restaurant_name: &str,
        website: Option<&str>,
    ) -> anyhow::Result<i32> {
        // Skip if restaurant already has dishes
        let count: i64 = sqlx::query_scalar(
            "SELECT COUNT(*) FROM dishes WHERE restaurant_id = $1",
        )
        .bind(restaurant_id)
        .fetch_one(&self.db)
        .await?;

        if count > 0 {
            return Ok(0);
        }

        // Fetch menu text (best-effort)
        let menu_text = match self.fetch_menu_text(website).await {
            Some(text) => text,
            None => {
                tracing::debug!(restaurant = %restaurant_name, "no menu text found, skipping dishes");
                return Ok(0);
            }
        };

        // Parse with LLM
        let parsed = match self.llm.parse_menu_ocr(&menu_text).await {
            Ok(dishes) => dishes,
            Err(e) => {
                tracing::warn!(restaurant = %restaurant_name, error = %e, "LLM menu parse failed");
                return Ok(0);
            }
        };

        let mut created = 0i32;
        for dish in &parsed {
            if dish.name.trim().is_empty() {
                continue;
            }

            let dish_id = uuid::Uuid::new_v4();
            let inserted = sqlx::query(
                r#"
                INSERT INTO dishes (id, restaurant_id, name, category, price, created_by)
                VALUES ($1, $2, $3, $4, $5, $6)
                ON CONFLICT (restaurant_id, name) DO NOTHING
                "#,
            )
            .bind(dish_id)
            .bind(restaurant_id)
            .bind(&dish.name)
            .bind(&dish.category)
            .bind(dish.price_rupees.map(|p| p as f64))
            .bind(uuid::Uuid::nil())  // system user
            .execute(&self.db)
            .await?;

            if inserted.rows_affected() > 0 {
                created += 1;
                // Enqueue background classification (non-fatal if queue full)
                if let Err(e) = self.job_queue.enqueue(Job::ClassifyDish {
                    dish_id,
                    name: dish.name.clone(),
                    cuisine: None,
                }).await {
                    tracing::warn!(dish_id = %dish_id, error = %e, "failed to enqueue ClassifyDish");
                }
            }
        }

        Ok(created)
    }
}
```

**Note**: `seed_dishes` references `self.job_queue` — you need to add this field to `CrawlerService`.

**Step 2: Add `job_queue` to `CrawlerService` struct and `new()`**

Update the struct and constructor:
```rust
use crate::jobs::JobQueue;

pub struct CrawlerService {
    pub db: PgPool,
    pub http: reqwest::Client,
    pub llm: Arc<dyn LlmProvider>,
    pub config: Arc<Config>,
    pub job_queue: Arc<dyn JobQueue>,
}

impl CrawlerService {
    pub fn new(
        db: PgPool,
        http: reqwest::Client,
        llm: Arc<dyn LlmProvider>,
        config: Arc<Config>,
        job_queue: Arc<dyn JobQueue>,
    ) -> Self {
        Self { db, http, llm, config, job_queue }
    }
```

**Step 3: Verify**
```bash
cd backend && cargo check
```
Expected: 0 errors. If `Job::ClassifyDish` fields differ, check `backend/src/jobs/mod.rs` for the exact variant and adjust the struct fields.

**Step 4: Commit**
```bash
git add backend/src/services/crawler.rs
git commit -m "feat(crawler): LLM menu parse + dish upsert + ClassifyDish enqueue"
```

---

## Task 11: `crawl_city()` orchestration

**Files:**
- Modify: `backend/src/services/crawler.rs`

This is the main pipeline method. It ties together all the pieces from Tasks 7–10.

**Step 1: Add `crawl_city()` method**

```rust
impl CrawlerService {
    /// Run the full pipeline for one city. Updates crawl_runs on completion.
    pub async fn crawl_city(&self, city_name: &str) -> anyhow::Result<()> {
        tracing::info!(city = %city_name, "starting city crawl");

        // Load city bounds
        let city_row = sqlx::query(
            "SELECT lat_min, lat_max, lng_min, lng_max FROM crawler_cities WHERE name = $1 AND enabled = true",
        )
        .bind(city_name)
        .fetch_optional(&self.db)
        .await?
        .ok_or_else(|| anyhow::anyhow!("city '{city_name}' not found or disabled"))?;

        use sqlx::Row;
        let lat_min: f64 = city_row.try_get("lat_min")?;
        let lat_max: f64 = city_row.try_get("lat_max")?;
        let lng_min: f64 = city_row.try_get("lng_min")?;
        let lng_max: f64 = city_row.try_get("lng_max")?;

        // Create crawl_runs record
        let run_id = uuid::Uuid::new_v4();
        sqlx::query(
            "INSERT INTO crawl_runs (id, city) VALUES ($1, $2)",
        )
        .bind(run_id)
        .bind(city_name)
        .execute(&self.db)
        .await?;

        let points = grid_points(lat_min, lat_max, lng_min, lng_max, self.config.crawler_grid_step_km);
        tracing::info!(city = %city_name, points = points.len(), "grid generated");

        let mut restaurants_found = 0i32;
        let dishes_found = 0i32;  // dishes are seeded lazily on user visit, not during crawl

        'outer: for (lat, lng) in &points {
            let mut next_token: Option<String> = None;
            loop {
                let (results, token) = match self
                    .nearby_search(*lat, *lng, next_token.as_deref())
                    .await
                {
                    Ok(r) => r,
                    Err(e) => {
                        tracing::warn!(lat, lng, error = %e, "nearby_search failed, skipping point");
                        break;
                    }
                };

                // Rate limit: Google Places allows 10 QPS
                tokio::time::sleep(std::time::Duration::from_millis(120)).await;

                for result in results {
                    match self.upsert_restaurant(&result, city_name).await {
                        Ok(Some(_)) => restaurants_found += 1,
                        Ok(None) => {}  // skipped (no geometry)
                        Err(e) => {
                            tracing::warn!(place_id = %result.place_id, error = %e, "upsert_restaurant failed");
                        }
                    }
                }

                // NOTE: Place Details + menu seeding are NOT called here.
                // They are triggered lazily from GET /restaurants/:id when enriched_at IS NULL.

                match token {
                    Some(t) => {
                        // Google requires 2s delay before using next_page_token
                        tokio::time::sleep(std::time::Duration::from_secs(2)).await;
                        next_token = Some(t);
                    }
                    None => break,
                }
            }
        }

        // Mark run complete
        sqlx::query(
            r#"
            UPDATE crawl_runs
            SET status = 'completed',
                restaurants_found = $1,
                dishes_found = $2,
                completed_at = NOW()
            WHERE id = $3
            "#,
        )
        .bind(restaurants_found)
        .bind(dishes_found)
        .bind(run_id)
        .execute(&self.db)
        .await?;

        // Mark city last_crawled_at
        sqlx::query(
            "UPDATE crawler_cities SET last_crawled_at = NOW() WHERE name = $1",
        )
        .bind(city_name)
        .execute(&self.db)
        .await?;

        tracing::info!(
            city = %city_name,
            restaurants = restaurants_found,
            dishes = dishes_found,
            "city crawl complete"
        );
        Ok(())
    }

    /// Run the full crawl for all enabled cities sequentially.
    pub async fn run_all_cities(&self) {
        let cities: Vec<String> = match sqlx::query_scalar(
            "SELECT name FROM crawler_cities WHERE enabled = true ORDER BY name",
        )
        .fetch_all(&self.db)
        .await {
            Ok(c) => c,
            Err(e) => {
                tracing::error!(error = %e, "failed to load crawler cities");
                return;
            }
        };

        tracing::info!(count = cities.len(), "starting crawl for all cities");
        for city in &cities {
            if let Err(e) = self.crawl_city(city).await {
                // Update run status to failed if possible
                tracing::error!(city = %city, error = %e, "city crawl failed");
                let _ = sqlx::query(
                    "UPDATE crawl_runs SET status = 'failed', completed_at = NOW() WHERE city = $1 AND status = 'running'"
                )
                .bind(city)
                .execute(&self.db)
                .await;
            }
        }
    }
}
```

**Step 2: Verify**
```bash
cd backend && cargo check
```
Expected: 0 errors.

**Step 3: Commit**
```bash
git add backend/src/services/crawler.rs
git commit -m "feat(crawler): crawl_city orchestration + run_all_cities"
```

---

## Task 11b: Lazy enrichment + menu seeding in `GET /restaurants/:id`

**Files:**
- Modify: `backend/src/routes/restaurants.rs`

When a user opens a restaurant page, if the restaurant has never been enriched (or enrichment is stale), call Place Details and — if the restaurant has no dishes yet — attempt menu seeding using the fetched `website`.

**Step 1: Add enrichment + menu seeding block to `get_restaurant()`**

In `backend/src/routes/restaurants.rs`, in the `get_restaurant` handler, **after** building the `RestaurantDetailResponse`, add this block before the final `Ok(Json(...))`:

```rust
    // Lazy enrichment: fetch Place Details if stale or missing
    let enriched_at: Option<chrono::DateTime<chrono::Utc>> = sqlx::query_scalar(
        "SELECT enriched_at FROM restaurants WHERE id = $1"
    )
    .bind(restaurant_id)
    .fetch_one(&state.db)
    .await
    .ok()
    .flatten();

    let needs_enrichment = enriched_at
        .map(|t| chrono::Utc::now() - t > chrono::Duration::days(90))
        .unwrap_or(true);

    if needs_enrichment {
        if let Some(ref place_id) = google_place_id {
            let crawler = state.crawler.clone();
            let place_id = place_id.clone();
            let db = state.db.clone();
            let rid = restaurant_id;

            tokio::spawn(async move {
                if let Ok(Some(detail)) = crawler.place_details(&place_id).await {
                    // Update enriched fields
                    let _ = sqlx::query(
                        r#"UPDATE restaurants SET
                            phone_number   = COALESCE($1, phone_number),
                            website        = COALESCE($2, website),
                            opening_hours  = COALESCE($3, opening_hours),
                            enriched_at    = NOW()
                           WHERE id = $4"#,
                    )
                    .bind(&detail.formatted_phone_number)
                    .bind(&detail.website)
                    .bind(&detail.opening_hours)
                    .bind(rid)
                    .execute(&db)
                    .await;

                    // Menu seed if restaurant has no dishes yet
                    let dish_count: i64 = sqlx::query_scalar(
                        "SELECT COUNT(*) FROM dishes WHERE restaurant_id = $1"
                    )
                    .bind(rid)
                    .fetch_one(&db)
                    .await
                    .unwrap_or(0);

                    if dish_count == 0 {
                        let _ = crawler.seed_dishes(
                            rid,
                            &detail.name,
                            detail.website.as_deref(),
                        ).await;
                    }
                }
            });
        }
    }
```

**Step 2: Add `pub` to `seed_dishes()` in `crawler.rs`**

```rust
// Change: async fn seed_dishes(
// To:
pub async fn seed_dishes(
```

**Step 3: Verify**
```bash
cd backend && cargo check
```
Expected: 0 errors. The enrichment spawns in background — user gets the cached response immediately; enriched data appears on next page load.

**Step 4: Commit**
```bash
git add backend/src/routes/restaurants.rs backend/src/services/crawler.rs
git commit -m "feat(crawler): lazy Place Details enrichment + menu seeding on restaurant page view"
```

---

## Task 12: Admin routes

**Files:**
- Create: `backend/src/routes/admin_crawler.rs`

**Step 1: Create the route file**

```rust
// backend/src/routes/admin_crawler.rs
use axum::{
    Json, Router,
    extract::{Path, State},
    http::StatusCode,
    routing::{get, post},
};
use sqlx::Row;

use crate::{
    AppState,
    auth::middleware::AuthUser,
    dto::CrawlRunResponse,
    error::{AppError, AppResult},
};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/crawl", post(trigger_all))
        .route("/crawl/:city", post(trigger_city))
        .route("/crawl/runs", get(list_runs))
}

/// POST /admin/crawl — trigger full crawl for all cities (background, returns immediately)
async fn trigger_all(
    State(state): State<AppState>,
    user: AuthUser,
) -> AppResult<(StatusCode, Json<serde_json::Value>)> {
    user.require_admin()?;

    if !state.config.google_places_api_key.is_empty() {
        let crawler = state.crawler.clone();
        tokio::spawn(async move {
            crawler.run_all_cities().await;
        });
        Ok((StatusCode::ACCEPTED, Json(serde_json::json!({ "ok": true, "message": "crawl started for all cities" }))))
    } else {
        Err(AppError::BadRequest("GOOGLE_PLACES_API_KEY not configured".to_string()))
    }
}

/// POST /admin/crawl/:city — trigger crawl for one city
async fn trigger_city(
    State(state): State<AppState>,
    user: AuthUser,
    Path(city): Path<String>,
) -> AppResult<(StatusCode, Json<serde_json::Value>)> {
    user.require_admin()?;

    if state.config.google_places_api_key.is_empty() {
        return Err(AppError::BadRequest("GOOGLE_PLACES_API_KEY not configured".to_string()));
    }

    let crawler = state.crawler.clone();
    tokio::spawn(async move {
        if let Err(e) = crawler.crawl_city(&city).await {
            tracing::error!(city = %city, error = %e, "manual city crawl failed");
        }
    });

    Ok((StatusCode::ACCEPTED, Json(serde_json::json!({ "ok": true, "city": city }))))
}

/// GET /admin/crawl/runs — list 20 most recent crawl runs
async fn list_runs(
    State(state): State<AppState>,
    user: AuthUser,
) -> AppResult<Json<Vec<CrawlRunResponse>>> {
    user.require_admin()?;

    let rows = sqlx::query(
        r#"
        SELECT id, city, status, restaurants_found, dishes_found, started_at, completed_at
        FROM crawl_runs
        ORDER BY started_at DESC
        LIMIT 20
        "#,
    )
    .fetch_all(&state.db)
    .await?;

    let runs = rows
        .into_iter()
        .map(|r| -> Result<CrawlRunResponse, sqlx::Error> {
            Ok(CrawlRunResponse {
                id: r.try_get("id")?,
                city: r.try_get("city")?,
                status: r.try_get("status")?,
                restaurants_found: r.try_get("restaurants_found")?,
                dishes_found: r.try_get("dishes_found")?,
                started_at: r.try_get("started_at")?,
                completed_at: r.try_get("completed_at")?,
            })
        })
        .collect::<Result<Vec<_>, _>>()?;

    Ok(Json(runs))
}
```

**Step 2: Register the module in `main.rs` or `routes/mod.rs`**

In `backend/src/routes/mod.rs` (or wherever other route modules are exposed), add:
```rust
pub mod admin_crawler;
```

**Step 3: Verify**
```bash
cd backend && cargo check
```
Expected: Errors about `state.crawler` not existing yet — that's OK, we fix it in Task 13.

**Step 4: Commit (after Task 13 compiles)**

Hold this commit until Task 13 is done.

---

## Task 13: Wire up in `main.rs`

**Files:**
- Modify: `backend/src/main.rs`

Read `main.rs` in full before editing. You need to:
1. Add `crawler: Arc<CrawlerService>` to `AppState`
2. Construct `CrawlerService` in `main()`
3. Spawn weekly background task (if `crawler_enabled`)
4. Register admin crawler routes

**Step 1: Add `crawler` field to `AppState`**

Find the `AppState` struct and add:
```rust
pub crawler: Arc<crate::services::crawler::CrawlerService>,
```

**Step 2: Construct `CrawlerService` in `main()` after building other state**

After `AppState` is constructed, add:
```rust
use crate::services::crawler::CrawlerService;

let crawler = Arc::new(CrawlerService::new(
    db.clone(),
    http_client.clone(),   // use same reqwest::Client as AppState.http
    llm.clone(),
    config.clone(),
    job_queue.clone(),
));
```

Then include it in `AppState { ..., crawler: crawler.clone() }`.

**Step 3: Spawn monthly background task (DB-backed scheduler)**

After building the router, add:
```rust
if config.crawler_enabled && !config.google_places_api_key.is_empty() {
    let crawler_bg = crawler.clone();
    tokio::spawn(async move {
        loop {
            // Check when the last successful crawl completed
            let last_run: Option<chrono::DateTime<chrono::Utc>> = sqlx::query_scalar(
                "SELECT MAX(completed_at) FROM crawl_runs WHERE status = 'completed'"
            )
            .fetch_optional(&crawler_bg.db)
            .await
            .ok()
            .flatten();

            let should_run = last_run
                .map(|t| chrono::Utc::now() - t > chrono::Duration::days(30))
                .unwrap_or(true); // No previous run → run immediately on first deploy

            if should_run {
                tracing::info!("monthly crawler starting");
                crawler_bg.run_all_cities().await;
            }

            // Check again in 1 hour (crawl only fires when >30 days have elapsed)
            tokio::time::sleep(std::time::Duration::from_secs(3600)).await;
        }
    });
}
```

**Why DB-backed instead of `tokio::time::interval`**: `tokio::time::interval` fires immediately on first tick and resets on every server restart. A server restart (redeploy, crash recovery) would re-trigger the crawler and consume Google Places quota. The DB-backed approach checks actual crawl history, so restarts after a recent crawl are no-ops.
```

**Step 4: Register admin crawler routes**

In the admin router section, nest the crawler routes:
```rust
// Inside the .nest("/admin", ...) block:
.merge(routes::admin_crawler::router())
```
(Exact nesting depends on how admin routes are currently wired — read `main.rs` to find the pattern.)

**Step 5: Verify everything compiles**
```bash
cd backend && cargo check
```
Expected: 0 errors.

**Step 6: Commit everything**
```bash
git add backend/src/main.rs backend/src/routes/admin_crawler.rs backend/src/routes/mod.rs
git commit -m "feat(crawler): wire up CrawlerService in AppState, weekly background task, admin routes"
```

---

## Task 14: End-to-end smoke test (local)

**Prerequisites**: API running locally with a valid `GOOGLE_PLACES_API_KEY` in `.env.api`.

**Step 1: Start the API**
```bash
./run-api.sh
```

**Step 2: Get an admin JWT**

Sign in with a Google account that has admin privileges (check `users` table: `is_admin = true`).

**Step 3: Trigger a single-city crawl**
```bash
curl -X POST http://localhost:8080/admin/crawl/Bangalore \
  -H "Authorization: Bearer <your-admin-token>"
```
Expected: `{"ok":true,"city":"Bangalore"}` with HTTP 202.

**Step 4: Check crawl status**
```bash
curl http://localhost:8080/admin/crawl/runs \
  -H "Authorization: Bearer <your-admin-token>"
```
Expected: JSON array with one entry, `status: "running"` initially, then `"completed"` after a few minutes.

**Step 5: Verify restaurants were created**
```bash
# Connect to your PostgreSQL:
SELECT COUNT(*), city FROM restaurants WHERE city = 'Bangalore' GROUP BY city;
```
Expected: at least 50 restaurants for Bangalore.

**Step 6: Verify nearby API returns results**
```bash
# Bangalore city center lat/lng
curl "http://localhost:8080/restaurants/nearby?lat=12.9716&lng=77.5946&radius=5000"
```
Expected: JSON array with restaurant summaries.

---

## Notes

- **`uuid::Uuid::nil()` as system user**: Crawled restaurants have `created_by = '00000000-0000-0000-0000-000000000000'`. Migration `0009_crawler.sql` inserts this user row first, so the FK constraint is satisfied.
- **Google Places Legacy API**: Use `maps.googleapis.com/maps/api/place/nearbysearch/json` (Legacy), not `places.googleapis.com/v1/places:searchNearby` (New). Legacy supports `next_page_token` pagination (up to 60 results/grid point); New API has no pagination (20 max).
- **Google Places next_page_token**: After page 1, the response may include a `next_page_token` for more results. Google requires a 2-second delay before using the token.
- **Menu coverage**: Expect ~20–30% of restaurants to yield menu text from their own website. The remaining ~70–80% get menus populated by users via OCR over time.
- **`CRAWLER_ENABLED=false`** in development: Set this in `.env.api` to skip the monthly auto-crawl during local dev and avoid consuming Google Places quota.
- **Place Details cost**: Called only when a user views a restaurant page and `enriched_at IS NULL OR < 90 days`. At early-stage usage (<150 unique restaurant views/month), cost is ~$6/month. No `$200/month free credit` as of March 2025 (replaced with per-SKU free tiers; Nearby Search has 5,000 free events, Place Details has no free tier).
- **Menu seeding is reactive, not proactive**: Crawled restaurants start with 0 dishes. The first user to open a restaurant page triggers enrichment which triggers menu seeding (if `dish_count = 0` after enrichment). This is slightly less ideal than proactive seeding but keeps the crawler cost at $0.
