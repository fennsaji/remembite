# Remembite – Feature Gates & Limits

Last updated: 2026-03-05

This document is the authoritative reference for every feature gate, numeric limit, rate limit, and enforcement point in Remembite. All items have been verified against the codebase.

---

## 1. Pro Feature Gates

Features locked behind a Pro subscription. Free users are blocked at both the UI layer (Flutter) and the API layer (Rust backend).

| Feature | Free Behavior | Enforcement |
|---|---|---|
| **Cloud sync** | Local-only — data never leaves the device | `sync_worker.dart:67` — `if (!auth.isPro) return;` |
| **Taste insights** | Returns `null`; UI shows Unlock Pro prompt | `profile_repository.dart:80` (frontend) + `timeline.rs:92` `user.require_pro()?` (backend) |
| **Compatibility predictions** | Locked card shown instead of signal | `dish_detail_screen.dart:421` (frontend) + `dishes.rs:660` `user.require_pro()?` (backend) |

> Both layers enforce independently — a modified client cannot bypass the backend Pro check.

---

## 2. AI Confidence Thresholds

Compatibility predictions require sufficient data before showing. Both conditions must be true simultaneously.

| Condition | Threshold | Enforcement |
|---|---|---|
| User must have reacted to dishes with overlapping attributes | ≥ 10 reactions | `dishes.rs:697` — returns `user_threshold_not_met` |
| Dish must have enough community votes | ≥ 10 community votes | `dishes.rs:725` — returns `dish_threshold_not_met` |

**Compatibility signal bands** (`dishes.rs:760–768`):

| Score | Signal |
|---|---|
| ≥ 0.75 | "You'll probably love this" |
| ≥ 0.55 | "This fits your taste" |
| ≥ 0.40 | "Could go either way" |
| < 0.40 | "Might not be your style" |

**Bayesian prior weight**: `k = 5` (`config.rs:52`, configurable via `BAYESIAN_PRIOR_WEIGHT` env var)
Formula: `(5 × llm_prior + n × community_avg) / (5 + n)`

---

## 3. OCR / Menu Scan Limits

| Limit | Value | Enforcement |
|---|---|---|
| Max dishes displayed per scan | No cap | All extracted dishes shown |
| Max raw OCR text length | 50,000 characters | `ocr.rs:25` — HTTP 400 if exceeded |
| OCR rate limit | 20 requests/hour per user | `main.rs:104` + `ocr.rs:22` — reuses `rl_edit_suggestions` limiter |

> Multi-page scanning is supported — each photo's raw text is accumulated on-device, then sent as one combined payload to `/ocr/parse`. Gemini deduplicates across pages.

---

## 4. Upload Limits

| Limit | Value | Enforcement |
|---|---|---|
| Max image file size | 5 MB | `images.rs:18` — `const MAX_BYTES: usize = 5 * 1024 * 1024`; checked at line 68 |
| Allowed MIME types | `image/jpeg`, `image/png`, `image/webp` | `images.rs:19` |

---

## 5. UI Display Caps

Hard caps on how many items are shown in key lists.

| UI Element | Cap | Enforcement |
|---|---|---|
| "Top Bites" on restaurant screen | 5 dishes | `restaurant_screen.dart:431` — `.take(5)` |
| Recently visited restaurants (home screen) | 5 restaurants | `restaurants.rs:171` — `LIMIT 5` |

---

## 6. API Pagination Limits

Default result counts per endpoint. None are currently user-configurable.

| Endpoint | Limit | File |
|---|---|---|
| `GET /restaurants` (nearby) | 20 | `restaurants.rs:286` |
| `GET /search` — restaurants | 5 | `search.rs:49` |
| `GET /search` — dishes | 10 | `search.rs:76` |
| `GET /users/me/timeline` | 200 | `timeline.rs:41` |
| `GET /images/dish/:id` (list) | 20 | `images.rs:187` |
| `GET /edit-suggestions` (list) | 100 | `edit_suggestions.rs:152` |

---

## 7. Rate Limits

Applied via `check_user_limit` / `check_ip_limit` middleware. Returns HTTP 429 on breach.

### Per-user (per hour)

| Action | Limit | Limiter | Applied at |
|---|---|---|---|
| Image uploads | 10/hr | `rl_uploads` | `images.rs:42` |
| Reactions | 100/hr | `rl_reactions` | `dishes.rs:217` |
| Restaurant creation | 10/hr | `rl_restaurant_create` | `restaurants.rs:40` |
| Edit suggestions (POST) | 20/hr | `rl_edit_suggestions` | `edit_suggestions.rs:54` |
| OCR (POST) | 20/hr | `rl_edit_suggestions` (shared) | `ocr.rs:22` |

### Per-IP (per minute)

| Action | Limit | Limiter | Applied at |
|---|---|---|---|
| Search | 60/min | `rl_global_ip` | `search.rs:27` |

> All limiters defined in `main.rs:101–105`.

---

## 8. Spam & Governance

| Rule | Threshold | Behavior | Enforcement |
|---|---|---|---|
| Reaction spam detection | > 20 reactions in 5 minutes | Non-blocking flag (async warning, does not reject) | `dishes.rs:288–304` |
| Edit suggestion auto-apply | ≥ 3 net upvotes within 7-day window | Edit applied automatically to dish | `edit_suggestions.rs:272` |
| Edit suggestion expiry | 7-day window from creation | Suggestion expires if threshold not met | `migrations/0001_initial_schema.sql` — `NOW() + INTERVAL '7 days'` |

---

## 9. Location Limits

| Limit | Value | Enforcement |
|---|---|---|
| Default nearby search radius | 5,000 m (5 km) | `restaurants.rs:260` |
| Duplicate detection radius | ~100 m | `restaurants.rs:46` (bounding box heuristic) |

---

## 10. Auth Token Expiry

| Token | Expiry | Config key |
|---|---|---|
| JWT access token | 24 hours | `JWT_ACCESS_EXPIRY_HOURS` (`config.rs:33`) |
| JWT refresh token | 30 days | `JWT_REFRESH_EXPIRY_DAYS` (`config.rs:34`) |

---

## Enforcement Verification

All 25 items audited against source code on 2026-03-05.

| Status | Count |
|---|---|
| ✅ Fully enforced | 24 |
| ⚠️ Partial (design note only) | 1 |
| ❌ Missing | 0 |

**Partial item**: OCR rate limit reuses the `rl_edit_suggestions` limiter rather than having its own dedicated limiter. Functionally correct (20/hr achieved) — no gap, just shared infrastructure.

---

End of Feature Gates & Limits
