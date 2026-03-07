# Remembite – Full Intelligent System Roadmap

---

# 1. Strategic Objective

Build the complete Remembite intelligent system end-to-end before user growth begins. Ship a fully-featured product, then scale infrastructure as users arrive.

Phases are ordered by technical dependency — each phase unblocks the next. No phase waits for user validation to proceed.

This roadmap assumes:

* Rust backend on VPS
* PostgreSQL (Neon)
* Flutter frontend
* LLM classification layer (Gemini 2.0 Flash)
* Bayesian blending
* Taste vector modeling

Goal: Production-ready intelligent platform, fully built and hardened before scaling.

---

# 2. Execution Philosophy

Build everything. Then grow.

All 7 phases are built sequentially without stopping for user growth signals. Infrastructure upscaling is a separate track triggered by actual user load — not a phase in the product build.

The learning gates from earlier drafts are removed as blockers. Post-launch monitoring will surface the same signals, but they will not delay development.

---

# 3. Phase 0 – Foundation Architecture (Week 1–2)

## 3.1 Database Schema Finalization

Core Tables:

* users
* restaurants
* dishes
* restaurant_ratings
* dish_reactions
* dish_attribute_votes
* dish_attribute_priors (LLM output)
* edit_suggestions
* edit_approvals
* user_taste_vectors
* favorites
* images

Deliverables:

* Migration scripts
* Indexing strategy
* Geo-index for restaurant proximity
* Local SQLite schema (offline-first, must be cloud-sync-ready from day one)

---

## 3.2 Backend Core Setup (Rust)

* Axum setup
* JWT authentication
* PostgreSQL integration (SQLx)
* Structured logging
* Error handling layer
* Basic rate limiting

Deliverable:
Stable API skeleton.

---

# 4. Phase 1 – Core Utility Layer (Week 3–5)

## 4.1 Restaurant Management

* Add restaurant (manual + GPS)
* Duplicate detection
* Edit metadata (creator only, admin override)

## 4.2 Menu OCR Flow

* ML Kit integration (on-device, free)
* Text cleanup
* Editable extraction
* Save dishes
* OCR is positioned as an accelerator, not the primary onboarding entry point

## 4.3 Reaction System

* One-tap reactions
* Local-first save (<200ms)
* Background sync
* Aggregation queries

## 4.4 Restaurant Star Rating

* 1–5 stars
* One rating per user
* Average calculation
* Passive trigger: bottom sheet after ≥2 reactions in same session

## 4.5 Basic Search (Functional)

* Restaurant name search
* Dish name search
* Fuzzy matching, case-insensitive
* Grouped results (restaurants + dishes)
* Exact match > partial match > popularity ranking

Note: Search ships with the utility layer. Ranking optimization is deferred to Phase 7.

## 4.6 Visit Timeline

* User-specific visit history
* Chronological grouping by month/year
* Private visibility enforced

## 4.7 Onboarding + Taste Bootstrapping

* App intro + sign in
* Optional taste bootstrapping: 10–15 common dishes, user reacts (🔥 / 🤢 / Skip)
* Bootstrapping reactions count toward the ≥10 personal reaction threshold
* "Taste Profile Completion" indicator set up from day one

Deliverable:
Fully usable decision tool without AI.

---

# 5. Phase 1.5 – UX Behavior & Interaction Logic (Week 5)

## 5.1 Restaurant Super Screen Logic

* Header layout (⭐ rating + Rate + Suggest Edit)
* "Your Top Bites" query implementation

  * Sort by reaction weight (🔥=5 → 🤢=1)
  * Tie-breaker: most recent reaction
* "Community Favorites" query implementation

  * Weighted reaction score
  * Minimum vote threshold enforcement
* Collapsible Full Menu behavior (default collapsed, first 5 visible)
* Pending updates indicator logic

## 5.2 Passive Restaurant Rating Trigger

* Session tracking for dish reactions
* Trigger bottom sheet after ≥2 reactions in same session
* Ensure single prompt per session

## 5.3 Duplicate Detection UX

* UI flow when similar restaurant detected
* "View Existing" vs "Create Anyway" handling

## 5.4 Offline Sync Architecture

* Local-first write for reactions
* Background sync queue
* Conflict resolution rules (last-write-wins for reactions)

Deliverable:
Fully aligned UX behavior with deterministic backend logic.

---

# 6. Phase 2 – Payment Infrastructure + Pro Tier (Week 6–7)

Payment ships before AI predictions. This ensures the upgrade moment exists when intelligence first appears.

## 6.1 Google Play Billing Integration (Android)

* `in_app_purchase` Flutter plugin integration
* Monthly subscription: ₹49/month
* Annual subscription: ₹399/year
* Server-side purchase token verification via Google Play Developer API
* Real-time cancellation/refund webhooks via Google Play Pub/Sub notifications
* Webhook handler updates `pro_status` in PostgreSQL

## 6.2 Pro Feature Flag System

* Server-side Pro status enforcement
* Feature flags for: AI predictions, taste insights, cloud sync, export
* Graceful degradation: data retained on cancellation, Pro features locked

## 6.3 Cloud Sync (Pro Feature)

* PostgreSQL mirror of local SQLite data
* Full local history syncs retroactively on Pro upgrade
* Conflict resolution: last-write-wins for reactions
* Cloud Sync `/sync/full` endpoint and backend logic built here; Settings toggle UI activated in Phase 4.6

## 6.4 Upgrade Flow UX

* Upgrade Screen: AI Taste Predictions first, then Taste Insights, Cloud Sync, Data Export
* ₹399/year (annual highlighted as recommended) + ₹49/month
* Upgrade trigger: Taste Profile Completion → "See your taste insights" → paywall
* Subscription management in Settings

## 6.5 Taste Profile Completion Indicator

* Profile screen shows progress toward first prediction
* "React to 4 more dishes to unlock your taste profile"
* Creates organic urgency without artificial caps

Deliverable:
Monetization infrastructure in place. Pro tier live but AI features not yet populated.

---

# 7. Phase 3 – Community Layer (Week 8)

## 7.1 Community Reactions Visible

* Aggregated reaction counts on dishes (already from Phase 1 aggregation)
* Community Favorites surface on Restaurant Super Screen

## 7.2 Suggest Edit System (Admin-Gated)

* Users can submit edit suggestions
* Suggestions displayed publicly with vote counts
* In early stage: admin manually reviews and applies — community auto-apply threshold not yet active
* Auto-apply logic (net upvotes ≥ 3 within 7 days) activated once user density per city justifies it
* Edit expires if no consensus within 7 days

## 7.3 Admin Controls

* Override edits
* Merge duplicate restaurants
* Moderate reports

## 7.4 Reporting System

* Report image
* Report restaurant/dish

Deliverable:
Community data integrity without chaos. Admin-mediated until community scale is reached.

---

# 8. Phase 3.5 – Data Integrity & Access Control (Week 8)

## 8.1 Database Constraints

* Unique constraint: (user_id, dish_id) for reactions
* Unique constraint: (user_id, restaurant_id) for ratings
* Idempotent update endpoints for overwriting reactions
* Transaction-safe aggregate recalculation

## 8.2 Access Control Layer

* Enforce public vs private visibility at API layer
* Private notes accessible only to owner
* Private images protected via signed URLs
* Taste vectors never exposed publicly

## 8.3 Rate Limiting & Abuse Controls

* Per-user rate limits
* Basic anomaly detection (reaction spam patterns)

Deliverable:
Data consistency + secure visibility boundaries.

---

# 9. Phase 4 – AI Classification Layer (Week 9–10)

## 9.1 LLM Integration (Gemini 2.0 Flash)

Async job pipeline:

* Dish created → enqueue job
* Send dish name + cuisine to LLM via `LlmProvider` trait
* Parse structured JSON
* Store priors

Must be:

* Non-blocking
* Retry-safe
* Cost monitored

## 9.2 Attribute Schema

Attributes (MVP scope only):

* spice_score
* sweetness_score
* dish_type
* cuisine_classification

No extra dimensions in v1.

## 9.3 Community Attribute Voting

* Optional spice/sweetness intensity voting on Dish Detail
* Numeric storage
* Aggregation: community averages + vote counts

## 9.4 FCM Push Notifications

* When classification job completes, send FCM push to dish creator's device
* Payload: `{ type: "classification_complete", dish_id, dish_name }`
* Flutter: handle FCM message, refresh Dish Detail screen if open
* FCM token stored on login via `PATCH /users/me/fcm-token`

Deliverable:
Dish attribute priors stored reliably. Hybrid data signals available. Users notified when dish classification completes.

---

# 9.5. Phase 4.5 – OCR Scan Flow Fix (Post Phase 4 Patch)

## 9.5.1 Problem

Home screen Scan Menu FAB navigated directly to `/scan` without a restaurant context. `OcrResultsScreen` requires a `restaurantId` to save dishes — without one it showed an error ("Scan from a restaurant"). This violated the design principle that scan is a menu capture tool for a specific restaurant, not a standalone entry point.

## 9.5.2 Fix (No New UI Patterns)

* Keep "Scan Menu" label on home FAB; change icon to `search`
* FAB navigates to `/search` — user finds or creates a restaurant there
* From the restaurant screen, user taps the Scan button (`/restaurant/:id/scan`)
* Scan is now always initiated within a restaurant's context — enforces the correct mental model

## 9.5.3 Rule Going Forward

Scan Menu is a restaurant-contextual action. It must only be accessible from within a specific restaurant's screen (`/restaurant/:id/scan`). No route should navigate to `/scan` without a `restaurantId` attached.

Deliverable:
Home FAB updated. Scan flow always has restaurant context. No user-visible regression.

---

# 9.6. Phase 4.6 – Core UI Screens (Favorites + Settings)

## 9.6.1 Favorites Screen

* List all favorited dishes (from local Drift `favorites` table)
* Filter by reaction level (🔥 / 😋 / 🙂 / 😐 / 🤢)
* Filter by restaurant
* Sort by most recent
* Sort by highest reaction weight
* Empty state: "Tap ♡ on any dish to save it here"

## 9.6.2 Settings Screen

* **Account**: display name, email, sign out
* **Subscription**: show current plan (Free / Pro); link to Play Store subscription management for Pro users
* **Cloud Sync**: toggle visible, enabled only for Pro — shows upgrade prompt for free users
* **Export Data**: visible for Pro only — triggers data export (implementation deferred to Phase 7; show "Coming soon" for now)
* **Privacy Controls**: link to privacy policy URL
* **Help & Support**: mailto link to support email

Note: Settings screen is a shell in this phase. Cloud Sync toggle and Data Export are placeholders until Phase 2 (cloud sync backend) and Phase 7 (export implementation) respectively.

Deliverable:
Favorites screen fully functional. Settings screen shell live with all rows visible; Pro-gated rows show upgrade prompt for free users.

---

# 10. Phase 5 – Bayesian Hybrid Weighting + Taste Vectors (Week 11–12)

## 10.1 Bayesian Smoothing

Implement:

```
final_score = (k * LLM_prior + n * community_avg) / (k + n)
```

* k = 5 (LLM prior counts as 5 community votes)
* Configurable constant — can be tuned post-launch
* n < 5: AI-dominated; n > 20: community-dominated
* Fallback behavior if no votes

## 10.2 Confidence Scoring

* Attribute confidence based on vote count + LLM confidence
* Store confidence_score per attribute
* Self-correcting over time as community votes accumulate

## 10.3 Taste Vector Engine

Maintain per-user:

* spice_preference
* sweetness_preference
* cuisine preference distribution
* dish type preference

Update logic:

* Incremental: `new_pref = old_pref + 0.1 * (dish_attr - old_pref)` (learning rate = 0.1)
* Background full-recompute job for consistency correction

## 10.4 Compatibility Scoring

```
compatibility_score = similarity(UserTasteVector, DishAttributes)
```

Threshold-gated UI exposure:

* User has ≥ 10 personal reactions to dishes with overlapping attributes
* Dish has ≥ 10 community votes

Below threshold → no prediction shown.

## 10.5 UI Fallback Behavior

* If below threshold → no prediction shown, no placeholder
* Never display uncertain AI guess

## 10.6 Taste Insights on Profile Screen

* After taste vectors are computed, surface human-readable insights on the Profile screen (Pro only)
* Examples: "You prefer spicy food", "You tend to dislike very sweet dishes", "You love North Indian cuisine"
* Derived from `user_taste_vectors` — top 2–3 signals only
* Shown below Taste Profile completion indicator
* Free users see blurred/locked version with "Unlock Pro" CTA

Deliverable:
Personalized predictions live (Pro only). Self-correcting attribute scores. Taste insights visible on Profile for Pro users.

---

# 10.5. Phase 5.5 – Map View & Location Picker

## 10.5.1 Map Screen

* Use `google_maps_flutter` package (Google Maps — requires API key)
* API key setup: Google Cloud Console → Maps SDK for Android + iOS + Places API (New); inject via `android/local.properties` + gradle `manifestPlaceholders` (Android) and `AppDelegate.swift` (iOS)
* Default view: pins for user's visited restaurants only (from local Drift DB)
* Toggle: "Show Nearby" — adds nearby restaurants as secondary pins (different color)
* Tap any pin → navigate to `/restaurant/:id`
* Center map on user's current GPS location on load
* No backend changes required — restaurant lat/lng already stored

## 10.5.2 Home Screen Navigation Entry Point

* `/map` route is inside `ShellRoute` — add `Icons.map_outlined` `IconButton` in Home screen `SliverAppBar` actions to provide the sole UI entry point
* Map is NOT in the floating pill bottom nav (Home | Favorites | Timeline | Profile stays as-is)

## 10.5.3 Location Picker Screen

* New full-screen route `/location-picker` (outside `ShellRoute`)
* Accessible from Add Restaurant screen — replaces static GPS auto-detect with "Pick on Map →" button
* Uses `google_maps_flutter` with fixed crosshair (map pans, crosshair stays centered)
* `onCameraMove` callback tracks camera center; Confirm button calls `context.pop(cameraCenter)`
* Search via Google Places Autocomplete REST API → Place Details API for lat/lng resolution
* GPS "Use GPS" button snaps map back to device location
* Returns `LatLng` to Add Restaurant via `context.pop()`; re-fires duplicate check on return

Deliverable:
Map View live with Google Maps. Visited + nearby pins. Home AppBar map entry point. Interactive location picker in Add Restaurant flow.

---

# 11. Phase 6 – Image Infrastructure (Week 13)

## 11.1 Image Storage Architecture

* Cloudflare R2 (S3-compatible)
* Signed URL generation for private images
* Public image CDN delivery via Cloudflare
* Size and format validation (max 5MB per upload)

## 11.2 Image Moderation Workflow

* Reporting queue
* Admin moderation interface
* Deletion workflow
* Storage cleanup jobs

Deliverable:
Scalable and abuse-resistant image handling.

Note: Image upload UI on Dish Detail screen is visible from Phase 1 but non-functional until this phase.

---

# 11.5. Phase 6.5 – Restaurant Data Enrichment & Smart Map Density

## 11.5.1 Restaurant Schema Enrichment

Google Places Nearby Search already returns rich metadata that we currently discard. Store it.

**PostgreSQL migration** — add columns to `restaurants`:

```sql
ALTER TABLE restaurants
  ADD COLUMN google_place_id    TEXT,
  ADD COLUMN google_rating      FLOAT,
  ADD COLUMN google_rating_count INT,
  ADD COLUMN price_level        SMALLINT,   -- 0 free → 4 very expensive
  ADD COLUMN business_status    TEXT,       -- OPERATIONAL | CLOSED_TEMPORARILY | CLOSED_PERMANENTLY
  ADD COLUMN phone_number       TEXT,
  ADD COLUMN website            TEXT,
  ADD COLUMN opening_hours      JSONB;      -- { "weekday_text": [...7 strings], "open_now": bool }
```

**Drift migration** — same columns added to local `restaurants` table (via `schemaVersion` bump + migration callback).

## 11.5.2 Places API Enrichment Flow

**Nearby Search** (already called on map load) — capture and pass through to `_NearbyPlace` model:
* `rating`, `user_ratings_total`, `price_level`, `opening_hours.open_now`, `business_status`, `place_id`

**Place Details API** — called once on "Add to Remembite" button press, in parallel with createRestaurant:
* Fields: `formatted_phone_number,website,opening_hours`
* Endpoint: `GET /maps/googleapis.com/maps/api/place/details/json?place_id=...&fields=...&key=...`
* Returns `opening_hours.weekday_text` (7-element string array) and `formatted_phone_number`, `website`

**Bottom sheet enrichment** — before user taps "Add to Remembite", sheet now shows:
* Google rating (⭐ x.x — 1,234 ratings)
* Open now / Closed badge
* Price level (₹ / ₹₹ / ₹₹₹ / ₹₹₹₹)
* Cuisine type badge (already shown)

**Backend update** — `POST /restaurants` request body additions:
```json
{
  "google_place_id": "ChIJ...",
  "google_rating": 4.2,
  "google_rating_count": 1847,
  "price_level": 2,
  "business_status": "OPERATIONAL",
  "phone_number": "+91 ...",
  "website": "https://...",
  "opening_hours": { "weekday_text": ["Monday: 9:00 AM – 9:00 PM", ...], "open_now": true }
}
```

All new fields are nullable — manually added restaurants (without a Places API source) have `null` for all enrichment columns. `GET /restaurants/:id` response includes all new fields when present.

## 11.5.3 Smart Map Pin Density (Flutter — no backend changes)

The map becomes congested at city-level zoom when hundreds of Google Places pins are shown simultaneously.

**State tracked without setState** (same pattern as `_cameraCenter`):
```dart
double _currentZoom = 14.0;   // updated in onCameraMove
```

**Scoring formula** (pure Dart, applied to `_nearbyPlaces` list):
```dart
double _placeScore(_NearbyPlace p) {
  final rating     = ((p.rating ?? 3.0) / 5.0) * 40;        // 0–40
  final popularity = (math.log(math.max(1, p.ratingCount ?? 0) + 1)
                      / math.log(1000)) * 30;                 // 0–30 (log scale)
  final openBonus  = (p.isOpen == true) ? 20.0 : 0.0;       // 0 or 20
  final opStatus   = (p.businessStatus == 'OPERATIONAL') ? 10.0 : 0.0;
  return rating + popularity + openBonus + opStatus;          // 0–100
}
```

**Pin cap by zoom level**:
| Camera zoom | Max Google Places pins shown |
|---|---|
| < 12 | 8 |
| 12–13 | 15 |
| 13–14 | 30 |
| 14–15 | 60 |
| ≥ 15 | all |

**Rules**:
* Sort `_nearbyPlaces` by `_placeScore()` descending, take top N per zoom level
* Visited restaurant pins (`reacted_` markers) always shown at all zoom levels — never filtered
* Nearby Remembite DB pins (`nearby_`) always shown — small set, quality-filtered by backend
* Only Google Places pins (`places_`) are density-filtered
* Filter runs inside `_buildMarkers()` — no extra API calls, no extra state

Deliverable:
Rich restaurant metadata stored and surfaced (Google rating, open hours, phone, website, price level). Map pin density adapts to zoom level based on quality signals. Bottom sheet shows enriched data before "Add to Remembite".

---

# 12. Phase 7 – Search & Ranking Optimization (Week 13–14)

Basic search ships in Phase 1. This phase optimizes performance, ranking quality, and adds Pro data export.

* Fuzzy search performance tuning
* Dish ranking query optimization
* "Your Top Bites" query performance
* Community favorites threshold refinement
* Favorites filtering optimization
* Separate optimized queries for:

  * Per-user sorted dishes
  * Global weighted dish ranking

## Data Export (Pro Feature)

* `GET /users/me/export` — returns full user data as JSON (reactions, ratings, notes, favorites)
* Flutter: download + share via OS share sheet
* Activate the "Export Data" row in Settings (was placeholder in Phase 4.6)

Deliverable:
High-quality, performant discoverability. Pro data export live.

---

# 13. Phase 8 – Performance & Hardening (Week 15–16)

* Load testing
* Query optimization
* Index tuning
* Rate limiting validation
* Abuse simulation
* AI failure handling tests

Deliverable:
Production-ready stable system. Ready for user growth.

---

# 13.5. Phase 9 – Restaurant Data Seeding & Crawler

Cold-start problem: new users open the app and see no restaurants. This phase pre-seeds the database with top-rated restaurants from 18 Indian cities using Google Places Legacy Nearby Search + Place Details, and attempts to pre-populate menus via restaurant website scraping + Gemini LLM.

## 13.5.1 Database: System User, UNIQUE Index, Grid Points + Enrichment Column

New migration `0009_crawler.sql`:
* System user row (nil UUID `00000000-0000-0000-0000-000000000000`) — FK target for crawler-created restaurants/dishes
* Partial UNIQUE index on `restaurants.google_place_id` — required for `ON CONFLICT (google_place_id)` upsert (column added in earlier migration without UNIQUE)
* `crawl_runs` table — tracks each crawl job (city, status, restaurants found, dishes found, timestamps)
* `crawler_cities` table — config-driven city list (18 cities, bounding boxes); admin can add cities without redeploy
* `crawl_grid_points` table — pre-generated ~5,500 lat/lng grid points across all 18 cities (2km step); crawler processes in order, budget-capped monthly
* `restaurants.enriched_at TIMESTAMPTZ` — tracks when Place Details were last fetched for a restaurant

## 13.5.2 Budget-Aware Monthly Crawler (Nearby Search Only)

`CrawlerService` module (`backend/src/services/crawler.rs`) runs as a DB-backed monthly background task (polls hourly, fires when >30 days since last successful run).

Each monthly run:
* SELECT next ~1,560 grid points (`last_scanned_at IS NULL OR last_scanned_at < NOW() - 4 months`)
* For each point: Google Places **Legacy** Nearby Search (type=restaurant, min rating=3.5, up to 60 results via `next_page_token` pagination)
* For each new `place_id` not in DB: INSERT restaurant with Nearby Search fields only (name, coords, rating, price_level, business_status) — NO Place Details call
* Stop at 1,560 points; resume next month
* After ~4 months: all 18 cities covered; cycle restarts — re-scan refreshes existing data (ToS compliance)

**Cost: $0/month** (Nearby Search within 5,000 free events/month)

## 13.5.3 Place Details Enrichment + Menu Seeding (Lazy, On User Visit)

`GET /restaurants/:id` triggers enrichment when:
```
enriched_at IS NULL OR enriched_at < NOW() - INTERVAL '90 days'
```
1. Fetch Place Details → update `phone_number`, `website`, `opening_hours`, `enriched_at`
2. If `dish_count = 0` AND `website IS NOT NULL`: attempt menu seeding
   * Try `{website}/menu`, then `{website}` root — extract text with HTML parser
   * Parse with `LlmProvider::parse_menu_ocr` (Gemini)
   * INSERT dishes `ON CONFLICT (restaurant_id, name) DO NOTHING` → enqueue `Job::ClassifyDish`

Enrichment and menu seeding run in a background `tokio::spawn` — user gets the cached response immediately; enriched data appears on the next page load.

**Cost:** ~$0–6/month (Place Details only for restaurants users actually visit; <150 calls/month early-stage)

**No Zomato/Swiggy fallback**: client-side rendered, Cloudflare bot protection, wrong URL structure. Dropped.

## 13.5.5 Admin Controls

```
POST /admin/crawl           — trigger crawl for all enabled cities (background)
POST /admin/crawl/:city     — trigger crawl for one city on-demand
GET  /admin/crawl/runs      — list 20 most recent crawl runs with status + counts
```

All require admin JWT.

## 13.5.6 Cities

**Metro (8):** Mumbai, Delhi NCR, Bangalore, Hyderabad, Chennai, Kolkata, Pune, Ahmedabad

**Tier-2 (10):** Jaipur, Lucknow, Surat, Indore, Bhopal, Chandigarh, Kochi, Coimbatore, Visakhapatnam, Nagpur

Deliverable:
≥500 restaurants per metro city, ≥200 per Tier-2 city after first full cycle (~4 months). Restaurants get dishes populated on first user visit. Admin can monitor via `/admin/crawl/runs`. Google Places cost: **$0/month crawler** + ~$0–6/month Place Details (usage-driven).

---

# 13.9. Phase 10 – Admin Dashboard

A standalone React + Vite + shadcn/ui web SPA in `admin/` deployed to `admin.remembite.com` via Cloudflare Pages. Auth reuses the existing `POST /auth/google` endpoint — access denied if `is_admin = false`.

## 13.9.1 DB Migration (`0011_admin.sql`)

```sql
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS is_suspended BOOL NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS pro_source   TEXT,   -- 'google_play' | 'manual'
  ADD COLUMN IF NOT EXISTS pro_plan     TEXT;   -- 'monthly' | 'annual'

ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE dishes      ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
```

All public `GET /restaurants` and `GET /restaurants/:id/dishes` queries updated to filter `WHERE deleted_at IS NULL`. Suspended users receive `401` on sign-in.

## 13.9.2 New Backend Endpoints (`backend/src/routes/admin.rs`)

All require admin JWT:

```
GET  /admin/analytics/summary                            — KPIs for dashboard
GET  /admin/users?q=&page=&pro=&admin=&suspended=        — paginated user list
GET  /admin/users/:id                                    — user detail with aggregated stats
PATCH /admin/users/:id                                   — grant/revoke pro, admin, suspend
GET  /admin/subscriptions?page=                          — active pro users (pro_expires_at > NOW())
GET  /admin/restaurants?q=&city=&page=&deleted=          — all restaurants, no GPS required
GET  /admin/dishes?q=&restaurant_id=&attribute_state=&page=&deleted=  — all dishes
GET  /admin/edit-suggestions?status=&page=               — all edit suggestions (admin view)
DELETE /admin/restaurants/:id                            — soft-delete
POST /admin/restaurants/:id/restore                      — clear deleted_at
POST /admin/restaurants/:id/enrich                       — re-trigger Place Details + menu seeding
DELETE /admin/dishes/:id                                 — soft-delete
POST /admin/dishes/:id/restore                           — clear deleted_at
POST /admin/dishes/:id/reclassify                        — re-enqueue ClassifyDish job
GET  /admin/jobs/stats                                   — pending LLM job count
```

**Required changes to existing files:**
* `auth.rs` — check `is_suspended = true` before issuing JWT; return 403 "Account suspended"
* `payments.rs` — set `pro_source = 'google_play'` and `pro_plan` (from `product_id`) on purchase verification
* Public `GET /restaurants`, `GET /restaurants/:id`, `GET /restaurants/:id/dishes`, `GET /search` — add `WHERE deleted_at IS NULL` filter
* `main.rs` — add `admin.remembite.com` to Axum CorsLayer allowed origins; register new `admin::router()`

## 13.9.3 Frontend: 8 Pages

| Page | Purpose |
|---|---|
| Dashboard | KPI stat cards (users, restaurants, reactions, pro count, pending queues) |
| Users | Paginated list; grant/revoke pro (with plan + expiry), admin, suspend |
| Subscriptions | All active pro users; plan type, source, expiry; MRR estimate |
| Reports | Open report queue — resolve/dismiss inline |
| Edit Suggestions | All edit suggestions — admin approve/reject (pending only) |
| Restaurants | Search, soft-delete, force re-enrich |
| Dishes | Search, soft-delete, reclassify |
| Crawler | Run history; trigger all-cities or single city |

## 13.9.4 Grant/Revoke Pro (User Upgrade from Admin)

Admin can upgrade any user to Pro from the Users page:
- Opens a dialog: plan (Monthly / Annual) + `expires_at` date picker
- Sets `pro_status = true`, `pro_expires_at`, `pro_source = 'manual'`, `pro_plan`
- Revoking sets all pro fields back to null/false

**Known limitation:** Existing JWTs remain valid for up to 15 minutes after suspend/revoke. Acceptable — access tokens are short-lived; the refresh flow checks `is_suspended` and cuts off suspended users on next refresh.

## 13.9.5 Tech Stack

| Layer | Choice |
|---|---|
| Framework | React 18 + Vite + TypeScript |
| UI | shadcn/ui + Tailwind CSS |
| Auth | `@react-oauth/google` → `POST /auth/google` |
| State | React Query + Axios with refresh interceptor |
| Deploy | Cloudflare Pages at `admin.remembite.com` |

Deliverable:
Full visual admin interface live at `admin.remembite.com`. All moderation queues (reports, edit suggestions) actionable without curl. User pro management, subscription MRR visibility, content soft-delete with restore, and crawler monitoring all in one place. Suspended users blocked at sign-in.

---

# 14. Launch Readiness Checklist

✔ Core utility stable and tested
✔ Google Play Billing live and verified end-to-end
✔ Pro upgrade flow creates natural conversion moments
✔ Governance stable (admin-mediated)
✔ AI classification async and safe
✔ FCM push notifications working (classification complete events)
✔ Bayesian blending tested
✔ Taste vector producing reasonable predictions
✔ Confidence thresholds enforced
✔ Favorites screen functional (filter + sort)
✔ Settings screen complete (all rows active, Pro-gating correct)
✔ Map View live (visited + nearby pins, smart density filtering by zoom)
✔ Restaurant data enriched (Google rating, open hours, price level, phone, website) from Places API
✔ Taste insights visible on Profile for Pro users
✔ No blocking flows
✔ Crash-free test runs
✔ Restaurant crawler first run triggered — ≥500 restaurants in metro cities before launch
✔ Place Details enrichment live on restaurant page view (90-day refresh)
✔ Admin crawler monitoring live (`GET /admin/crawl/runs`)
✔ Admin dashboard live at `admin.remembite.com` — moderation queues, user management, crawler controls

---

# 15. Scale-Up Track (Separate — Triggered by User Load)

This is not a phase in the product build. Infrastructure scaling happens post-launch, driven by real load metrics. No date can be set in advance.

## Trigger Signals

| Signal | Action |
|---|---|
| VPS CPU sustained >70% | Add a second backend VPS instance |
| API p95 latency >500ms | Profile and optimize; consider horizontal scale |
| Neon compute hours approaching limit | Upgrade to Neon Launch plan (~$15/mo) |
| Job queue depth growing | Migrate in-process queue to Redis + workers |
| R2 storage approaching 10GB free tier | Move to R2 paid tier ($0.015/GB) |

## Scale-Up Steps (in order)

1. **Enable Cloudflare Load Balancing (~$5/mo)** — already in request path (DNS + R2); just enable the add-on, point two origins at both VPS IPs, configure health checks
2. **Add second Host.co.in SM-V1 (~₹299/mo)** — stateless backend, identical Docker config; if reliability is a concern at scale, switch to Contabo VPS 10 Navi Mumbai (~€6.65/mo). Cloudflare LB is provider-agnostic.
3. **Upgrade Neon to Launch plan** — no migration required, same connection string
4. **Migrate job queue to Redis** — `LlmProvider` and job queue traits are already abstracted; swap implementation only
5. **Add read replicas on Neon** (Scale plan) — for analytics and reporting queries
6. **iOS billing (StoreKit 2)** — add Apple App Store subscription flow; `in_app_purchase` plugin already supports it

---

# 16. Post-Launch Monitoring Plan

Track:

* Day 7 and Day 30 retention rates
* Reactions per user per visit (target: ≥5)
* Attribute vote frequency
* AI classification error rate
* Prediction acceptance rate
* Edit abuse rate
* Pro conversion rate from Taste Profile Completion trigger
* Annual vs monthly subscription split

Adjust:

* Smoothing constant (k)
* Prediction thresholds (loosen from 10 to 5 if data density warrants)
* Community auto-apply threshold activation timing

---

# 17. Total Estimated Timeline

~18 weeks (4.5 months) disciplined sequential execution + Phase 9 crawler running in parallel from Phase 8 onward (async background service, no blocking dependency). Phase 10 Admin Dashboard can be built in parallel with Phase 9 (no dependencies — backend endpoints + React SPA are independent of crawler work).

No phase waits for user growth. Infrastructure scaling is handled post-launch as a separate track triggered by real load.

---

End of Roadmap
