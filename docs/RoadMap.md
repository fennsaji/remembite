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

Deliverable:
Dish attribute priors stored reliably. Hybrid data signals available.

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

Deliverable:
Personalized predictions live (Pro only). Self-correcting attribute scores.

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

# 12. Phase 7 – Search & Ranking Optimization (Week 13–14)

Basic search ships in Phase 1. This phase optimizes performance and ranking quality.

* Fuzzy search performance tuning
* Dish ranking query optimization
* "Your Top Bites" query performance
* Community favorites threshold refinement
* Favorites filtering optimization
* Separate optimized queries for:

  * Per-user sorted dishes
  * Global weighted dish ranking

Deliverable:
High-quality, performant discoverability.

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

# 14. Launch Readiness Checklist

✔ Core utility stable and tested
✔ Google Play Billing live and verified end-to-end
✔ Pro upgrade flow creates natural conversion moments
✔ Governance stable (admin-mediated)
✔ AI classification async and safe
✔ Bayesian blending tested
✔ Taste vector producing reasonable predictions
✔ Confidence thresholds enforced
✔ No blocking flows
✔ Crash-free test runs

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

1. **Add Hetzner Load Balancer (LB11, ~€5.99/mo)** — routes traffic across backend instances
2. **Add second Hetzner CX21 VPS** — stateless backend, identical config, Docker deployment
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

~16 weeks (4 months) disciplined sequential execution.

No phase waits for user growth. Infrastructure scaling is handled post-launch as a separate track triggered by real load.

---

End of Roadmap
