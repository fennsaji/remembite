# Remembite – Master TODO

Last updated: 2026-07-08

---

## 🔴 Remaining Manual Setup (Phase 2)

- [x] Activate subscription products in Play Console (`remembite_pro_monthly`, `remembite_pro_annual`)
- [x] Play Console → Setup → API access → grant `remembite-play-api@remembite-7df00.iam.gserviceaccount.com` **Financial data viewer** role
- [x] Deploy backend to a public URL (VPS) — done: host Caddy → localhost:8080, ports moved to 20k range, CI/CD via `.github/workflows/deploy.yml`
- [x] Vector/Axiom logging: `vector` is behind `profiles: [logging]` in `docker-compose.prod.yml`; deploy workflow now passes `--profile logging` to both `pull` and `up`, so Vector keeps running after deploys.
- [ ] Create Pub/Sub push subscription → endpoint: `https://<backend-url>/webhooks/google-play?token=<GOOGLE_PUBSUB_WEBHOOK_TOKEN from .env.api — never commit the value>`
- [ ] Play Console → Monetize → Subscriptions → Real-time developer notifications → link topic `remembite-subscription-events`
- [ ] Fill in `.env.api` on production server:
  ```
  GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=<contents of ~/Documents/Remembite/play-service-account.json as single line>
  ```

---
