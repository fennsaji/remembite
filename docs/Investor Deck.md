# Remembite

## Building the Dish Intelligence Infrastructure for Dining

---

## 1. The Core Insight

Every restaurant visit creates structured behavioral data:

* Dish choice
* Reaction intensity
* Cuisine preference
* Flavor tolerance
* Repeat behavior

Yet today, this data disappears.

Existing platforms optimize for:

* Restaurant discovery
* Public reviews
* Social content

No platform captures structured dish-level intelligence combined with personal behavioral modeling.

This is the gap Remembite fills.

---

## 2. The Problem

When revisiting restaurants, users:

* Forget what they ordered
* Forget what they liked
* Repeat mediocre choices
* Spend time re-deciding

At scale:

* Billions of dish-level decisions annually
* Zero structured memory layer

The market lacks a dish-centric intelligence system.

---

## 3. The Solution: A Layered Intelligence System

Remembite is not a food diary.
It is a multi-layer dish intelligence platform built on three pillars:

Layer 1 — Utility Layer

* Menu OCR
* One-tap dish reactions
* Restaurant star ratings
* Private notes & photos

Layer 2 — Community Data Layer

* Public dish reaction aggregation
* Community edit governance
* Structured dish database

Layer 3 — AI Intelligence Layer

* LLM-based dish classification
* Probabilistic flavor modeling
* Bayesian smoothing (AI prior + community correction)
* Personal taste vector modeling
* Compatibility prediction engine

---

## 4. Product Experience (In-Restaurant Decision Flow)

Open App →
See Recently Visited Restaurant →
View "Your Top Bites" →
See Community Favorites →
Optional AI Compatibility Signal →
Order with confidence.

Optimized for <15 second decision support.

---

## 5. Target User

Primary archetype: **frequent restaurant-goers in Tier 1 Indian cities**

* Visits restaurants 2–3× per week
* Dines out across diverse cuisine types (not just one regular)
* Already makes considered ordering decisions — thinks about what to order
* Has experienced the frustration of forgetting a great dish or repeating a bad one
* Aged 22–35, smartphone-native, comfortable with subscription apps

Launch city focus: Bengaluru or Delhi NCR — high dining frequency, tech-forward user base, strong food culture.

This user generates enough behavioral data (dish reactions across visits) for the taste vector to become meaningful within 3–4 weeks. Casual restaurant-goers who visit once a month are not the primary target.

---

## 6. Intelligence Architecture

### 6.1 AI Classification (Cold Start Layer)

When a dish is created:

* Dish name + cuisine sent to LLM
* Structured JSON returned:

  * spice_score (0–1)
  * sweetness_score (0–1)
  * dish_type
  * cuisine classification

LLM output is treated as probabilistic prior, not truth.

---

### 6.2 Community Override Model

Users optionally vote on:

* Spice intensity
* Sweetness intensity

Votes are stored numerically.

Final attribute score computed via Bayesian smoothing:

final_score = (k * LLM_prior + n * community_avg) / (k + n)

Result:

* Early stage → AI weighted
* Mature stage → Community dominates

Self-correcting flavor intelligence.

---

### 6.3 Personal Taste Vector Engine (Pro Layer)

Each user maintains a dynamic taste vector:

* spice_preference
* sweetness_preference
* cuisine distribution
* dish_type preference

Updated based on:

* Reaction intensity
* Dish attribute scores

Compatibility score computed via similarity function.

Prediction displayed only when confidence threshold met:
* User has ≥ 10 personal reactions
* Dish has ≥ 10 community votes

---

## 7. Cold Start Strategy

Two cold start problems require explicit mitigation:

**Problem 1: New restaurant with no community data**

Mitigation:
* Pre-seed 20–30 popular restaurants in launch city before Day 1
* LLM classification runs immediately on dish creation — new dishes are never attribute-empty, only community-light
* "Classifying..." state is visible and expected — it communicates activity, not emptiness

**Problem 2: New user with no personal reaction history**

Mitigation:
* Onboarding taste bootstrapping: user reacts to 10–15 common dishes in 30 seconds
* Bootstrapped reactions immediately count toward the ≥10 threshold
* Taste Profile Completion indicator on Profile screen shows progress toward first prediction
* First meaningful prediction arrives faster — reducing time-to-magic

---

## 8. Governance Model

Community-driven, controlled system:

* Anyone can add restaurants and dishes
* Creator can edit metadata
* Community suggests edits
* Edits auto-apply after approval threshold (admin-gated at early stage, community-activated at scale)
* Admin override + moderation

Structured growth without data chaos.

---

## 9. Data Architecture

Public Layer:

* Restaurants
* Dishes
* Aggregated reaction counts
* Restaurant star ratings
* Final attribute scores

Private Layer:

* Notes
* Visit history
* Taste vectors
* AI compatibility scores

Strict access control enforced at API layer.

---

## 10. Market Opportunity

Global:

* Billions of restaurant visits annually
* No structured dish intelligence platform

India:

* 700M+ smartphone users
* Rapid dining and food culture growth
* Tier 1 cities: established subscription app behavior, willingness to pay for premium utility

Remembite creates a new category:
Dish-level behavioral intelligence.

---

## 11. Competitive Positioning

| Platform    | Focus              | Limitation             |
| ----------- | ------------------ | ---------------------- |
| Zomato      | Restaurant reviews | Not dish-structured    |
| Google Maps | Location + ratings | No behavioral modeling |
| Instagram   | Visual content     | No structured memory   |

Remembite owns:

* Structured dish graph
* Reaction-weighted aggregation
* Self-correcting flavor model
* Personal taste vector intelligence

The proprietary asset is not the app — it is the structured behavioral data that accumulates inside it.

---

## 12. Business Model

Freemium Model — gated by intelligence access, not data quantity

Free:

* Unlimited dish tracking
* Full public intelligence access (community reactions, favorites)
* Menu OCR
* Visit timeline + private notes

Pro (₹49/month or ₹399/year):

* AI taste compatibility predictions
* Advanced taste insights
* Cloud sync (cross-device)
* Data export

Pricing rationale:
* ₹49/month is intentionally accessible — the goal is habit and retention at scale, not high per-user revenue
* Annual plan (₹399/year, ~32% discount vs monthly) drives cash flow and reduces churn
* Free tier is generous on tracking — users build rich history, then discover the intelligence behind it requires Pro
* No dish count cap: paywalling memory creates resentment; paywalling insights creates desire

---

## 13. Technical Stack

Frontend:

* Flutter

Backend:

* Rust (Actix/Axum)
* PostgreSQL
* VPS deployment
* Async job queue (interface-abstracted for future Redis swap)

AI Layer:

* LLM-based structured classification
* Probabilistic attribute modeling

Payments:

* Razorpay (India-first: UPI, cards, netbanking)

System designed for:

* Low latency
* Offline-first UX
* Async intelligence
* Horizontal scaling in Phase 3

---

## 14. Roadmap

Phase 1 – Utility Core + Validated Habit Loop

* OCR, reactions, ratings, basic search, visit timeline
* Ship to 20–30 test users
* Validate: do users return? Do they react to 5+ dishes per visit?

Phase 2 – Monetization Infrastructure

* Payment integration (Razorpay)
* Pro tier live before AI features ship
* Upgrade flow built around Taste Profile Completion trigger

Phase 3 – Governance & Data Integrity

* Community layer (reactions aggregated, admin-mediated edits)
* Access control, rate limiting

Phase 4 – AI Layer (after real data exists)

* LLM classification
* Bayesian blending
* Taste vector engine
* Confidence-gated predictions (Pro only)

Total: ~16 weeks. Learning gates between phases prevent building intelligence without a user base.

---

## 15. Vision

Remembite evolves into:
The structured dish knowledge graph for dining.

Long-term potential:

* Cross-city taste modeling
* Restaurant analytics and insights for operators
* Behavioral dining intelligence layer
* API layer for third-party dining applications

---

## 16. Why Now

* On-device OCR is reliable and free (ML Kit)
* LLM classification cost is low and falling
* Dining behavior is habitual and recurring
* No category leader in dish intelligence
* Indian subscription app market is maturing — ₹149/month is a viable price point

Technology + behavior alignment enables this category now.

---

## 17. Investment Thesis

Remembite is not a review app.
It is a self-correcting, community-powered, AI-augmented dish intelligence infrastructure.

By owning the dish-level decision moment, Remembite builds:

* High retention (habit formed at every restaurant visit)
* Structured proprietary data (dish reaction graph is defensible)
* Compounding intelligence advantage (more reactions → better predictions → more upgrades → more reactions)

Every reaction improves the system.

Every revisit reinforces the habit.

---

## Closing

Billions of dining decisions happen every year.
Remembite ensures they become structured intelligence.
