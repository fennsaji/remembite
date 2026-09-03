use std::sync::Arc;

use scraper::{Html, Selector};
use serde::Deserialize;
use sqlx::PgPool;

use crate::{
    config::Config,
    jobs::{JobQueue, queue::Job},
    llm::provider::LlmProvider,
};

// ── Google Places API response types ────────────────────────────────────────

#[derive(Deserialize)]
struct PlacesNearbyResponse {
    #[serde(default)]
    results: Vec<NearbyResult>,
    #[serde(default)]
    next_page_token: Option<String>,
}

#[derive(Deserialize)]
pub struct NearbyResult {
    pub place_id: String,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub rating: Option<f64>,
    #[serde(default)]
    pub user_ratings_total: Option<i64>,
    #[serde(default)]
    pub price_level: Option<i64>,
    #[serde(default)]
    pub business_status: Option<String>,
    pub geometry: Option<PlaceGeometry>,
}

#[derive(Deserialize)]
struct PlaceDetailsResponse {
    #[serde(default)]
    result: PlaceDetail,
}

#[derive(Deserialize, Default)]
pub struct PlaceDetail {
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub formatted_phone_number: Option<String>,
    #[serde(default)]
    pub website: Option<String>,
    #[serde(default)]
    pub price_level: Option<i64>,
    #[serde(default)]
    pub rating: Option<f64>,
    #[serde(default)]
    pub user_ratings_total: Option<i64>,
    #[serde(default)]
    pub business_status: Option<String>,
    #[serde(default)]
    pub opening_hours: Option<serde_json::Value>,
    pub geometry: Option<PlaceGeometry>,
}

#[derive(Deserialize)]
pub struct PlaceGeometry {
    pub location: GeoLatLng,
}

#[derive(Deserialize)]
pub struct GeoLatLng {
    pub lat: f64,
    pub lng: f64,
}

// ── Service ──────────────────────────────────────────────────────────────────

pub struct CrawlerService {
    pub db: PgPool,
    pub http: reqwest::Client,
    pub llm: Arc<dyn LlmProvider>,
    pub config: Arc<Config>,
    pub job_queue: Arc<dyn JobQueue>,
}

/// Generate a grid of (lat, lng) points covering a bounding box at the given step size.
/// step_km: distance between grid points in km (2.0 = good overlap with 1500m search radius)
pub fn grid_points(
    lat_min: f64,
    lat_max: f64,
    lng_min: f64,
    lng_max: f64,
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

/// Extract visible text from an HTML page body.
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

    /// Call Google Places Legacy Nearby Search. Returns results filtered to min_rating.
    /// Handles a single page; caller paginates via next_page_token.
    async fn nearby_search(
        &self,
        lat: f64,
        lng: f64,
        next_page_token: Option<&str>,
    ) -> anyhow::Result<(Vec<NearbyResult>, Option<String>)> {
        let url = if let Some(token) = next_page_token {
            format!(
                "https://maps.googleapis.com/maps/api/place/nearbysearch/json?pagetoken={token}&key={key}",
                key = self.config.google_places_api_key,
            )
        } else {
            format!(
                "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location={lat},{lng}&radius=1500&type=restaurant&key={key}",
                key = self.config.google_places_api_key,
            )
        };

        let resp: PlacesNearbyResponse = self.http.get(&url).send().await?.json().await?;

        let min_rating = self.config.crawler_min_rating;
        let results: Vec<NearbyResult> = resp
            .results
            .into_iter()
            .filter(|r| r.rating.unwrap_or(0.0) >= min_rating)
            .collect();

        Ok((results, resp.next_page_token))
    }

    /// Fetch full details for a single place_id. Called from GET /restaurants/:id
    /// lazy enrichment, NOT from the crawl pipeline.
    pub async fn place_details(&self, place_id: &str) -> anyhow::Result<Option<PlaceDetail>> {
        let fields = "name,formatted_phone_number,website,price_level,rating,user_ratings_total,business_status,opening_hours,geometry";
        let url = format!(
            "https://maps.googleapis.com/maps/api/place/details/json?place_id={place_id}&fields={fields}&key={key}",
            key = self.config.google_places_api_key,
        );

        let resp: PlaceDetailsResponse = self.http.get(&url).send().await?.json().await?;

        if resp.result.name.is_empty() {
            return Ok(None);
        }
        Ok(Some(resp.result))
    }

    /// Insert a restaurant from Nearby Search data. Returns its ID (existing or new),
    /// or None if the result has no geometry.
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

        // System user (nil UUID) — row inserted by migration 0009, so the FK holds.
        let system_user = uuid::Uuid::nil();

        sqlx::query(
            r#"
            INSERT INTO restaurants (
                id, name, city, latitude, longitude, created_by,
                google_place_id, google_rating, google_rating_count,
                price_level, business_status
            )
            VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
            ON CONFLICT (google_place_id) WHERE google_place_id IS NOT NULL DO NOTHING
            "#,
        )
        .bind(uuid::Uuid::new_v4())
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

        // Re-fetch the ID (covers the ON CONFLICT DO NOTHING path)
        let actual_id: uuid::Uuid =
            sqlx::query_scalar("SELECT id FROM restaurants WHERE google_place_id = $1")
                .bind(&result.place_id)
                .fetch_one(&self.db)
                .await?;

        Ok(Some(actual_id))
    }

    /// Attempt to fetch menu text for a restaurant from its own website.
    /// Returns None if no website, fetch fails, or text is too short to be useful.
    async fn fetch_menu_text(&self, website: Option<&str>) -> Option<String> {
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
    ///
    /// SSRF guard: the URL must be http(s) to a public host (checked both as
    /// written and after DNS resolution), and redirects are not followed —
    /// a 3xx is treated as a failure so a public host can't bounce us onto
    /// an internal address.
    async fn fetch_html(&self, url: &str) -> anyhow::Result<String> {
        let parsed = parse_safe_url(url)?;
        assert_safe_host(&parsed).await?;

        let client = reqwest::Client::builder()
            .redirect(reqwest::redirect::Policy::none())
            .timeout(std::time::Duration::from_secs(10))
            .build()?;

        let resp = client
            .get(parsed)
            .header("User-Agent", "Mozilla/5.0 (compatible; Remembite-Crawler/1.0)")
            .send()
            .await?;

        if resp.status().is_redirection() {
            tracing::debug!(url, status = %resp.status(), "crawler: refusing to follow redirect");
            anyhow::bail!("HTTP {} (redirect not followed) for {url}", resp.status());
        }
        if !resp.status().is_success() {
            anyhow::bail!("HTTP {} for {url}", resp.status());
        }

        Ok(resp.text().await?)
    }

    /// Seed dishes for a restaurant if it has none. Returns count of dishes created.
    ///
    /// dishes has no UNIQUE(restaurant_id, name) constraint, so inserts use a
    /// case-insensitive WHERE NOT EXISTS guard instead of ON CONFLICT.
    pub async fn seed_dishes(
        &self,
        restaurant_id: uuid::Uuid,
        restaurant_name: &str,
        website: Option<&str>,
    ) -> anyhow::Result<i32> {
        // Skip if restaurant already has dishes
        let count: i64 =
            sqlx::query_scalar("SELECT COUNT(*) FROM dishes WHERE restaurant_id = $1")
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

        // Cuisine context for classification jobs
        let cuisine: Option<String> =
            sqlx::query_scalar("SELECT cuisine_type FROM restaurants WHERE id = $1")
                .bind(restaurant_id)
                .fetch_one(&self.db)
                .await
                .unwrap_or(None);
        let cuisine = cuisine.unwrap_or_default();

        let mut created = 0i32;
        for dish in &parsed {
            if dish.name.trim().is_empty() {
                continue;
            }

            let dish_id = uuid::Uuid::new_v4();
            let inserted = sqlx::query(
                r#"
                INSERT INTO dishes (id, restaurant_id, name, category, price, created_by)
                SELECT $1, $2, $3, $4, $5, $6
                WHERE NOT EXISTS (
                    SELECT 1 FROM dishes
                    WHERE restaurant_id = $2 AND lower(name) = lower($3)
                )
                "#,
            )
            .bind(dish_id)
            .bind(restaurant_id)
            .bind(dish.name.trim())
            .bind(&dish.category)
            .bind(dish.price_rupees)
            .bind(uuid::Uuid::nil()) // system user
            .execute(&self.db)
            .await?;

            if inserted.rows_affected() > 0 {
                created += 1;
                // Enqueue background classification (non-fatal if queue full)
                if let Err(e) = self
                    .job_queue
                    .enqueue(Job::ClassifyDish {
                        dish_id,
                        dish_name: dish.name.trim().to_string(),
                        cuisine: cuisine.clone(),
                    })
                    .await
                {
                    tracing::warn!(dish_id = %dish_id, "failed to enqueue ClassifyDish: {e}");
                }
            }
        }

        Ok(created)
    }

    /// True if any crawl_runs row is currently `running` — used to prevent
    /// overlapping crawls (double-triggered admin call, or manual trigger
    /// racing the monthly scheduler) from doubling Google Places quota spend.
    pub async fn has_running_crawl(&self) -> anyhow::Result<bool> {
        let count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM crawl_runs WHERE status = 'running'")
            .fetch_one(&self.db)
            .await?;
        Ok(count > 0)
    }

    /// Run the full pipeline for one city. Always finalizes its crawl_runs row
    /// (completed or failed) before returning, even on error — a `trigger_city`
    /// call that fails no longer leaves the row stuck `running` forever.
    pub async fn crawl_city(&self, city_name: &str) -> anyhow::Result<()> {
        tracing::info!(city = %city_name, "starting city crawl");

        if self.has_running_crawl().await? {
            tracing::warn!(city = %city_name, "a crawl is already running, skipping");
            return Ok(());
        }

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
        sqlx::query("INSERT INTO crawl_runs (id, city) VALUES ($1, $2)")
            .bind(run_id)
            .bind(city_name)
            .execute(&self.db)
            .await?;

        let result = self
            .scan_city_grid(city_name, lat_min, lat_max, lng_min, lng_max)
            .await;

        match result {
            Ok(restaurants_found) => {
                let dishes_found = 0i32; // dishes are seeded lazily on user visit, not during crawl
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

                sqlx::query("UPDATE crawler_cities SET last_crawled_at = NOW() WHERE name = $1")
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
            Err(e) => {
                let _ = sqlx::query(
                    "UPDATE crawl_runs SET status = 'failed', completed_at = NOW() WHERE id = $1",
                )
                .bind(run_id)
                .execute(&self.db)
                .await;
                Err(e)
            }
        }
    }

    /// Scan every grid point in the city's bounding box, upserting restaurants
    /// as they're found. Returns the count of restaurants inserted/matched.
    async fn scan_city_grid(
        &self,
        city_name: &str,
        lat_min: f64,
        lat_max: f64,
        lng_min: f64,
        lng_max: f64,
    ) -> anyhow::Result<i32> {
        let points = grid_points(lat_min, lat_max, lng_min, lng_max, self.config.crawler_grid_step_km);
        tracing::info!(city = %city_name, points = points.len(), "grid generated");

        let mut restaurants_found = 0i32;

        for (lat, lng) in &points {
            let mut next_token: Option<String> = None;
            loop {
                let (results, token) =
                    match self.nearby_search(*lat, *lng, next_token.as_deref()).await {
                        Ok(r) => r,
                        Err(e) => {
                            tracing::warn!(lat, lng, "nearby_search failed, skipping point: {e}");
                            break;
                        }
                    };

                // Rate limit: Google Places allows 10 QPS
                tokio::time::sleep(std::time::Duration::from_millis(120)).await;

                for result in results {
                    match self.upsert_restaurant(&result, city_name).await {
                        Ok(Some(_)) => restaurants_found += 1,
                        Ok(None) => {} // skipped (no geometry)
                        Err(e) => {
                            tracing::warn!(place_id = %result.place_id, "upsert_restaurant failed: {e}");
                        }
                    }
                }

                // NOTE: Place Details + menu seeding are NOT called here.
                // They run lazily from GET /restaurants/:id when enriched_at is stale.

                match token {
                    Some(t) => {
                        // Google requires a 2s delay before a next_page_token becomes valid
                        tokio::time::sleep(std::time::Duration::from_secs(2)).await;
                        next_token = Some(t);
                    }
                    None => break,
                }
            }
        }

        Ok(restaurants_found)
    }

    /// Run the full crawl for all enabled cities sequentially.
    pub async fn run_all_cities(&self) {
        let cities: Vec<String> = match sqlx::query_scalar(
            "SELECT name FROM crawler_cities WHERE enabled = true ORDER BY name",
        )
        .fetch_all(&self.db)
        .await
        {
            Ok(c) => c,
            Err(e) => {
                tracing::error!("failed to load crawler cities: {e}");
                return;
            }
        };

        tracing::info!(count = cities.len(), "starting crawl for all cities");
        for city in &cities {
            // crawl_city finalizes its own crawl_runs row (completed/failed/skipped)
            if let Err(e) = self.crawl_city(city).await {
                tracing::error!(city = %city, "city crawl failed: {e}");
            }
        }
    }
}

// ── SSRF guard ──────────────────────────────────────────────────────────────

/// Hostnames that must never be crawled regardless of what they resolve to.
const BLOCKED_HOSTNAMES: &[&str] = &["localhost", "metadata.google.internal"];

/// True if `ip` is in a private, loopback, link-local, unspecified, or cloud
/// metadata range — i.e. anything that isn't a routable public address.
fn is_private_ip(ip: std::net::IpAddr) -> bool {
    use std::net::IpAddr;
    match ip {
        IpAddr::V4(v4) => {
            let [a, b, _, _] = v4.octets();
            v4.is_loopback()            // 127/8
                || v4.is_private()      // 10/8, 172.16/12, 192.168/16
                || v4.is_link_local()   // 169.254/16 (incl. 169.254.169.254 metadata)
                || v4.is_unspecified()  // 0.0.0.0
                || a == 0               // 0/8
                || v4.is_broadcast()
                || (a == 100 && (64..=127).contains(&b)) // 100.64/10 CGNAT
        }
        IpAddr::V6(v6) => {
            // IPv4-mapped (::ffff:a.b.c.d) — apply the v4 rules.
            if let Some(v4) = v6.to_ipv4_mapped() {
                return is_private_ip(IpAddr::V4(v4));
            }
            let seg0 = v6.segments()[0];
            v6.is_loopback()                 // ::1
                || v6.is_unspecified()       // ::
                || (seg0 & 0xfe00) == 0xfc00 // fc00::/7 unique local
                || (seg0 & 0xffc0) == 0xfe80 // fe80::/10 link local
        }
    }
}

/// Parse `raw` and reject anything that isn't http(s) to a non-blocked,
/// non-private host. IP-literal hosts are range-checked here; hostnames are
/// resolved and checked in [`assert_safe_host`].
fn parse_safe_url(raw: &str) -> anyhow::Result<url::Url> {
    let parsed = url::Url::parse(raw)?;
    if !is_safe_url(&parsed) {
        anyhow::bail!("unsafe URL rejected by crawler: {raw}");
    }
    Ok(parsed)
}

/// Synchronous part of the SSRF check (scheme + literal host).
fn is_safe_url(parsed: &url::Url) -> bool {
    if !matches!(parsed.scheme(), "http" | "https") {
        return false;
    }
    match parsed.host() {
        None => false,
        Some(url::Host::Ipv4(v4)) => !is_private_ip(v4.into()),
        Some(url::Host::Ipv6(v6)) => !is_private_ip(v6.into()),
        Some(url::Host::Domain(d)) => {
            let d = d.trim_end_matches('.').to_ascii_lowercase();
            !BLOCKED_HOSTNAMES.contains(&d.as_str()) && !d.ends_with(".localhost")
        }
    }
}

/// Resolve the URL's host and reject it if *any* resolved address is
/// private. (Literal IPs were already checked by [`is_safe_url`].)
async fn assert_safe_host(parsed: &url::Url) -> anyhow::Result<()> {
    let host = match parsed.host() {
        Some(url::Host::Domain(d)) => d.to_string(),
        Some(_) => return Ok(()), // IP literal — already range-checked
        None => anyhow::bail!("URL has no host"),
    };
    let port = parsed.port_or_known_default().unwrap_or(80);
    let addrs = tokio::net::lookup_host((host.as_str(), port)).await?;
    let mut any = false;
    for addr in addrs {
        any = true;
        if is_private_ip(addr.ip()) {
            anyhow::bail!("host {host} resolves to non-public address {}", addr.ip());
        }
    }
    if !any {
        anyhow::bail!("host {host} did not resolve");
    }
    Ok(())
}

#[cfg(test)]
mod ssrf_tests {
    use super::*;

    fn safe(s: &str) -> bool {
        url::Url::parse(s).map(|u| is_safe_url(&u)).unwrap_or(false)
    }

    #[test]
    fn rejects_non_http_schemes() {
        assert!(!safe("ftp://example.com/menu"));
        assert!(!safe("file:///etc/passwd"));
        assert!(!safe("gopher://example.com"));
    }

    #[test]
    fn rejects_private_ipv4_literals() {
        for u in [
            "http://127.0.0.1/",
            "http://10.1.2.3/",
            "http://172.16.0.1/",
            "http://172.31.255.255/",
            "http://192.168.1.1/",
            "http://169.254.169.254/latest/meta-data/",
            "http://0.0.0.0/",
            "http://0.1.2.3/",
            "http://100.64.0.1/",
        ] {
            assert!(!safe(u), "{u} should be rejected");
        }
    }

    #[test]
    fn rejects_private_ipv6_literals() {
        for u in [
            "http://[::1]/",
            "http://[::]/",
            "http://[fc00::1]/",
            "http://[fd12:3456::1]/",
            "http://[fe80::1]/",
            "http://[::ffff:127.0.0.1]/",
            "http://[::ffff:10.0.0.1]/",
        ] {
            assert!(!safe(u), "{u} should be rejected");
        }
    }

    #[test]
    fn rejects_blocked_hostnames() {
        assert!(!safe("http://localhost/"));
        assert!(!safe("http://LOCALHOST:8080/"));
        assert!(!safe("http://foo.localhost/"));
        assert!(!safe("http://metadata.google.internal/computeMetadata/v1/"));
    }

    #[test]
    fn accepts_public_urls() {
        assert!(safe("https://example.com/menu"));
        assert!(safe("http://8.8.8.8/"));
        assert!(safe("http://172.32.0.1/")); // just outside 172.16/12
        assert!(safe("http://[2001:4860:4860::8888]/"));
    }

    #[tokio::test]
    async fn resolved_loopback_is_rejected() {
        // "localhost" is blocked by name; use a literal-free path that
        // resolves to loopback via the system resolver instead.
        let u = url::Url::parse("http://localhost/").unwrap();
        assert!(assert_safe_host(&u).await.is_err());
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn grid_points_covers_bbox() {
        // Bangalore bounding box
        let points = grid_points(12.83, 13.14, 77.46, 77.75, 2.0);

        assert!(!points.is_empty(), "grid must not be empty");

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

    #[test]
    fn extract_text_strips_markup() {
        let html = "<html><body><h1>Menu</h1><p>Paneer Tikka ₹250</p></body></html>";
        let text = extract_text(html);
        assert!(text.contains("Menu"));
        assert!(text.contains("Paneer Tikka"));
        assert!(!text.contains("<h1>"));
    }
}
