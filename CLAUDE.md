# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Working Rules

- **Update docs before code**: Any change that deviates from the existing design or plan must be documented first (PRD.md, Wireframes.md, RoadMap.md, Dev Prompts.md as appropriate) before any code is written.
- **Don't jump the gun**: Answer questions and wait for explicit instructions before making changes.

## Project Overview

Remembite is a dish-level intelligence platform for dining. It captures structured behavioral data from restaurant visits (dish reactions, flavor preferences, repeat behavior) and builds personalized taste models. Not a review app — a self-correcting, community-powered, AI-augmented dish intelligence system.

## Technical Stack

- **Frontend**: Flutter (offline-first, Riverpod + GoRouter + Drift + Dio)
- **Backend**: Rust (Axum)
- **Database**: PostgreSQL (server) + SQLite via Drift (on-device)
- **AI**: Gemini for LLM classification via async job queue
- **Deployment**: Docker Compose (dev), VPS (prod)

## Commands

### Backend
```bash
./run-api.sh          # start foreground (docker compose up with .env.api)
./run-api.sh -d       # start detached
./run-api.sh down     # stop containers
./run-api.sh logs -f  # tail logs

cd backend && cargo check   # compile check (no DATABASE_URL needed)
```

### Flutter App
```bash
./run-app.sh                    # Android emulator (uses .env.android)
./run-app.sh .env.ios           # iOS simulator
./run-app.sh .env.android emulator-5554  # explicit device

cd app && flutter analyze                    # lint
cd app && dart run build_runner build        # generate .g.dart files
cd app && dart run build_runner watch        # generate on save
```

### Environment Files
- `.env.api` — backend secrets (JWT, Gemini, DB creds); passed via `--env-file` to docker compose
- `.env.android` — `API_URL=http://10.0.2.2:8080` (emulator → host)
- `.env.ios` — `API_URL=http://localhost:8080`
- `API_URL` is injected at build time via `--dart-define=API_URL=...`

## Code Architecture

### Backend (`backend/src/`)

`AppState` (in `main.rs`) is cloned per request and holds:
- `db: PgPool` — sqlx connection pool
- `config: Arc<Config>` — all env vars (`config.rs`)
- `llm: Arc<dyn LlmProvider>` — Gemini abstraction (`llm/`)
- `job_queue: Arc<dyn JobQueue>` — in-process channel queue (`jobs/`)
- `http: reqwest::Client` — for outbound HTTP (Google token verification)

Migrations run automatically on startup via `sqlx::migrate!("./migrations").run(&db)`. Use non-macro `sqlx::query()` builders (not `sqlx::query!`) — no `DATABASE_URL` needed at compile time.

**Route modules** each export a `router()` function that returns `Router<AppState>`, nested in `main.rs`:
```
routes/health.rs        GET /health
routes/auth.rs          POST /auth/google
routes/restaurants.rs   /restaurants (nearby, create, detail, patch, duplicate-check)
routes/dishes.rs        /restaurants/:id/dishes + /dishes/:id (reactions, favorites, votes)
routes/ratings.rs       /restaurants/:id/ratings
routes/search.rs        /search?q=
routes/timeline.rs      /users/me/timeline
```

**Auth**: `AuthUser` extractor in `auth/middleware.rs` validates JWT from `Authorization: Bearer` header. Use `#[allow(dead_code)]` on fields/methods needed in Phase 2+.

**Jobs**: `Job` enum dispatched through `InProcessQueue` → `jobs/worker.rs` loop. Current jobs: `ParseMenuOcr` (raw text → structured dishes), `ClassifyDish` (dish → spice/sweetness attributes via Gemini).

### Flutter App (`app/lib/`)

**Entry**: `main.dart` → `ProviderScope` → `RemembiteApp` → `MaterialApp.router` with `appRouterProvider`.

**State management**: All providers use `@riverpod` annotation (Riverpod generator). Run `build_runner` after changing annotated classes/functions.

**Navigation** (`core/router/app_router.dart`):
- `GoRouter` with redirect: unauthenticated → `/auth/sign-in`; authenticated on auth route → `/home`
- `ShellRoute` wraps `/home`, `/favorites`, `/timeline`, `/profile` with `MainShell` (floating pill nav)
- Scan and onboarding routes are outside the shell (full-screen)

**Auth** (`core/network/auth_state.dart`):
- `AuthUser` persisted to `FlutterSecureStorage` as JSON under key `auth_user`
- `authStateProvider` loads on cold start; `signIn()`/`signOut()` update both storage and provider state
- Dio interceptor reads `authStateProvider` to attach `Authorization: Bearer` on every request

**Local DB** (`core/db/`):
- `AppDatabase` (Drift) opens `remembite.db`; tables: restaurants, dishes, reactions, ratings, favorites
- Each table has a corresponding DAO in `core/db/daos/`
- `synced_at` column on each table marks sync state; `null` = pending upload (Pro sync)

**Feature structure**: each feature under `features/<name>/` follows `data/` (repository + models) + `presentation/` (screens + `.g.dart`). Repositories call the API via `apiClientProvider` (Dio) and write results to Drift.

## Architecture Decisions

### Bayesian Prior Weight (`k`)
- `k = 5` — LLM prior counts as 5 community votes
- n < 5: AI-dominated; n > 20: community-dominated

### Confidence Threshold for Compatibility Predictions
Both must be true before showing a prediction:
1. User has ≥ 10 personal reactions to dishes with overlapping attributes
2. Dish has ≥ 10 community votes

### Offline-First + Cloud Sync
- All data stored locally in SQLite from Day 1 (free and Pro)
- Cloud sync is Pro-only — local schema is the single source of truth, not throwaway
- Conflict resolution: last-write-wins for reactions; attribute votes overwriteable by same user
- On Pro upgrade: full local history syncs retroactively

### OCR Pipeline
1. **On-device**: ML Kit extracts raw text (no server call)
2. **Server async**: `Job::ParseMenuOcr` → Gemini → structured dish list
3. **User confirmation**: staged in `OcrResultsScreen` before `batchCreateDishes()`

### LLM Classification — Non-Blocking UX
- Dish created immediately in `classifying` attribute state (can receive reactions)
- `Job::ClassifyDish` runs async; attributes populate when complete
- Frontend uses shimmer animation (not spinner) for `classifying` state

### Taste Vector Update
- Incremental on each reaction: `new_pref = old_pref + 0.1 * (dish_attr - old_pref)` (learning rate = 0.1)

### Edit Governance (Phase 2)
- Edit auto-applies at net upvotes ≥ 3 within 7 days; expires otherwise

### Deployment
- MVP: single VPS, in-process job queue (interface abstraction allows swap to Redis without schema changes)

## Design System — Turmeric & Nightfall

UI must match `design/remembite.pen` exactly. Open in Pencil before building any screen. Do not invent UI — implement what is designed.

### Dark Theme
| Role | Token | Hex |
|---|---|---|
| Background | Abyss | `#0F0D0B` |
| Surface | Embers | `#1A1612` |
| Elevated surface | Char | `#241E18` |
| Border | Dusk | `#2E2520` |
| Primary text | Cream | `#F5EEE4` |
| Secondary text | Parchment | `#B89F87` |
| Muted text | Ash | `#8E7868` |
| Accent | Turmeric | `#E6A830` |
| Accent pressed | Saffron | `#C98A1A` |
| Error | Chili | `#D95F3B` |
| Pro surface | Gilded | `#2A2115` |
| Pro accent | Gold Leaf | `#F0C060` |

### Light Theme
| Role | Token | Hex |
|---|---|---|
| Background | Linen | `#FAF7F2` |
| Surface | Cotton | `#F2EDE5` |
| Elevated surface | Pearl | `#EBE4D9` |
| Border | Wheat | `#D9CFC3` |
| Primary text | Espresso | `#1C1410` |
| Secondary text | Bark | `#5C4A38` |
| Muted text | Sand | `#7A6350` |
| Accent | Turmeric | `#C47E10` |
| Accent pressed | Deep Amber | `#A36808` |
| Error | Chili | `#C04A28` |
| Pro surface | Honey | `#FFF3D6` |
| Pro accent | Amber Pro | `#B8720E` |

### Typography
- **Display / headlines**: Fraunces (variable serif, Google Fonts)
- **Body / labels / UI**: DM Sans (Google Fonts)
- Section labels: UPPERCASE, 11px, DM Sans 600, secondary text, preceded by 24×2px accent bar
- Tab bar: floating pill (`#241E18` background, `#E6A830` active item)

### Implementation Rules
- `AppColorsDark` and `AppColorsLight` in `app/lib/core/theme/app_theme.dart`
- `typedef AppColors = AppColorsDark` for screens using dark only
- Pro surfaces: `LinearGradient` from surface → proSurface at 15% opacity (never flat gold fill)
- `classifying` state: mutedText color + shimmer animation

## Development Roadmap

- **Phase 1**: Utility core — OCR, reactions, ratings, search, timeline ✅
- **Phase 2**: Governance & data integrity — edit suggestions, moderation, access control
- **Phase 3**: AI layer — LLM classification, Bayesian blending, taste vectors, confidence-gated predictions
