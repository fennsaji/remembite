# Remembite – Master TODO

Last updated: 2026-03-03

---

## 🔴 Remaining Manual Setup (Phase 2)

- [x] Activate subscription products in Play Console (`remembite_pro_monthly`, `remembite_pro_annual`)
- [x] Play Console → Setup → API access → grant `remembite-play-api@remembite-7df00.iam.gserviceaccount.com` **Financial data viewer** role
- [ ] Deploy backend to a public URL (VPS)
- [ ] Create Pub/Sub push subscription → endpoint: `https://<backend-url>/webhooks/google-play?token=9JDX8z3G4r1c5phijtYHl3c8umYlyd7iErTtBDXiz5c=`
- [ ] Play Console → Monetize → Subscriptions → Real-time developer notifications → link topic `remembite-subscription-events`
- [ ] Fill in `.env.api` on production server:
  ```
  GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=<contents of ~/Documents/Remembite/play-service-account.json as single line>
  ```

---
