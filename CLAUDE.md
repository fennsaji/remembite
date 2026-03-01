# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Remembite is a dish-level intelligence platform for dining. It captures structured behavioral data from restaurant visits (dish reactions, flavor preferences, repeat behavior) and builds personalized taste models. Not a review app — a self-correcting, community-powered, AI-augmented dish intelligence system.

## Technical Stack

- **Frontend**: Flutter (offline-first UX)
- **Backend**: Rust (Actix or Axum web framework)
- **Database**: PostgreSQL
- **AI**: LLM-based structured classification (dish attributes as probabilistic priors)
- **Deployment**: VPS with async job queue for AI processing

## Architecture

Three-layer system:

1. **Utility Layer** — Menu OCR, one-tap dish reactions, star ratings, private notes/photos
2. **Community Data Layer** — Aggregated dish reactions, edit governance, structured dish database
3. **AI Intelligence Layer** — LLM classification, Bayesian smoothing (`final_score = (k * LLM_prior + n * community_avg) / (k + n)`), personal taste vectors, compatibility prediction

### Data Architecture

- **Public layer**: Restaurants, dishes, aggregated reactions, star ratings, final attribute scores
- **Private layer**: Notes, visit history, taste vectors, AI compatibility scores
- Strict access control enforced at API layer

### Key AI Concepts

- LLM returns structured JSON for new dishes: spice_score, sweetness_score, dish_type, cuisine classification
- LLM output treated as probabilistic prior, not truth — community votes override via Bayesian smoothing
- Personal taste vectors: spice_preference, sweetness_preference, cuisine distribution, dish_type preference
- Compatibility predictions only shown when confidence threshold is met

## Architecture Decisions

Concrete decisions resolving open system design questions:

### Bayesian Prior Weight (`k`)
- `k = 5` — LLM prior counts as 5 community votes
- n < 5: AI-dominated; n > 20: community-dominated
- `k` is a fixed tunable constant, not dynamic

### Confidence Threshold for Compatibility Predictions
Two conditions must both be met before a prediction is shown:
1. User has ≥ 10 personal reactions to dishes sharing overlapping attributes (spice/sweetness/cuisine/dish_type)
2. The dish has ≥ 10 community votes (ensures attribute scores are stable)

### Offline-First + Cloud Sync
- All data (free and Pro) stored locally in SQLite on-device from Day 1
- Cloud sync (PostgreSQL mirror) is Pro-only, but the local schema must support sync from the start
- On Pro upgrade: full local history syncs retroactively
- Do not design the local schema as throwaway — it is the single source of truth
- **Conflict resolution**: last-write-wins for reactions; attribute votes are overwriteable by the same user

### OCR Pipeline
Three-step flow:
1. **On-device**: Raw text extracted via **ML Kit** (no server call, no cost)
2. **Server-side async**: Raw text sent to backend LLM job for structured parsing → dish name, price, category
3. **User confirmation**: Parsed dishes staged for user review before entering the dish database

### Edit Governance — Approval Threshold
- Edit auto-applies when net upvotes (upvotes − downvotes) ≥ 3 within 7 days
- No consensus within 7 days: edit expires
- Admin can approve or reject any edit at any time, overriding vote state

### LLM Classification — Non-Blocking UX
- Dish is created and immediately visible with a `classifying` attribute state
- LLM job runs async via job queue; attributes populate on completion
- Frontend polls for attribute state or receives push notification
- Dishes in `classifying` state can already receive user reactions

### Taste Vector Update Frequency
- Updated incrementally in real-time on each reaction submission
- Weighted delta: `new_pref = old_pref + 0.1 * (dish_attr - old_pref)` (learning rate = 0.1)
- Background full-recompute job available for consistency correction

### Deployment & Scaling
- MVP: single VPS with in-process async job queue
- Job queue implemented behind an interface abstraction to allow swap to Redis + workers without schema changes
- Horizontal scaling target: Phase 3 launch

## Development Roadmap

- **Phase 1**: Utility core (OCR, reactions, ratings)
- **Phase 2**: Governance & data integrity (edit suggestions, moderation, access control)
- **Phase 3**: AI layer (LLM classification, Bayesian blending, taste vectors, confidence-gated predictions)
