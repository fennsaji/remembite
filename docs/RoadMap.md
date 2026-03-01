# Remembite – Full Intelligent System Roadmap

---

# 1. Strategic Objective

Ship the full intelligent Remembite system in a sequence driven by **learning milestones**, not technical layers.

Phases are ordered to validate the core habit loop first, monetize second, and layer intelligence only after real behavioral data exists.

This roadmap assumes:

* Rust backend on VPS
* PostgreSQL
* Flutter frontend
* LLM classification layer
* Bayesian blending
* Taste vector modeling

Goal: Production-ready intelligent platform, validated at each stage before moving forward.

---

# 2. Execution Philosophy

Build in layers.
Phase by what you need to learn, not by what is technically interesting.
Never block the habit loop for the intelligence layer.
Let real data accumulate.
Monetize before predictions ship — so the upgrade moment exists when the magic first appears.

Remembite succeeds if:

* The core reaction system is addictive without AI.
* The intelligence layer feels magical when it arrives.
* The upgrade moment is natural, not forced.

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

* Actix/Axum setup
* JWT authentication
* PostgreSQL integration
* Structured logging
* Error handling layer
* Basic rate limiting

Deliverable:
Stable API skeleton.

---

# 4. Phase 1 – Core Utility Layer (Week 3–5)

This must work perfectly before intelligence layer matters.
**Learning milestone: Do users return? Do they react to 5+ dishes per visit?**

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
Fully usable decision tool without AI. Ship to 20–30 test users.

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

**LEARNING GATE — End of Phase 1.5**

Before proceeding, validate:

* Are test users returning within 7 days after first visit?
* Are users reacting to 5+ dishes per restaurant visit?
* Is the OCR extraction error rate acceptable in real conditions?

If retention is not observed, investigate and iterate on the habit loop before adding more layers.

---

# 6. Phase 2 – Payment Infrastructure + Pro Tier (Week 6–7)

Payment ships before AI predictions. This ensures the upgrade moment exists when intelligence first appears.

## 6.1 Payment Provider Integration

* Razorpay integration (UPI, cards, netbanking — India-first)
* Monthly subscription: ₹149/month
* Annual subscription: ₹999/year
* Webhook handling for payment lifecycle events

## 6.2 Pro Feature Flag System

* Server-side Pro status enforcement
* Feature flags for: AI predictions, taste insights, cloud sync, export
* Graceful degradation: data retained on cancellation, Pro features locked

## 6.3 Cloud Sync (Pro Feature)

* PostgreSQL mirror of local SQLite data
* Full local history syncs retroactively on Pro upgrade
* Conflict resolution: last-write-wins for reactions

## 6.4 Upgrade Flow UX

* Upgrade Screen: AI Taste Predictions first, then Taste Insights, Cloud Sync, Unlimited Tracking
* ₹149/month + ₹999/year (annual highlighted as recommended)
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

Simplified governance appropriate for early user density. Full community voting deferred until density warrants it.

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

**LEARNING GATE — End of Phase 3.5**

Before building AI layer, validate:

* Is there sufficient real user reaction data to test whether predictions will be meaningful?
* Are community reaction counts on dishes reaching the ≥5 threshold that enables Community Favorites?
* Is there a Pro subscriber base, even small, to validate the upgrade funnel?

If the data is too sparse, extend Phase 3 with additional seeding and user acquisition before proceeding.

---

# 9. Phase 4 – AI Classification Layer (Week 9–10)

## 9.1 LLM Integration

Async job pipeline:

* Dish created → enqueue job
* Send dish name + cuisine to LLM
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

* Use object storage (S3-compatible)
* Signed URL generation for private images
* Public image CDN delivery
* Size and format validation

## 11.2 Image Moderation Workflow

* Reporting queue
* Admin moderation interface
* Deletion workflow
* Storage cleanup jobs

Deliverable:
Scalable and abuse-resistant image handling.

Note: Image upload UI on Dish Detail screen is visible from Phase 1 but non-functional until this phase. Communicate clearly in internal builds.

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
Production-ready stable system.

---

# 14. Launch Readiness Checklist

✔ Core utility stable and validated with real users
✔ Payment infrastructure live and tested
✔ Pro upgrade flow creates natural conversion moments
✔ Governance stable (admin-mediated until community scale)
✔ AI classification async and safe
✔ Bayesian blending tested
✔ Taste vector producing reasonable predictions
✔ Confidence thresholds enforced
✔ No blocking flows
✔ Crash-free test runs

---

# 15. Post-Launch Monitoring Plan

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

# 16. Total Estimated Timeline

~16 weeks (4 months) disciplined execution.

Learning gates at end of Phase 1.5 and Phase 3.5 may extend timeline if retention signals are not observed — this is by design.

---

# 17. MVP Scope Boundary

The following features are **explicitly out of MVP** and must not be built until learning gates are passed:

| Deferred Feature | Reason |
|---|---|
| Community edit voting (auto-apply) | Requires user density. Admin-only until then. |
| Image upload and CDN | Deferred to Phase 6 |
| Bayesian blending | Requires community data to exist |
| AI taste predictions | Requires real user data + community vote threshold |
| Pro subscription charging | Ships in Phase 2 — before AI, not after |
| Search ranking optimization | Basic search ships in Phase 1; optimization in Phase 7 |

---

End of Roadmap
