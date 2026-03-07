# Remembite – Technology Stack

---

## 1. Overview

This document is the authoritative reference for every technology, language, framework, service, and tool used in Remembite. All implementation decisions should align with the choices here. Changes to this document require explicit justification.

---

## 2. Frontend

### Language & Framework
| Choice | Rationale |
|---|---|
| **Dart** | Language for Flutter |
| **Flutter** | Single codebase for iOS + Android. Offline-first architecture maps well to Flutter's widget model. |

### State Management
| Choice | Rationale |
|---|---|
| **Riverpod** | Compile-safe, testable, no BuildContext dependency. Preferred over Bloc for this project's scale. |

### Local Storage (Offline-First)
| Choice | Rationale |
|---|---|
| **SQLite** via **Drift** | Type-safe SQLite ORM for Dart. Schema defined in Dart, migrations tracked. This is the primary source of truth on-device. |

### Networking
| Choice | Rationale |
|---|---|
| **Dio** | HTTP client with interceptors, retry logic, and cancellation. Used for all API calls to Rust backend. |

### On-Device AI / OCR
| Choice | Rationale |
|---|---|
| **Google ML Kit** (Text Recognition v2) | Free, on-device, no server call. Used for menu OCR step 1. Works offline. |

### Authentication
| Choice | Rationale |
|---|---|
| **Google Sign-In** (`google_sign_in` package) | Primary auth method. Returns OAuth token exchanged for a server-issued JWT. |

### Push Notifications
| Choice | Rationale |
|---|---|
| **Firebase Cloud Messaging (FCM)** | Used to notify the app when async LLM classification of a dish completes. |

### Image Handling
| Choice | Rationale |
|---|---|
| **image_picker** | Camera + gallery access for dish photos. |
| **cached_network_image** | CDN image caching and display. |

---

## 3. Backend

### Language & Framework
| Choice | Rationale |
|---|---|
| **Rust** | Memory safety without GC, excellent async performance, low resource footprint on VPS. |
| **Axum** | Tokio-native web framework. Cleaner ergonomics than Actix for this project's API surface. |
| **Tokio** | Async runtime. Axum requires it. |

### Database Access
| Choice | Rationale |
|---|---|
| **SQLx** | Async, compile-time SQL verification against live database. No ORM overhead. Raw SQL kept readable and explicit. |

### Serialisation
| Choice | Rationale |
|---|---|
| **Serde** + **serde_json** | Standard Rust serialisation. All API request/response structs derive `Serialize` / `Deserialize`. |

### Authentication
| Choice | Rationale |
|---|---|
| **jsonwebtoken** crate | JWT signing and verification. HS256 algorithm. Tokens issued after Google OAuth verification. |
| **Google OAuth** token verification | Backend verifies the Google ID token on sign-in, then issues its own short-lived JWT. |

### Async Job Queue
| Choice | Rationale |
|---|---|
| **In-process queue** (default) | Tokio task spawning behind a `JobQueue` trait. Zero infrastructure overhead at MVP scale. |
| **Redis + workers** (when needed) | Swap target when job queue depth grows under real load. The trait abstraction allows swapping without schema changes. |

### Password / Secret Management
| Choice | Rationale |
|---|---|
| Environment variables via `.env` | Loaded at startup via `dotenvy`. Never committed to version control. |

---

## 4. Database

### Cloud Database
| Choice | Rationale |
|---|---|
| **PostgreSQL 16** | Primary cloud database. Stores all public and private data layers. |
| **pgvector** extension | Taste vector similarity search. Schema prepared from day one; activate when taste vector engine is live. |

### Hosting

**Neon free tier** at launch. Upgrade to **Neon Launch plan (~$15/mo)** when compute hours or storage approach free tier limits. No migration required — same connection string, just a plan upgrade.

| Option | Launch Cost | Scale Cost | pgvector | Ops Burden |
|---|---|---|---|---|
| **Neon** ✓ | Free | ~$15/mo | Native | None |
| Self-host on Hetzner | ₹0 extra | ₹0 extra | Manual install | Medium |
| Supabase | Free | ~₹800/mo | Native | Low |
| DigitalOcean Managed | ~₹1,200/mo min | ~₹1,200/mo+ | Supported | Low |
| AWS RDS | ~₹2,500/mo min | ~₹2,500/mo+ | Supported | Low |

### On-Device Database
| Choice | Rationale |
|---|---|
| **SQLite** (via Drift on Flutter) | Offline-first local store. Schema mirrors PostgreSQL closely to simplify sync logic. |

### Schema Sync Strategy
- Local SQLite is source of truth for free users
- On Pro upgrade: full local history syncs to PostgreSQL retroactively
- Conflict resolution: last-write-wins on `updated_at` timestamp for reactions; attribute votes are user-overwriteable

---

## 5. AI / LLM Layer

### LLM Use Cases
The LLM performs two structured extraction tasks — neither requires deep reasoning:

1. **Dish Classification** — On dish creation: `dish_name + cuisine` → `spice_score`, `sweetness_score`, `dish_type`, `cuisine` as a typed JSON object. Seeded as probabilistic prior for Bayesian blending.
2. **OCR Menu Parsing** — Raw ML Kit text → structured dish entries (`name`, `price`, `category`). Runs async after menu scan.

### Provider Abstraction (Switchable)
The backend implements an `LlmProvider` trait (Rust) that all LLM calls go through. Switching providers requires changing one environment variable and one concrete implementation — no business logic changes.

```
LlmProvider trait
├── classify_dish(name, cuisine) → DishAttributes
└── parse_menu_ocr(raw_text) → Vec<ParsedDish>

Implementations:
├── GeminiProvider  ← active
├── ClaudeProvider
└── OpenAiProvider
```

### Current Provider
| Choice | Rationale |
|---|---|
| **Gemini 2.5 Flash-Lite** (Google) | Cheapest stable model ($0.10/$0.40 per 1M tokens). Free tier covers early-stage volume. Strong structured JSON output. Good Indian cuisine knowledge. |
| Config | `LLM_PROVIDER=gemini` in `.env`. API key via `GEMINI_API_KEY`. Model ID: `gemini-2.5-flash-lite`. |

### Provider Comparison (reference)
| Provider | Input | Output | Free Tier | Notes |
|---|---|---|---|---|
| **Gemini 2.5 Flash-Lite** ✓ | $0.10/1M | $0.40/1M | Yes | Current choice |
| GPT-4o-mini | $0.15/1M | $0.60/1M | No | Strong JSON mode |
| Claude Haiku 4.5 | $0.25/1M | $1.25/1M | No | Reliable structured output |

### Classification Cost Control
- Dishes are classified **once** on creation, result cached in PostgreSQL
- LLM cost does not scale with reactions — only with new dish additions
- Estimated cost: ~₹0.01–0.03 per dish at Gemini 2.0 Flash pricing

### Bayesian Blending
- Computed in Rust on the backend, not by the LLM
- Formula: `final_score = (k * llm_prior + n * community_avg) / (k + n)`, where `k = 5`
- No external service — pure computation

---

## 6. Infrastructure & Deployment

### Hosting
| Choice | Rationale |
|---|---|
| **Host.co.in SM-V1** (India) | Runs Rust backend + Nginx only. Database offloaded to Neon. 2 vCPU, 4 GB DDR5, 75 GB NVMe, 1 TB BW, AMD EPYC 4th Gen. ₹299/mo on annual plan (₹353/mo effective incl. 18% GST). ~10–40ms latency from India. Fallback: Contabo VPS 10 Navi Mumbai (~$7.59/mo) if reliability issues arise. |

### Reverse Proxy
| Choice | Rationale |
|---|---|
| **Nginx** | TLS termination, request routing to Axum backend. Simple configuration. |

### TLS
| Choice | Rationale |
|---|---|
| **Let's Encrypt** via **Certbot** | Free TLS certificates. Auto-renewal. |

### Containerisation
| Choice | Rationale |
|---|---|
| **Docker** | Backend and PostgreSQL run in containers. `docker-compose` for local dev parity. |

### CI/CD
| Choice | Rationale |
|---|---|
| **GitHub Actions** | Automated tests on PR, build + deploy on merge to `main`. |

---

## 7. Storage

### Object Storage (Images)
| Choice | Rationale |
|---|---|
| **Cloudflare R2** | S3-compatible, zero egress fees. Ideal for serving dish images via CDN. |

### CDN
| Choice | Rationale |
|---|---|
| **Cloudflare** (built into R2) | Global CDN, DDoS protection, and image serving included with R2. |

### Image Policy
- User-uploaded dish photos stored in R2
- Public images served via CDN URL; private images via signed URLs (time-limited)
- Image size limit enforced at API layer (max 5MB per upload)

---

## 8. Payments

### Platform Billing (Mandatory for In-App Subscriptions)
Google and Apple require their own billing systems for digital goods sold inside apps. Third-party payment providers (Razorpay, Stripe, etc.) cannot be used for in-app subscriptions.

| Platform | Provider | Status |
|---|---|---|
| **Android** | **Google Play Billing** | Shipped with Pro tier |
| **iOS** | **Apple App Store (StoreKit 2)** | Added when iOS app ships |

### Flutter Package
| Choice | Rationale |
|---|---|
| **`in_app_purchase`** (Flutter plugin) | Official plugin wrapping Google Play Billing Library and StoreKit. Single API for both platforms. |

### Subscription Flow (Android)
- Monthly plan: ₹49/month
- Annual plan: ₹399/year
- Purchase initiated via `in_app_purchase` → Google Play handles payment UI and recurring billing
- App receives purchase token → sent to backend for server-side verification via **Google Play Developer API**
- Backend updates `pro_status` in PostgreSQL on verified purchase
- Cancellations and refunds delivered via **Google Play Real-Time Developer Notifications** (Pub/Sub webhook)
- Graceful degradation on cancellation: data retained, Pro features locked

### Platform Fee Impact
| Platform | Fee | Net revenue on ₹49/mo |
|---|---|---|
| Google Play | 15% | ~₹41.65 |
| Apple App Store | 15%* | ~₹41.65 |

*15% applies under Apple's Small Business Program (revenue < $1M/year). Defaults to 30% otherwise.

---

## 9. Monitoring & Observability

### Error Tracking
| Choice | Rationale |
|---|---|
| **Sentry** | Rust SDK for backend errors, Flutter SDK for frontend crashes. Free tier covers MVP scale. |

### Metrics
| Choice | Rationale |
|---|---|
| **Prometheus** + **Grafana** | Backend exposes `/metrics` endpoint. Self-hosted on the same VPS. |

### Product Analytics
| Choice | Rationale |
|---|---|
| **PostHog** (self-hosted) | Open-source product analytics. Track conversion funnel, upgrade triggers, feature usage. Self-hosted to avoid per-event costs at early stage. |

---

## 10. Development Tooling

| Tool | Purpose |
|---|---|
| **Git** + **GitHub** | Version control and collaboration |
| **Docker Compose** | Local dev environment (Postgres + backend) |
| **cargo-watch** | Auto-recompile Rust on file change during development |
| **sqlx-cli** | Run and manage PostgreSQL migrations |
| **flutter_test** | Unit and widget tests for Flutter |
| **cargo test** | Unit and integration tests for Rust backend |
| **Postman** / **Bruno** | API testing during development |
| **Pencil** | UI design (`.pen` files in `design/`) |

---

## 11. Security Considerations

| Area | Approach |
|---|---|
| Auth | JWT with short expiry (24h access token, 30-day refresh token) |
| API | Rate limiting per user via Axum middleware |
| Images | Signed URLs for private content; moderation queue for public uploads |
| Secrets | Environment variables only; no secrets in source code |
| SQL | SQLx compile-time query verification; no string concatenation in queries |
| Data isolation | PostgreSQL row-level access enforced at API — users cannot access other users' private data |

---

## 12. What Is Explicitly Not Used

| Excluded | Reason |
|---|---|
| Firebase Firestore / Realtime DB | Avoid lock-in; PostgreSQL + Rust gives full control |
| GraphQL | REST is sufficient for this API surface; no client-defined query needs |
| Kubernetes | Overkill at current scale; single VPS with Docker Compose suffices until load demands horizontal scaling. Contabo has no auto-scaling — scale manually via Cloudflare LB + second VPS when CPU >70% sustained. |
| Next.js / web frontend | Mobile-only product at launch; no web app planned until Year 2 |
| LLM provider lock-in | `LlmProvider` trait abstracts all calls — provider is swappable via config, not code changes |
| Razorpay / third-party payment gateways | Google and Apple mandate their own billing for in-app digital subscriptions; third-party processors are not permitted |

---

End of Tech Stack
