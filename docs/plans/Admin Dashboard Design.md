# Admin Dashboard — Design Document

**Date**: 2026-03-06
**Status**: Approved
**Phase**: Phase 10

---

## Problem

All existing admin capabilities are API-only (curl/Postman). As Remembite scales, the admin needs a visual interface to:
- Review and action reports and edit suggestions without raw HTTP calls
- Monitor user growth, pro subscriptions, and platform health
- Manage users (grant/revoke pro, suspend bad actors)
- Observe and trigger the restaurant crawler
- Soft-delete bad data (spammy restaurants, offensive dish names)

---

## Solution

A standalone React + Vite + shadcn/ui SPA in `admin/` at the root of the monorepo. Deployed to `admin.remembite.com` via Cloudflare Pages. Auth reuses the existing `POST /auth/google` endpoint — access is denied if `is_admin = false`.

---

## Tech Stack

| Layer | Choice |
|---|---|
| Framework | React 18 + Vite + TypeScript |
| UI components | shadcn/ui + Tailwind CSS |
| HTTP | Axios with Bearer interceptor + refresh token rotation |
| Routing | React Router v6 |
| State | React Query (server state) |
| Auth | `@react-oauth/google` → existing `POST /auth/google` |
| Deploy | Cloudflare Pages (free) at `admin.remembite.com` |

No SSR needed. No new framework. Pure SPA — admin tools don't need SEO.

---

## Architecture

### Frontend: `admin/` folder

```
admin/
  src/
    pages/
      Dashboard.tsx
      Users.tsx
      Subscriptions.tsx
      Reports.tsx
      EditSuggestions.tsx
      Restaurants.tsx
      Dishes.tsx
      Crawler.tsx
      Login.tsx
    components/
      Layout.tsx          — sidebar nav + main area
      DataTable.tsx       — reusable paginated table
      ActionDialog.tsx    — confirm/cancel modal
    lib/
      api.ts              — Axios instance + typed endpoints
      auth.ts             — token storage + refresh token flow
  package.json
  vite.config.ts
  tailwind.config.ts
```

### Auth Flow

1. Admin opens `admin.remembite.com`
2. Redirected to Login page — "Sign in with Google" button (`@react-oauth/google` renders the button and provides the Google ID token)
3. Google ID token → `POST /auth/google` → returns `{ access_token, refresh_token, is_admin, ... }`
4. If `is_admin = false` → display "Access denied" + sign out immediately
5. If `is_admin = true` → store `access_token` in memory (React state) + `refresh_token` in `localStorage` → redirect to Dashboard
6. Axios interceptor attaches `Authorization: Bearer <access_token>` on every request
7. On 401 response → Axios interceptor calls `POST /auth/refresh` with `refresh_token` → receives new `access_token` → retries original request. If refresh also fails → sign out + redirect to Login.

Note: `access_token` is kept in memory (not `localStorage`) to reduce XSS exposure. `refresh_token` in `localStorage` is acceptable for an internal admin tool.

### CORS

The backend must allow `admin.remembite.com` as an origin in the Axum CORS layer. This is a required change to `main.rs`:

```rust
// In the CorsLayer configuration in main.rs, add:
.allow_origin("https://admin.remembite.com".parse::<HeaderValue>().unwrap())
```

### Backend: New Admin Endpoints

All require `require_admin()` — 403 if not admin.

**New file:** `backend/src/routes/admin.rs`

```
GET  /admin/analytics/summary
GET  /admin/users?q=&page=&pro=&admin=&suspended=
GET  /admin/users/:id
PATCH /admin/users/:id
GET  /admin/subscriptions?page=
GET  /admin/restaurants?q=&city=&page=&deleted=
GET  /admin/dishes?q=&restaurant_id=&attribute_state=&page=&deleted=
GET  /admin/edit-suggestions?status=&page=
DELETE /admin/restaurants/:id
POST /admin/restaurants/:id/restore
POST /admin/restaurants/:id/enrich
DELETE /admin/dishes/:id
POST /admin/dishes/:id/restore
POST /admin/dishes/:id/reclassify
GET  /admin/jobs/stats
```

Existing admin endpoints remain unchanged (already in `edit_suggestions::admin_router`, `reports::admin_router`, `restaurants::admin_router`, `dishes::admin_router`, `images::admin_router`, and crawler endpoints from Phase 9).

### DB Migration: `0011_admin.sql`

```sql
-- User management
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS is_suspended BOOL NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS pro_source   TEXT,   -- 'google_play' | 'manual' | null
  ADD COLUMN IF NOT EXISTS pro_plan     TEXT;   -- 'monthly' | 'annual' | null

-- Soft-delete for content moderation
ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE dishes      ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- Partial indexes for soft-delete filtering (used by both admin and public queries)
CREATE INDEX IF NOT EXISTS idx_restaurants_not_deleted ON restaurants(id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_dishes_not_deleted      ON dishes(id)      WHERE deleted_at IS NULL;
```

---

## Required Changes to Existing Files

These are changes Phase 10 makes to files that already exist — not new files.

### 1. `backend/src/routes/auth.rs` — Suspended user check

`POST /auth/google` must check `is_suspended` before issuing tokens:

```rust
// After fetching/upserting the user row, before issuing JWT:
let is_suspended: bool = row.try_get("is_suspended")?;
if is_suspended {
    return Err(AppError::Forbidden("Account suspended".to_string()));
}
```

### 2. `backend/src/services/google_play.rs` (or `payments.rs`) — Populate `pro_plan`

`verify_purchase` must set `pro_plan` based on `product_id`:

```rust
// Map product_id → pro_plan before UPDATE users SET ...
let pro_plan = if req.product_id.contains("annual") { "annual" } else { "monthly" };

sqlx::query(
    "UPDATE users SET pro_status = true, pro_expires_at = $1,
     pro_source = 'google_play', pro_plan = $2 WHERE id = $3"
)
.bind(expires_at)
.bind(pro_plan)
.bind(auth.id)
.execute(&state.db).await?;
```

Existing pro subscribers will have `pro_plan = null` until they re-verify a purchase. This is acceptable — the admin Subscriptions page renders `null` as "—" rather than crashing.

### 3. Public restaurant/dish queries — Soft-delete filter

All public endpoints that list or fetch restaurants/dishes must add `WHERE deleted_at IS NULL`:

- `GET /restaurants/nearby` — add to WHERE clause
- `GET /restaurants/:id` — add to WHERE clause (return 404 if deleted)
- `GET /restaurants/:id/dishes` — add to WHERE clause
- `GET /search` — add to both restaurant and dish sub-queries
- `GET /users/me/timeline` — dish reactions reference dishes; deleted dishes should still show (reactions are historical — do not cascade-delete)

Note: Reactions and ratings on soft-deleted restaurants/dishes are retained. Only visibility is removed. Taste vectors are not recomputed on soft-delete.

### 4. `backend/src/main.rs` — Register `admin.rs` router + CORS

```rust
.nest("/admin", routes::admin::router()
    .merge(routes::edit_suggestions::admin_router())
    .merge(routes::restaurants::admin_router())
    .merge(routes::reports::admin_router())
    .merge(routes::dishes::admin_router())
    .merge(routes::images::admin_router()))
```

Add `admin.remembite.com` to the `CorsLayer` allowed origins.

---

## Known Limitation: JWT Not Invalidated on Suspend/Revoke

When admin suspends a user or revokes pro, the user's existing access token remains valid until it expires (typically 15 minutes). This is an accepted limitation — implementing a server-side JWT blocklist adds significant complexity for a small security window.

**Mitigation:** Access tokens have a short TTL. The next request after expiry will hit `POST /auth/refresh`, which checks `is_suspended` (since refresh calls re-fetch the user row) and returns 401 for suspended users, effectively cutting them off within 15 minutes.

Pro revocation has the same 15-minute lag — the user retains Pro API access until their current access token expires.

---

## Pages

### 1. Dashboard

KPIs shown as stat cards:

| Metric | Query |
|---|---|
| Total users | `COUNT(*) FROM users` |
| New users (7d / 30d) | `COUNT(*) WHERE created_at > NOW() - INTERVAL 'N days'` |
| Total restaurants | `COUNT(*) WHERE deleted_at IS NULL` |
| Total dishes | `COUNT(*) WHERE deleted_at IS NULL` |
| Total reactions | `COUNT(*) FROM dish_reactions` |
| Pro subscribers | `COUNT(*) FROM users WHERE pro_status = true AND pro_expires_at > NOW()` |
| Open reports | `COUNT(*) FROM reports WHERE status = 'open'` |
| Pending edit suggestions | `COUNT(*) FROM edit_suggestions WHERE status = 'pending'` |
| Pending LLM jobs | from `GET /admin/jobs/stats` |

Queue alerts: if open reports > 0 or pending edits > 0, show a banner linking to the relevant page.

---

### 2. Users

Paginated table (25 per page):

| Column | Notes |
|---|---|
| Avatar + Name | |
| Email | |
| Joined | relative timestamp |
| Reactions | count |
| Pro | badge (Plan type + expires date) |
| Admin | badge |
| Suspended | badge |
| Actions | ⋮ menu |

**Search:** by name or email (server-side).

**Filters:** Pro = all/yes/no · Admin = all/yes/no · Suspended = all/yes/no.

**Actions per user (via ⋮ dropdown):**
- Grant Pro — opens dialog with plan selector (Monthly / Annual) + `expires_at` date picker; sets `pro_status = true`, `pro_source = 'manual'`, `pro_plan`
- Revoke Pro — sets `pro_status = false`, `pro_expires_at = null`, `pro_source = null`, `pro_plan = null`
- Grant Admin — sets `is_admin = true`
- Revoke Admin — sets `is_admin = false`
- Suspend — sets `is_suspended = true` (next sign-in returns 403; existing JWT valid for up to 15 minutes)
- Unsuspend — sets `is_suspended = false`

**User detail modal** (click row) — populated by `GET /admin/users/:id`:

```json
{
  "id": "...",
  "email": "...",
  "display_name": "...",
  "avatar_url": "...",
  "pro_status": true,
  "pro_plan": "annual",
  "pro_source": "google_play",
  "pro_expires_at": "...",
  "is_admin": false,
  "is_suspended": false,
  "created_at": "...",
  "reaction_count": 42,
  "restaurants_added": 3,
  "reports_filed": 1,
  "recent_reactions": [
    { "dish_name": "Butter Chicken", "restaurant_name": "Punjab Grill", "reaction": "so_yummy", "created_at": "..." }
  ]
}
```

Backend aggregates `reaction_count`, `restaurants_added`, `reports_filed`, and `recent_reactions` (last 5) in a single `GET /admin/users/:id` response — no extra calls from the frontend.

---

### 3. Subscriptions

List of all users with `pro_status = true AND pro_expires_at > NOW()`, sorted by `pro_expires_at ASC` (soonest to expire first).

| Column | Notes |
|---|---|
| Name + Email | |
| Plan | Monthly / Annual / — (null) |
| Source | Google Play / Manual / — |
| Expires | absolute date |
| Status | Active / Expiring Soon (<7 days) |
| Actions | Revoke Pro |

**Stats row at top:**

| Stat | Formula |
|---|---|
| Active subscribers | COUNT WHERE `pro_expires_at > NOW()` |
| Monthly subscribers | COUNT WHERE `pro_plan = 'monthly' AND pro_expires_at > NOW()` |
| Annual subscribers | COUNT WHERE `pro_plan = 'annual' AND pro_expires_at > NOW()` |
| Est. MRR | `monthly_count × 49 + annual_count × (399/12)` ₹ |

Note: MRR is an estimate — it doesn't account for mid-cycle cancellations or Google Play billing delays. Use it as a directional signal, not accounting truth.

---

### 4. Reports

Grouped by entity_type. Shows open reports only (status = 'open').

| Column | Notes |
|---|---|
| Type | Restaurant / Dish / Image |
| Entity | name (link to admin restaurant/dish page) |
| Reason | |
| Reported by | user name |
| Date | |
| Actions | Resolve · Dismiss |

Actions update `reports.status` via existing `POST /admin/reports/:id/action`. Row removed from queue after action.

---

### 5. Edit Suggestions

Admin list — unlike the public list which only shows `pending`, admin sees all statuses.

| Column | Notes |
|---|---|
| Entity type | restaurant / dish |
| Entity name | |
| Field | name / city / cuisine_type / category |
| Proposed value | |
| Votes | net votes |
| Status | pending / approved / rejected / expired |
| Date | |
| Actions | Approve · Reject (only for pending) |

Filter by status (default: pending). Uses new `GET /admin/edit-suggestions?status=&page=` — separate from the existing public `GET /edit-suggestions` (which remains public, pending-only).

---

### 6. Restaurants

Powered by `GET /admin/restaurants?q=&city=&page=&deleted=false` — returns all restaurants (including crawler-seeded) with no GPS requirement.

Paginated table (25 per page):

| Column | Notes |
|---|---|
| Name | |
| City | |
| Cuisine | |
| Dishes | count |
| Reactions | count |
| Google Rating | ⭐ or — |
| Created by | "Crawler" or user name |
| Deleted | — (active) or date |
| Created | date |
| Actions | ⋮ menu |

**Search:** by name. **Filters:** by city, deleted = active (default) / deleted / all.

**Actions:**
- View — opens detail panel (full address, phone, website, opening hours)
- Force Re-enrich — `POST /admin/restaurants/:id/enrich` → triggers Place Details + menu seeding in background
- Soft Delete — `DELETE /admin/restaurants/:id` → confirm modal → sets `deleted_at`
- Restore — `POST /admin/restaurants/:id/restore` → clears `deleted_at` (only visible when deleted = true filter active)

---

### 7. Dishes

Powered by `GET /admin/dishes?q=&restaurant_id=&attribute_state=&page=&deleted=false` — returns all dishes across all restaurants.

Paginated table (25 per page):

| Column | Notes |
|---|---|
| Name | |
| Restaurant | |
| Category | |
| Attribute State | Classifying / Classified / Failed |
| Spice / Sweetness | blended score or — |
| Reactions | count |
| Deleted | — (active) or date |
| Created | date |
| Actions | ⋮ menu |

**Search:** by name. **Filters:** by restaurant (typeahead), attribute_state, deleted = active / deleted / all.

**Actions:**
- Reclassify — `POST /admin/dishes/:id/reclassify` → re-enqueues ClassifyDish job
- Soft Delete — `DELETE /admin/dishes/:id` → sets `deleted_at`
- Restore — `POST /admin/dishes/:id/restore` → clears `deleted_at`

---

### 8. Crawler

**Stats bar:** last successful run (city, timestamp), total restaurants in DB, crawler-seeded vs user-added counts.

**Run history table** (20 most recent, from Phase 9's `crawl_runs`):

| Column |
|---|
| City |
| Status (running / completed / failed) |
| Restaurants found |
| Dishes found |
| Started at |
| Completed at / Duration |

**Trigger panel:**
- "Run All Cities" button → `POST /admin/crawl` → shows toast "Crawl started"
- City dropdown + "Run This City" → `POST /admin/crawl/:city`

---

## Error Handling

- 401 from API → Axios interceptor tries token refresh; if refresh fails → sign out + redirect to Login
- 403 from API → toast "Admin access required"
- 403 on sign-in (suspended check fails) → "Account suspended" message
- Network error → toast with retry option
- Successful actions → toast "Done"
- Soft-delete and suspend confirm via modal before executing

---

## Non-Goals

- No Flutter admin screen (web dashboard only)
- No real-time updates / WebSocket — page refreshes on action completion
- No audit log in v1 (who did what action) — can be added post-launch
- No iOS StoreKit subscription visibility (Google Play only in v1)
- No JWT blocklist — accepted 15-minute lag on suspend/revoke (see Known Limitation)

---

## Success Criteria

1. Admin signs in with Google; non-admin users see "Access denied"
2. Suspended user's next sign-in returns 403 "Account suspended"
3. All 8 pages load with real data from production API
4. Grant Pro action sets `pro_status = true`, `pro_plan`, `pro_source = 'manual'` in DB; user's next sign-in issues a Pro JWT
5. Soft-delete hides restaurant/dish from all public API responses; restore brings it back
6. MRR estimate on Subscriptions page only counts `pro_expires_at > NOW()`
7. Crawl trigger on Crawler page fires and a new row appears in run history
8. `cargo check` clean for all new + modified backend files
9. `npm run build` clean in `admin/`

---

End of Design
