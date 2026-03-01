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
See Nearby Restaurant →
View "Your Top Bites" →
See Community Favorites →
Optional AI Compatibility Signal →
Order with confidence.

Optimized for <15 second decision support.

---

## 5. Intelligence Architecture

### 5.1 AI Classification (Cold Start Layer)

When a dish is created:

* Dish name + cuisine sent to LLM
* Structured JSON returned:

  * spice_score (0–1)
  * sweetness_score (0–1)
  * dish_type
  * cuisine classification

LLM output is treated as probabilistic prior, not truth.

---

### 5.2 Community Override Model

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

### 5.3 Personal Taste Vector Engine (Pro Layer)

Each user maintains a dynamic taste vector:

* spice_preference
* sweetness_preference
* cuisine distribution
* dish_type preference

Updated based on:

* Reaction intensity
* Dish attribute scores

Compatibility score computed via similarity function.

Prediction displayed only when confidence threshold met.

---

## 6. Governance Model

Community-driven, controlled system:

* Anyone can add restaurants and dishes
* Creator can edit metadata
* Community suggests edits
* Edits auto-apply after approval threshold
* Admin override + moderation

Structured growth without data chaos.

---

## 7. Data Architecture

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

## 8. Market Opportunity

Global:

* Billions of restaurant visits annually
* No structured dish intelligence platform

India:

* 700M+ smartphone users
* Rapid dining and food culture growth

Remembite creates a new category:
Dish-level behavioral intelligence.

---

## 9. Competitive Positioning

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

---

## 10. Business Model

Freemium Model

Free:

* Limited dish tracking
* Full public intelligence access

Pro (₹49/month target):

* Unlimited tracking
* AI compatibility predictions
* Cloud sync
* Advanced taste insights

Low price, high retention, strong habit loop.

---

## 11. Technical Stack

Frontend:

* Flutter

Backend:

* Rust (Actix/Axum)
* PostgreSQL
* VPS deployment
* Async job queue

AI Layer:

* LLM-based structured classification
* Probabilistic attribute modeling

System designed for:

* Low latency
* Offline-first UX
* Async intelligence

---

## 12. Roadmap

Phase 1 – Utility Core

* OCR
* Reactions
* Ratings

Phase 2 – Governance & Data Integrity

* Edit suggestions
* Moderation
* Access control

Phase 3 – AI Layer

* LLM classification
* Bayesian blending
* Taste vector engine
* Confidence-gated predictions

Full intelligent system built in layered execution.

---

## 13. Vision

Remembite evolves into:
The structured dish knowledge graph for dining.

Long-term potential:

* Cross-city taste modeling
* Restaurant analytics insights
* Behavioral dining intelligence layer

---

## 14. Why Now

* On-device OCR is reliable and free
* LLM classification cost is low
* Dining behavior is habitual and recurring
* No category leader in dish intelligence

Technology + behavior alignment enables this category now.

---

## 15. Investment Thesis

Remembite is not a review app.
It is a self-correcting, community-powered, AI-augmented dish intelligence infrastructure.

By owning the dish-level decision moment, Remembite builds:

* High retention
* Structured proprietary data
* Compounding intelligence advantage

Every reaction improves the system.

Every revisit reinforces the habit.

---

## Closing

Billions of dining decisions happen every year.
Remembite ensures they become structured intelligence.
