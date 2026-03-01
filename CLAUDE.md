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

## Development Roadmap

- **Phase 1**: Utility core (OCR, reactions, ratings)
- **Phase 2**: Governance & data integrity (edit suggestions, moderation, access control)
- **Phase 3**: AI layer (LLM classification, Bayesian blending, taste vectors, confidence-gated predictions)
