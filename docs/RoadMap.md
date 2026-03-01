# Remembite – Full Intelligent System Roadmap

---

# 1. Strategic Objective

Ship the full intelligent Remembite system (community + AI + governance) in a structured, execution-safe sequence.

This roadmap assumes:

* Rust backend on VPS
* PostgreSQL
* Flutter frontend
* LLM classification layer
* Bayesian blending
* Taste vector modeling

Goal: Production-ready intelligent platform.

---

# 2. Phase 0 – Foundation Architecture (Week 1–2)

## 2.1 Database Schema Finalization

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

---

## 2.2 Backend Core Setup (Rust)

* Actix/Axum setup
* JWT authentication
* PostgreSQL integration
* Structured logging
* Error handling layer
* Basic rate limiting

Deliverable:
Stable API skeleton.

---

# 3. Phase 1 – Core Utility Layer (Week 3–5)

This must work perfectly before intelligence layer matters.

## 3.1 Restaurant Management

* Add restaurant (manual + GPS)
* Duplicate detection
* Edit metadata (creator only)

## 3.2 Menu OCR Flow

* ML Kit integration
* Text cleanup
* Editable extraction
* Save dishes

## 3.3 Reaction System

* One-tap reactions
* Local-first save (<200ms)
* Background sync
* Aggregation queries

## 3.4 Restaurant Star Rating

* 1–5 stars
* One rating per user
* Average calculation

Deliverable:
Fully usable decision tool without AI.

---

# 3.5 Phase 1.5 – UX Behavior & Interaction Logic (Week 5)

This phase aligns UI behavior with PRD-defined decision flow.

## 3.5.1 Restaurant Super Screen Logic

* Header layout (⭐ rating + Rate + Suggest Edit)
* "Your Top Bites" query implementation

  * Sort by reaction weight (🔥=5 → 🤢=1)
  * Tie-breaker: most recent reaction
* "Community Favorites" query implementation

  * Weighted reaction score
  * Minimum vote threshold enforcement
* Collapsible Full Menu behavior (default collapsed, first 5 visible)
* Pending updates indicator logic

## 3.5.2 Passive Restaurant Rating Trigger

* Session tracking for dish reactions
* Trigger bottom sheet after ≥2 reactions in same session
* Ensure single prompt per session

## 3.5.3 Duplicate Detection UX

* UI flow when similar restaurant detected
* "View Existing" vs "Create Anyway" handling

## 3.5.4 Visit Timeline Implementation

* Query user-specific visit history
* Chronological grouping by month/year
* Private visibility enforcement

## 3.5.5 Search Prioritization Logic

* Exact match > partial match > popularity ranking
* Restaurant vs dish result grouping

## 3.5.6 Offline Sync Architecture

* Local-first write for reactions
* Background sync queue
* Conflict resolution rules (last-write-wins for reactions)

Deliverable:
Fully aligned UX behavior with deterministic backend logic.

---

---

# 4. Phase 2 – Governance Layer (Week 6–7)

## 4.1 Suggest Edit System

* Submit edit suggestion
* Store pending state
* Approval logic
* Auto-apply if approvals ≥ N

## 4.2 Admin Controls

* Override edits
* Merge duplicate restaurants
* Moderate reports

## 4.3 Reporting System

* Report image
* Report restaurant/dish

Deliverable:
Community data integrity without chaos.

---

# 4.5 Phase 2.5 – Data Integrity & Access Control (Week 7)

## 4.5.1 Database Constraints

* Unique constraint: (user_id, dish_id) for reactions
* Unique constraint: (user_id, restaurant_id) for ratings
* Idempotent update endpoints for overwriting reactions
* Transaction-safe aggregate recalculation

## 4.5.2 Access Control Layer

* Enforce public vs private visibility at API layer
* Private notes accessible only to owner
* Private images protected via signed URLs
* Taste vectors never exposed publicly

## 4.5.3 Rate Limiting & Abuse Controls

* Per-user rate limits
* Basic anomaly detection (reaction spam patterns)

Deliverable:
Data consistency + secure visibility boundaries.

---

---

# 5. Phase 3 – AI Classification Layer (Week 8–9)

## 5.1 LLM Integration

Async job pipeline:

* Dish created → enqueue job
* Send dish name + cuisine to LLM
* Parse structured JSON
* Store priors

Must be:

* Non-blocking
* Retry-safe
* Cost monitored

## 5.2 Attribute Schema

Attributes (MVP scope only):

* spice_score
* sweetness_score
* dish_type
* cuisine_classification

No extra dimensions in v1.

Deliverable:
Dish attribute priors stored reliably.

---

# 6. Phase 4 – Community Attribute Voting (Week 10)

## 6.1 Optional Attribute Prompt

* Spice intensity voting
* Sweetness intensity voting
* Numeric storage

## 6.2 Aggregation Engine

Compute:

* Community averages
* Vote counts

Deliverable:
Hybrid data signals available.

---

# 7. Phase 5 – Bayesian Hybrid Weighting (Week 11)

Implement smoothing formula:

final_score = (k * L + n * C) / (k + n)

Requirements:

* Configurable smoothing constant (k)
* Confidence scoring
* Fallback behavior if no votes

Deliverable:
Self-correcting attribute scores.

---

# 7.5 Phase 5.5 – Confidence & Exposure Rules (Week 11)

## 7.5.1 Confidence Computation

* Attribute confidence based on vote count + LLM confidence
* Store confidence_score per attribute

## 7.5.2 Prediction Gating

Compatibility prediction visible only if:

* User has ≥ 10 reactions
* Dish has ≥ minimum attribute confidence threshold

## 7.5.3 UI Fallback Behavior

* If below threshold → no prediction shown
* Never display uncertain AI guess

Deliverable:
Trustworthy and controlled AI exposure.

---

---

# 8. Phase 6 – Taste Vector Engine (Week 12–13)

## 8.1 User Taste Modeling

Maintain per-user:

* spice_preference
* sweetness_preference
* cuisine preference distribution
* dish type preference

Update logic:

* Reaction-weighted updates
* Incremental recalculation

## 8.2 Compatibility Scoring

compatibility_score = similarity(UserTasteVector, DishAttributes)

Threshold-based UI exposure.

Deliverable:
Personalized predictions (Pro only).

---

# 9. Phase 7 – Search & Ranking Optimization (Week 14)

* Fuzzy search implementation
* Dish ranking logic
* "Your Top Bites" sorting rules
* Community favorites thresholds
* Favorites filtering (by reaction, by restaurant)
* Separate optimized queries for:

  * Per-user sorted dishes
  * Global weighted dish ranking

Deliverable:
High-quality discoverability.

---

# 9.5 Phase 7.5 – Image Infrastructure & Moderation Hardening (Week 14)

## 9.5.1 Image Storage Architecture

* Use object storage (e.g., S3-compatible)
* Signed URL generation for private images
* Public image CDN delivery
* Size and format validation

## 9.5.2 Image Moderation Workflow

* Reporting queue
* Admin moderation interface
* Deletion workflow
* Storage cleanup jobs

Deliverable:
Scalable and abuse-resistant image handling.

---

---

# 10. Phase 8 – Performance & Hardening (Week 15–16)

* Load testing
* Query optimization
* Index tuning
* Rate limiting validation
* Abuse simulation
* AI failure handling tests

Deliverable:
Production-ready stable system.

---

# 11. Launch Readiness Checklist

✔ Core utility stable
✔ Governance stable
✔ AI classification async and safe
✔ Bayesian blending tested
✔ Taste vector producing reasonable predictions
✔ Confidence thresholds enforced
✔ No blocking flows
✔ Crash-free test runs

---

# 12. Post-Launch Monitoring Plan

Track:

* Reaction frequency
* Attribute vote frequency
* AI classification error rate
* Prediction acceptance rate
* Edit abuse rate

Adjust:

* Smoothing constant (k)
* Prediction thresholds
* Prompt frequency

---

# 13. Total Estimated Timeline

~16 weeks (4 months) disciplined execution.

Can be compressed with parallel workstreams.

---

# 14. Execution Philosophy

Build in layers.
Never block utility for intelligence.
Let data accumulate.
Expose intelligence only when confident.

Remembite succeeds if:
The core reaction system is addictive.
The intelligence layer feels magical but subtle.

---

End of Roadmap
