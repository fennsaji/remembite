# Remembite – Development Prompts

Each prompt below is a self-contained starting point for a new Claude Code session.
Copy the prompt for the phase you are starting. Each prompt assumes all prior phases are complete.

Always read CLAUDE.md first — it contains architecture decisions that override defaults.

---

## Phase 0 – Foundation Architecture

```
We are building Remembite — a dish-level intelligence platform for dining.

Read these docs before writing any code:
- CLAUDE.md — architecture decisions, key constants, conflict resolution rules
- docs/Tech Stack.md — authoritative tech choices
- docs/RoadMap.md — full phase breakdown
- docs/PRD.md

Phase 0 deliverables:

1. DATABASE SCHEMA (PostgreSQL via SQLx migrations)
   Create sqlx migration files for all 12 tables:
   - users (id, google_id, email, display_name, avatar_url, pro_status, pro_expires_at, created_at, updated_at)
   - restaurants (id, name, location POINT, city, cuisine_type, created_by, created_at, updated_at)
   - dishes (id, restaurant_id, name, category, price, created_by, attribute_state [classifying|classified|failed], created_at, updated_at)
   - restaurant_ratings (id, user_id, restaurant_id, stars [1-5], created_at, updated_at) — unique(user_id, restaurant_id)
   - dish_reactions (id, user_id, dish_id, reaction [so_yummy|tasty|pretty_good|meh|never_again], synced_at, created_at, updated_at) — unique(user_id, dish_id)
   - dish_attribute_votes (id, user_id, dish_id, attribute [spice|sweetness], value FLOAT, created_at, updated_at) — unique(user_id, dish_id, attribute)
   - dish_attribute_priors (id, dish_id, spice_score FLOAT, sweetness_score FLOAT, dish_type TEXT, cuisine TEXT, confidence FLOAT, created_at)
   - edit_suggestions (id, entity_type [restaurant|dish], entity_id, field, proposed_value, suggested_by, status [pending|approved|rejected|expired], net_votes INT, created_at, updated_at)
   - edit_approvals (id, suggestion_id, user_id, vote [up|down], created_at)
   - user_taste_vectors (id, user_id, spice_preference FLOAT, sweetness_preference FLOAT, cuisine_distribution JSONB, dish_type_distribution JSONB, reaction_count INT, updated_at)
   - favorites (id, user_id, dish_id, created_at) — unique(user_id, dish_id)
   - images (id, entity_type [dish|restaurant], entity_id, uploaded_by, r2_key, is_public, created_at)

   Indexes: geo index on restaurants.location, index on dish_reactions(user_id), dish_reactions(dish_id),
   restaurant_ratings(restaurant_id), dish_attribute_votes(dish_id), user_taste_vectors(user_id).
   Schema must be cloud-sync-ready — local SQLite (Drift) will mirror this structure.

2. RUST BACKEND SCAFFOLD (Axum + Tokio + SQLx)
   Project structure:
   src/
     main.rs — Axum router, middleware stack, server startup
     config.rs — env vars via dotenvy (DATABASE_URL, JWT_SECRET, LLM_PROVIDER, GEMINI_API_KEY, etc.)
     error.rs — unified AppError type implementing IntoResponse
     auth/ — JWT middleware, Google OAuth token verification, token issuance
     routes/ — one file per domain (restaurants, dishes, reactions, users, auth)
     models/ — DB row structs deriving FromRow
     dto/ — request/response structs deriving Serialize/Deserialize
     services/ — business logic layer
     jobs/ — JobQueue trait + InProcessQueue implementation
     llm/ — LlmProvider trait + GeminiProvider stub (not yet wired)
     db/ — SQLx query functions

   Implement:
   - GET /health → 200 OK
   - POST /auth/google — verify Google ID token, issue JWT (24h access + 30d refresh)
   - JWT extractor middleware for protected routes
   - Per-user rate limiting middleware
   - Structured logging via tracing crate
   - All secrets loaded from .env via dotenvy — never hardcoded

   LlmProvider trait must have: classify_dish(name, cuisine) → DishAttributes and parse_menu_ocr(raw_text) → Vec<ParsedDish>
   JobQueue trait must have: enqueue(job) and a background worker loop

3. FLUTTER SCAFFOLD
   Project structure:
   lib/
     main.dart
     core/
       router/ — go_router setup, route definitions
       theme/ — dark theme (#0C0C0C bg, #FF3B30 accent, Sora font)
       network/ — Dio client with JWT interceptor, retry logic
     features/ — one folder per feature (auth, home, restaurant, dish, profile, etc.)
       each feature: data/ (Drift DAOs + API calls), domain/ (models), presentation/ (screens + providers)
     local_db/ — Drift database definition, all table definitions mirroring PostgreSQL schema

   Drift tables: all 12 tables mirrored locally. Include sync_status field on syncable tables.
   Riverpod providers: auth state, current user, connectivity status.
   Implement: splash screen → Google Sign-In → home screen navigation skeleton.
   All screens are empty shells at this stage — just routing and auth.

4. DOCKER COMPOSE (local dev)
   Services: postgres:16 (local dev only, Neon used in production), rust backend with cargo-watch.
   Include .env.example with all required variables documented.

Tech stack: Rust/Axum/SQLx/Serde/jsonwebtoken, Flutter/Riverpod/Drift/Dio, PostgreSQL 16.
Use sqlx-cli for migrations. Compile-time SQL verification must pass before committing.
```

---

## Phase 1 – Core Utility Layer

```
We are building Remembite. Phase 0 is complete: DB schema, Rust scaffold, Flutter scaffold all exist.

Read CLAUDE.md and docs/PRD.md before starting.

UI must match design/remembite.pen exactly — open the design file in Pencil before building any screen. Use the exact colors, typography, spacing, component names, and layout defined there. Do not invent UI — implement what is designed.

Phase 1 deliverables — build backend API + Flutter UI for:

1. RESTAURANT MANAGEMENT
   Backend:
   - POST /restaurants — create restaurant (name, location, cuisine_type)
   - GET /restaurants/:id — restaurant detail + aggregated stats
   - PATCH /restaurants/:id — edit metadata (creator or admin only)
   - GET /restaurants/nearby?lat=&lng=&radius= — geo query using PostGIS or ST_DWithin
   - Duplicate detection: before create, query restaurants within 500m with name similarity >0.8 (pg_trgm)
   Flutter: Add Restaurant screen, duplicate detection UX ("View Existing" / "Create Anyway")

2. MENU OCR FLOW
   Flutter:
   - Camera capture using image_picker
   - On-device text extraction via Google ML Kit Text Recognition v2
   - Editable extracted dish list UI (checkbox per dish, edit/remove)
   - POST /restaurants/:id/dishes/batch — save confirmed dishes
   Backend: accept batch dish creation, enqueue LLM classification job per dish, return dishes with attribute_state=classifying

3. DISH REACTIONS
   Backend:
   - POST /dishes/:id/reactions — upsert reaction (unique per user+dish)
   - GET /dishes/:id/reactions/summary — aggregated counts per reaction type
   - Reaction weight mapping: so_yummy=5, tasty=4, pretty_good=3, meh=2, never_again=1
   Flutter: one-tap reaction row (5 emoji), local-first save (<200ms), background sync via Drift + Dio

4. RESTAURANT STAR RATINGS
   Backend:
   - POST /restaurants/:id/ratings — upsert 1-5 star rating (unique per user+restaurant)
   - GET /restaurants/:id/ratings/summary — average + count
   Flutter: passive bottom sheet trigger after ≥2 dish reactions in same session (one prompt per session)

5. BASIC SEARCH
   Backend:
   - GET /search?q= — fuzzy search across restaurants + dishes using pg_trgm
   - Results grouped: restaurants first, then dishes (with restaurant name)
   - Priority: exact match > partial match > popularity (reaction count / rating count)
   Flutter: Search Results screen with grouped sections

6. VISIT TIMELINE
   Backend: GET /users/me/timeline — all dish reactions grouped by restaurant+date, sorted desc
   Flutter: Visit Timeline screen, private to user

7. ONBOARDING + TASTE BOOTSTRAPPING
   Flutter:
   - Onboarding screen with Google Sign-In
   - Taste bootstrapping: 10-15 common dishes across Indian cuisines, user reacts or skips
   - Bootstrapping reactions saved identically to normal reactions
   - Skip always visible, never blocked
   Backend: bootstrapping uses same POST /dishes/:id/reactions endpoint

Dish detail screen: show reaction, notes input (private), attribute voting UI (spice/sweetness with Skip).
Notes saved to local Drift DB + synced for Pro users only.
Restaurant Super Screen: Your Top Bites (sorted by reaction weight, tie-break by recency) + Community Favorites (min 5 votes, weighted score) + Full Menu (collapsed, first 5 visible).
```

---

## Phase 1.5 – UX Behavior & Interaction Logic

```
We are building Remembite. Phases 0 and 1 are complete.

Read CLAUDE.md before starting. Reference design/remembite.pen for any UI changes or additions — all interaction states (selected, loading, empty, error) must stay consistent with the design.

Phase 1.5 deliverables — wire up all interaction and sync logic:

1. RESTAURANT SUPER SCREEN QUERIES
   "Your Top Bites": SELECT dishes WHERE user reacted, ORDER BY reaction_weight DESC, reaction_updated_at DESC
   "Community Favorites": weighted_score = (5*yummy + 4*tasty + 3*pretty_good + 2*meh + 1*never_again) / total_votes
   Only show Community Favorites if total_votes >= 5. Below threshold show "New".
   Full Menu: collapsed by default, show first 5, "View All" expands. Each dish shows all 5 reaction buttons.

2. PASSIVE RESTAURANT RATING TRIGGER
   Track dish reaction count per session in app state (Riverpod).
   After ≥2 reactions in same restaurant session, show rating bottom sheet once.
   Session = app foreground time at same restaurant. Never show twice per session.

3. DUPLICATE DETECTION UX
   On Add Restaurant: if backend returns duplicate_detected=true with candidate list,
   show modal: "Similar restaurant found nearby" + [View Existing] [Create Anyway].
   View Existing navigates to existing restaurant screen.

4. OFFLINE SYNC ARCHITECTURE
   All writes go to Drift (SQLite) first → return success to UI immediately.
   Background sync worker: Riverpod AsyncNotifier polls pending syncs every 30s + on connectivity restore.
   Conflict resolution: last-write-wins using updated_at timestamp for reactions.
   Sync status indicator: subtle icon on records pending sync.
   Free users: local only (no cloud sync). Pro users: sync to PostgreSQL.
   Drift schema must have synced_at nullable column on all syncable tables.

5. HOME SCREEN LOGIC
   Recently Visited: last 5 distinct restaurants where user has reactions, sorted by most recent reaction.
   Nearby Restaurants: geo query from current GPS location, sorted by distance.
   GPS permission request on first home screen load.

All queries must be implemented both in Drift (local, for offline) and SQLx (backend, for Pro sync).
Ensure all API endpoints return consistent shape whether data comes from local or remote.
```

---

## Phase 2 – Payment Infrastructure + Pro Tier

```
We are building Remembite. Phases 0, 1, 1.5 are complete.

Read CLAUDE.md, docs/Tech Stack.md (Payments section), docs/PRD.md (Section 9) before starting. Reference design/remembite.pen screens 6 (Upgrade) and 5 (Profile) for the Pro upgrade UI — match exactly.

Phase 2 deliverables:

1. GOOGLE PLAY BILLING (Android)
   Flutter: integrate in_app_purchase plugin.
   Define two subscription products in Google Play Console:
   - remembite_pro_monthly (₹49/month)
   - remembite_pro_annual (₹399/year)
   Purchase flow: initiate purchase → receive PurchaseDetails → send purchase token to backend for verification.
   Handle all purchase states: pending, purchased, error, restored.
   On app start: restore purchases and re-verify with backend.

2. BACKEND PAYMENT VERIFICATION
   POST /payments/verify — accept Google Play purchase token + product_id
   Verify token against Google Play Developer API (server-to-server)
   On success: update users.pro_status=true, pro_expires_at based on subscription period
   Return updated user object with pro_status

3. GOOGLE PLAY REAL-TIME NOTIFICATIONS (Pub/Sub webhook)
   POST /webhooks/google-play — receive subscription lifecycle events
   Handle: SUBSCRIPTION_RENEWED, SUBSCRIPTION_CANCELED, SUBSCRIPTION_EXPIRED, SUBSCRIPTION_PURCHASED
   Update pro_status and pro_expires_at accordingly
   Verify webhook authenticity (Google Pub/Sub JWT)

4. PRO FEATURE FLAG ENFORCEMENT
   Backend middleware: extract pro_status from JWT claims or DB lookup.
   Protected endpoints: taste vector read, AI compatibility scores, cloud sync, data export.
   Return 403 with upgrade_required=true for free users hitting Pro endpoints.
   Flutter: Riverpod provider for pro_status. Gate Pro UI behind proStatusProvider.

5. CLOUD SYNC (Pro feature)
   On Pro upgrade: trigger full local history sync — POST /sync/full with all local reactions, ratings, notes.
   Backend: upsert all records, last-write-wins on updated_at conflicts.
   Ongoing: background sync worker (from Phase 1.5) only calls backend if user is Pro.
   Cross-device: on login on new device, GET /sync/full to pull all user data into local Drift DB.

6. UPGRADE FLOW UX
   Upgrade Screen: AI Taste Compatibility Predictions → Advanced Taste Insights → Cloud Sync → Data Export.
   Annual plan (₹399/year) displayed first and highlighted as recommended. Monthly (₹49) below it.
   Taste Profile Completion bar on Profile screen: "React to X more dishes to unlock your taste profile" → tapping navigates to Upgrade Screen.
   Locked AI signal on Dish Detail (Pro gate): blurred placeholder "🔥 You'll probably love this — unlock predictions" when dish would have a prediction but user is not Pro.
   Subscription management in Settings: show current plan, expiry date, cancel option (links to Play Store subscription management).

Platform fee: Google Play takes 15% of all revenue. No action needed in code — Play Store handles it.
```

---

## Phase 3 – Community Layer

```
We are building Remembite. Phases 0–2 are complete.

Read CLAUDE.md before starting.

Phase 3 deliverables:

1. COMMUNITY REACTIONS VISIBLE
   All reaction aggregations were built in Phase 1. Ensure they surface correctly:
   - Community Favorites on Restaurant Super Screen (min 5 votes, weighted score)
   - Aggregate reaction bar on each dish in Full Menu view (show counts per reaction type)
   These should already work from Phase 1 queries — verify and fix if not.

2. SUGGEST EDIT SYSTEM
   Backend:
   - POST /edit-suggestions — submit suggestion (entity_type, entity_id, field, proposed_value)
   - GET /edit-suggestions?entity_id=&entity_type= — list pending suggestions for an entity
   - POST /edit-suggestions/:id/vote — vote up or down (unique per user per suggestion)
   - Auto-apply logic: if net_votes (upvotes - downvotes) >= 3 within 7 days → apply edit, mark suggestion approved
   - Expiry job: cron/background task — expire suggestions with no consensus after 7 days (status=expired)
   - Admin endpoints: POST /admin/edit-suggestions/:id/approve and /reject (admin role check)
   Flutter:
   - "Suggest Edit" button on Restaurant Super Screen header → modal (field selector + proposed value input)
   - Pending edits indicator: subtle "X community updates pending" link on Restaurant Super Screen
   - Pending Edits screen: list suggestions with vote counts + Approve button for community voting

3. ADMIN CONTROLS
   Backend:
   - Admin role on users table (is_admin boolean)
   - POST /admin/restaurants/:id/merge — merge duplicate restaurant (combine ratings, dishes, preserve creator history, recalculate aggregates)
   - POST /admin/reports/:id/action — take action on reported content (remove/ignore)
   - Admin auth middleware: check is_admin=true on JWT user, return 403 otherwise
   Flutter: admin controls are backend-only for now — no admin UI in app. Use API directly or build minimal web admin later.

4. REPORTING SYSTEM
   Backend:
   - POST /reports — submit report (entity_type [image|dish|restaurant], entity_id, reason)
   - GET /admin/reports — list open reports (admin only)
   Flutter: "Report" option in long-press context menu on dish/image.
```

---

## Phase 3.5 – Data Integrity & Access Control

```
We are building Remembite. Phases 0–3 are complete.

Read CLAUDE.md (access control rules) before starting.

Phase 3.5 deliverables:

1. DATABASE CONSTRAINTS (verify all exist in migrations)
   - UNIQUE (user_id, dish_id) on dish_reactions
   - UNIQUE (user_id, restaurant_id) on restaurant_ratings
   - UNIQUE (user_id, dish_id, attribute) on dish_attribute_votes
   - UNIQUE (user_id, suggestion_id) on edit_approvals
   All reaction/rating endpoints must be idempotent upserts, not inserts.
   Reaction aggregate recalculation must run inside a transaction.

2. ACCESS CONTROL LAYER (enforce at every API endpoint)
   Public (no auth): GET restaurants, GET dishes, GET dish reaction summaries, GET community favorites
   Authenticated (JWT required): all write operations, GET user-specific data
   Pro only: GET /users/me/taste-vector, GET /dishes/:id/compatibility, POST /sync/*, GET /export
   Private data rules:
   - Notes: only owner can read/write (filter by user_id in all queries — never return other users' notes)
   - Images marked private: never return r2_key or URL to non-owner
   - Taste vectors: never returned in any public endpoint
   Add integration tests asserting these rules — a non-owner request must return 403 or empty.

3. RATE LIMITING (Axum middleware)
   Per-user limits (identified by JWT user_id):
   - Reactions: 100/hour
   - Restaurant creates: 10/hour
   - Edit suggestions: 20/hour
   - Search: 200/hour
   Global IP-based limit for unauthenticated endpoints: 60/minute.
   Return 429 with Retry-After header on limit exceeded.

4. ANOMALY DETECTION
   Basic reaction spam detection: if same user submits >20 reactions in <5 minutes, flag user for review (write to admin_flags table, do not block silently).
   Log all admin_flags with timestamp, user_id, reason.
```

---

## Phase 4 – AI Classification Layer

```
We are building Remembite. Phases 0–3.5 are complete.

Read CLAUDE.md (LLM pipeline, OCR pipeline, non-blocking UX) and docs/Tech Stack.md (AI/LLM section) before starting. Reference design/remembite.pen screens 8 (Menu Scan) and 9 (OCR Results) for the OCR flow UI, and screen 4 (Dish Detail) for the AI signal / classifying state.

Phase 4 deliverables:

1. GEMINI 2.0 FLASH INTEGRATION
   Implement GeminiProvider for the LlmProvider trait (stub was created in Phase 0).
   classify_dish(name: &str, cuisine: &str) → DishAttributes:
     Send structured prompt to Gemini 2.0 Flash API. Parse JSON response.
     Return: { spice_score: f32, sweetness_score: f32, dish_type: String, cuisine: String, confidence: f32 }
     All scores are 0.0–1.0. If response is malformed, retry once then store as failed state.
   parse_menu_ocr(raw_text: &str) → Vec<ParsedDish>:
     Send raw OCR text. Return: [{ name, price_rupees, category }]
     Filter out obvious non-dish lines (headers, footers, page numbers).
   Config: LLM_PROVIDER=gemini, GEMINI_API_KEY in .env. Provider loaded via factory from env var.
   Cost: ~₹0.02/dish. Free tier covers early scale. Log all LLM calls with token counts.

2. ASYNC CLASSIFICATION JOB PIPELINE
   On dish creation (POST /restaurants/:id/dishes or batch save):
   - Dish saved immediately with attribute_state=classifying
   - Classification job enqueued via JobQueue trait
   - Job worker calls classify_dish(), stores result in dish_attribute_priors, updates dish.attribute_state=classified
   - On failure after retry: attribute_state=failed (user can trigger re-classification)
   Jobs must be retry-safe (idempotent). Use exponential backoff (1s, 4s, 16s).
   Job worker runs in background Tokio task, not blocking request thread.

3. COMMUNITY ATTRIBUTE VOTING (complete the UI from Phase 1)
   Dish Detail screen already has spice/sweetness voting UI from Phase 1.
   Backend: POST /dishes/:id/attribute-votes (upsert, unique per user+dish+attribute)
   Votes stored as numeric value: spice mild=0.2, medium=0.5, hot=0.9; sweet low=0.2, medium=0.5, high=0.9
   GET /dishes/:id/attributes — return LLM prior + community average + vote count per attribute

4. OCR PIPELINE — SECOND STEP (LLM parsing)
   Phase 1 implemented ML Kit extraction (step 1). Now implement server-side LLM parsing (step 2).
   POST /ocr/parse — accept { raw_text, restaurant_id }
   Call parse_menu_ocr() via LlmProvider. Return structured dish list.
   Flutter: after ML Kit extracts text, send to /ocr/parse before showing editable list.
   User reviews parsed dishes → confirms → POST /restaurants/:id/dishes/batch.

5. FCM PUSH NOTIFICATION — classification complete
   When classification job completes, send FCM push to dish creator's device.
   Payload: { type: "classification_complete", dish_id, dish_name }
   Flutter: handle FCM message, refresh dish detail screen if it is open.
   Store FCM token on login: PATCH /users/me/fcm-token.
```

---

## Phase 5 – Bayesian Blending + Taste Vectors

```
We are building Remembite. Phases 0–4 are complete. Dish attribute priors exist in DB.

Read CLAUDE.md (Bayesian formula, taste vector update formula, confidence threshold rules) before starting. Reference design/remembite.pen screen 5 (Profile) for taste profile progress UI and screen 4 (Dish Detail) for the AI compatibility signal.

Phase 5 deliverables:

1. BAYESIAN ATTRIBUTE SCORING
   Implement in Rust (pure computation, no LLM):
   final_score = (k * llm_prior + n * community_avg) / (k + n)
   k = 5 (configurable constant in config.rs, not hardcoded)
   n = count of community attribute votes for this dish+attribute
   community_avg = mean of all votes for this dish+attribute
   Store final_score in dish_attribute_priors (add final_spice_score, final_sweetness_score columns via migration).
   Recompute final_score on every new attribute vote. Run inside transaction with the vote insert.
   confidence_score = min(n / (n + k), 1.0) — approaches 1 as community votes accumulate.

2. TASTE VECTOR ENGINE (Pro feature)
   Maintain user_taste_vectors with: spice_preference, sweetness_preference, cuisine_distribution (JSONB), dish_type_distribution (JSONB), reaction_count.
   Update incrementally on each dish reaction:
     new_pref = old_pref + 0.1 * (dish_final_score - old_pref)   [learning rate = 0.1]
     Update cuisine_distribution[cuisine] += reaction_weight / total_weight (normalize to sum=1)
     reaction_weight: so_yummy=5, tasty=4, pretty_good=3, meh=2, never_again=1
   Update runs synchronously in the reaction upsert transaction (fast — pure arithmetic).
   Background full-recompute job: POST /admin/users/:id/recompute-taste-vector for consistency correction.
   Taste vector only updated for Pro users (check pro_status before update).

3. COMPATIBILITY SCORING
   GET /dishes/:id/compatibility (Pro only)
   Confidence threshold — both conditions must be true before returning a score:
   - User has >= 10 dish reactions to dishes with overlapping attributes (same cuisine OR same dish_type)
   - Dish has >= 10 community attribute votes (final_score is stable)
   If either condition fails: return { prediction: null, reason: "insufficient_data" } — never return an uncertain guess.
   Compatibility formula: weighted cosine similarity between user taste vector and dish final attribute scores.
   Score range 0.0–1.0. Display threshold for "You'll probably love this": score >= 0.7.

4. TASTE INSIGHTS (Pro feature)
   GET /users/me/taste-insights — derive human-readable insights from taste vector:
   - Spice preference > 0.6 → "Prefers spicy food"
   - Sweetness preference < 0.3 → "Tends to dislike very sweet dishes"
   - Top 2 cuisines from cuisine_distribution → "Frequently chooses North Indian and Italian"
   Return list of insight strings. Flutter: display on Profile screen under "Taste Insights (Pro)".

5. TASTE PROFILE COMPLETION INDICATOR
   GET /users/me/taste-profile-status
   Return: { reaction_count, reactions_needed_for_prediction, completion_percentage, ready_for_predictions }
   completion_percentage = min(reaction_count / 10, 1.0) * 100
   Flutter: progress bar on Profile screen. Text: "React to X more dishes to unlock predictions".
   When ready_for_predictions=true and user is Pro: show first prediction automatically on next dish detail open.
```

---

## Phase 6 – Image Infrastructure

```
We are building Remembite. Phases 0–5 are complete.

Read docs/Tech Stack.md (Storage section) before starting. Reference design/remembite.pen screen 4 (Dish Detail) for image upload placement and screen 3 (Restaurant) for restaurant image treatment.

Phase 6 deliverables:

1. CLOUDFLARE R2 SETUP
   Configure R2 bucket: remembite-images (or remembite-images-dev for local).
   Two access patterns:
   - Public images: served via public CDN URL (R2 public bucket URL or custom domain)
   - Private images: served via pre-signed URLs (time-limited, 1 hour expiry)
   Add to config.rs: R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET, R2_PUBLIC_URL.
   Use aws-sdk-s3 crate (S3-compatible) for R2 operations.

2. IMAGE UPLOAD API
   POST /images/upload — multipart form upload
   Validations: max 5MB, MIME type must be image/jpeg or image/png
   Generate unique key: {entity_type}/{entity_id}/{uuid}.jpg
   Upload to R2. Insert into images table (entity_type, entity_id, uploaded_by, r2_key, is_public).
   Return: { image_id, url } — url is CDN URL if public, pre-signed URL if private.
   GET /images/:id/url — return fresh pre-signed URL for private images (re-generate on each call).

3. FLUTTER IMAGE HANDLING
   Dish Detail screen: image upload button (image_picker — camera + gallery).
   Public/private toggle before upload.
   Display uploaded images using cached_network_image.
   Private images: fetch pre-signed URL from backend on display, cache URL for session only.
   Image size enforcement: compress client-side to <5MB before uploading using flutter_image_compress.

4. IMAGE MODERATION
   Backend: POST /reports creates report with entity_type=image.
   GET /admin/reports?type=image — admin endpoint to list image reports.
   POST /admin/images/:id/remove — delete from R2 (r2_client.delete_object), set images.deleted_at.
   Deleted images return 404 on URL fetch. CDN cache invalidation via Cloudflare API (optional).
   Flutter: long-press on image shows "Report Image" option.

Note: Image upload UI on Dish Detail was visible since Phase 1 but non-functional. This phase makes it functional. No code changes needed in Flutter UI — just wire up the upload API call.
```

---

## Phase 7 – Search & Ranking Optimization

```
We are building Remembite. Phases 0–6 are complete. Basic search shipped in Phase 1.

Phase 7 deliverables — optimize search performance and ranking quality:

1. SEARCH PERFORMANCE
   Enable pg_trgm extension (add migration if not already present).
   Add GIN indexes: CREATE INDEX ON restaurants USING gin(name gin_trgm_ops) and dishes.
   Benchmark search queries with EXPLAIN ANALYZE before and after indexing.
   Target: p95 search latency <100ms at 100K rows.

2. RANKING QUALITY
   Restaurants: rank by (name_similarity * 0.5) + (avg_rating / 5 * 0.3) + (reaction_count_log * 0.2)
   Dishes: rank by (name_similarity * 0.5) + (weighted_community_score * 0.3) + (total_reactions_log * 0.2)
   Implement as a single PostgreSQL query with computed ranking score — do not rank in application code.

3. YOUR TOP BITES OPTIMISATION
   Add composite index on dish_reactions(user_id, reaction, updated_at DESC).
   Ensure query uses index — verify with EXPLAIN.
   Target: <20ms for a user with 500 reactions.

4. COMMUNITY FAVORITES OPTIMISATION
   Materialise community favorite scores: add community_score FLOAT and vote_count INT to dishes table.
   Background job: recompute community_score on each new reaction (already runs in reaction upsert — verify).
   Add index on dishes(restaurant_id, community_score DESC).
   Target: Restaurant Super Screen loads in <50ms.

5. FAVORITES SCREEN FILTERING
   GET /users/me/favorites?reaction=so_yummy&restaurant_id=&sort=recent|highest
   Ensure all filter combinations use indexes efficiently. Add composite index if needed.

6. SEARCH RESULT DEDUPLICATION
   Dish search: if same dish name exists at multiple restaurants, group under one result with "Available at 3 restaurants".
   Backend: GROUP BY normalised dish name, return restaurant_ids array.
   Flutter: show grouped dish result with restaurant count, tap expands to list of restaurants.
```

---

## Phase 8 – Performance & Hardening

```
We are building Remembite. Phases 0–7 are complete. Ready for production hardening.

Phase 8 deliverables:

1. LOAD TESTING
   Use k6 or wrk to simulate load on critical endpoints.
   Scenarios:
   - 100 concurrent users reacting to dishes (POST /dishes/:id/reactions)
   - 50 concurrent users searching (GET /search?q=)
   - 20 concurrent users loading Restaurant Super Screen
   Target: p95 <200ms, p99 <500ms, 0 errors under 100 concurrent users.
   Fix any bottlenecks found before marking phase complete.

2. QUERY OPTIMISATION
   Run EXPLAIN ANALYZE on all queries that show >50ms in load test.
   Add missing indexes. Rewrite N+1 queries. Use CTEs where appropriate.
   Ensure all SQLx queries pass compile-time verification (no runtime SQL errors possible).

3. RATE LIMITING VALIDATION
   Write integration tests asserting all rate limits trigger correctly.
   Test: 101 reactions in 1 hour → 429 on 101st. 61 unauthenticated searches in 1 minute → 429.
   Ensure rate limit state resets correctly after window expires.

4. ABUSE SIMULATION
   Test duplicate reaction spam (same user, 50 reactions/min) → admin_flag created, requests not silently dropped.
   Test edit suggestion spam → rate limit triggers.
   Test invalid JWT tokens → 401, no stack trace leaked in response.
   Test SQL injection attempts via search endpoint → SQLx parameterised queries prevent all injection.

5. AI FAILURE HANDLING
   Test LLM classification failure scenarios:
   - Gemini API returns 503 → retry with backoff, set attribute_state=failed after retries exhausted
   - Malformed JSON response → log error, mark failed, do not crash worker
   - FCM send failure → log, do not fail the classification job
   Ensure a failed classification never blocks dish creation or reaction submission.

6. FLUTTER CRASH-FREE AUDIT
   Run Flutter integration tests covering full user journey:
   Onboarding → Add Restaurant → Scan Menu → React to Dishes → View Profile → Upgrade to Pro → View Predictions
   Zero crashes on Android API 26+ (target Android 8+).
   Test offline mode: all core flows work without network. Sync resumes when connectivity restores.

7. SECURITY CHECKLIST
   - No secrets in source code or logs
   - All private data endpoints return 403 for non-owners (write tests)
   - Signed URLs expire correctly (test with expired URL → 403)
   - JWT expiry enforced (test with expired token → 401)
   - Rate limits enforced on all write endpoints
   - No stack traces or internal errors returned to client (only error codes + messages)

Deliverable: production-ready system. All tests passing. Load test results documented.
```

---

## Scale-Up Track (Post-Launch, Triggered by Load)

```
We are scaling Remembite. The full product is live and user load is growing.

Trigger this work when:
- VPS CPU sustained >70%, OR
- API p95 latency >500ms, OR
- Neon compute hours approaching free tier limit, OR
- Job queue depth growing consistently

Read docs/RoadMap.md (Scale-Up Track section) for the ordered steps.

Scale-up tasks (implement in this order based on which trigger fired):

1. HETZNER LOAD BALANCER
   Add LB11 load balancer (~€5.99/mo) in Hetzner Cloud.
   Configure: HTTP/HTTPS, round-robin, health check on GET /health.
   Update Nginx config on existing VPS — remove direct 80/443 exposure, accept from LB only.
   Test: LB routes to single VPS correctly before adding second instance.

2. SECOND BACKEND VPS
   Provision second Hetzner CX21. Deploy identical Docker setup.
   Rust backend is stateless — no shared in-process state between instances.
   Register second VPS with LB. Verify LB distributes load across both.
   JWT_SECRET must be identical on both instances (shared via env var or secret manager).

3. NEON UPGRADE
   Upgrade Neon plan from Free to Launch (~$15/mo).
   No migration, no connection string change. Verify after upgrade:
   - Compute hours limit increased
   - Storage limit increased
   - Auto-pause disabled (for production traffic)

4. REDIS JOB QUEUE
   Implement RedisJobQueue for the JobQueue trait (Phase 0 defined the trait).
   Use redis-rs crate. Job serialisation: JSON via serde_json.
   Swap LLM_JOB_QUEUE=redis in .env. Test job enqueue/dequeue before deploying.
   Deploy Redis as a separate Hetzner VPS or managed Redis.
   Old InProcessQueue implementation stays in code — swappable back via config.

5. IOS APP + APPLE BILLING
   Flutter codebase already supports iOS (same Dart code).
   Add StoreKit 2 configuration via in_app_purchase plugin (already installed).
   Create matching subscription products in App Store Connect:
   - remembite_pro_monthly (₹49/month)
   - remembite_pro_annual (₹399/year)
   Backend: POST /payments/verify — add Apple receipt validation branch (App Store Server API).
   Handle APPLE_WEBHOOK_SECRET for App Store Server Notifications.
   Test on iOS simulator and real device before App Store submission.
```

---

End of Dev Prompts
