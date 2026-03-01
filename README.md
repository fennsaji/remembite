# Remembite

**Building the Dish Intelligence Infrastructure for Dining**

Remembite is a dish-level intelligence platform that captures structured behavioral data from restaurant visits — dish reactions, flavor preferences, and repeat behavior — to help users make confident dining decisions in under 15 seconds.

## What It Does

- **Remember** what you ordered and loved (or didn't) at every restaurant
- **Discover** community-favorite dishes backed by aggregated reactions
- **Predict** dish compatibility using AI-powered personal taste modeling

## Architecture

A three-layer intelligence system:

| Layer | Purpose | Features |
|-------|---------|----------|
| Utility | Core tracking | Menu OCR, one-tap reactions, ratings, notes & photos |
| Community Data | Collective intelligence | Aggregated dish reactions, edit governance, structured dish database |
| AI Intelligence | Personalization | LLM classification, Bayesian flavor modeling, taste vectors, compatibility predictions |

## Tech Stack

- **Frontend**: Flutter (offline-first)
- **Backend**: Rust (Actix/Axum)
- **Database**: PostgreSQL
- **AI**: LLM-based structured classification with Bayesian community correction

## Roadmap

- **Phase 1** — Utility core (OCR, reactions, ratings)
- **Phase 2** — Governance & data integrity (edit suggestions, moderation, access control)
- **Phase 3** — AI layer (taste vectors, compatibility predictions, confidence-gated recommendations)

## License

All rights reserved.
