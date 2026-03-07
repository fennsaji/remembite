# Remembite – Production Deployment Guide

Last updated: 2026-03-05

---

## Overview

| Component | Technology | Provider |
|---|---|---|
| Backend API | Rust / Axum | Host.co.in VPS (SM-V1) |
| Database | PostgreSQL 16 | Neon (serverless Postgres) |
| Image storage | S3-compatible | Cloudflare R2 |
| Push notifications | FCM | Firebase |
| Auth | Google Sign-In | Google Cloud |
| Payments | Google Play Billing | Google Play Console |
| DNS + CDN | Cloudflare | — |
| Android app | Flutter | Google Play Store |

---

## 1. Prerequisites

**Already done during development** (no action needed):
- [x] Cloudflare account with R2 bucket `remembite-images` (Phase 6)
- [x] Firebase project `remembite-7df00` with FCM + `google-services.json` in app (Phase 1)
- [x] Google Cloud project with Maps SDK, Places API, OAuth client, Geocoding API (Phase 5.5)
- [x] Gemini API key from Google AI Studio (Phase 1)
- [x] Google Play Console developer account + app `com.fennsaji.remembite` + subscriptions created (Phase 7)

**New — needed for production only**:
- [ ] Host.co.in account + VPS ordered + SSH key added (Section 2)
- [ ] Neon `main` branch switched to production (dev branch already exists — Section 3)
- [ ] Domain `api.remembite.app` pointing to VPS IP (Section 2.2)

---

## 2. VPS Setup (Host.co.in SM-V1)

### 2.0 Create Host.co.in account

```
1. Go to host.co.in → Sign Up
2. Verify email and add a payment method (credit card / UPI / NetBanking)

3. Generate your SSH key if you don't have one:
   ssh-keygen -t ed25519 -C "remembite-deploy"
   cat ~/.ssh/id_ed25519.pub   ← paste this during/after order
```

### 2.1 Order server

```
host.co.in → VPS Hosting → SM-V1 → Configure:

  Billing Cycle:      Annually — ₹299/mo (Save 50%)
  Operating System:   ubuntu-24.04-x86_64
  Control Panel:      None
  LiteSpeed:          None  (we use Nginx)
  Backup:             No Thanks  (DB is on Neon, images on R2 — VPS has no irreplaceable data)
  Firewall:           No Firewall  (we configure ufw ourselves — see 2.3)
  Immunify360:        None  (PHP/cPanel tool, irrelevant for Docker/Rust)
  Server Management:  Self Managed

  Total: ₹3,588/year + 18% IGST = ₹4,233.84/year (~₹353/mo effective)

→ Continue → complete payment

Note: VPS only runs the Rust backend + Nginx. DB is on Neon, images on Cloudflare R2.

Note the server's public IPv4 address — you'll use it throughout this guide as <server-ip>.
```

### 2.2 Point your domain to the VPS

```
In your DNS provider (or Cloudflare if you added the domain there):
  A record:  api.remembite.app  →  <server-ip>
  TTL: 300 (5 minutes)

Verify: dig api.remembite.app +short
Expected: <server-ip>
```

### 2.3 Initial server setup

```bash
ssh root@<server-ip>

# Update system
apt update && apt upgrade -y

# ── Firewall (ufw) ──────────────────────────────────────────────────────────
# Do this FIRST — before opening any services
ufw default deny incoming   # block everything by default
ufw default allow outgoing  # allow outbound (apt, Docker pulls, Neon, R2, etc.)
ufw allow 22/tcp            # SSH — do this before enabling or you'll lock yourself out
ufw allow 80/tcp            # HTTP (Nginx redirects to HTTPS)
ufw allow 443/tcp           # HTTPS
ufw enable                  # confirm with 'y'
ufw status                  # verify: 22, 80, 443 should show ALLOW

# ── Docker ──────────────────────────────────────────────────────────────────
# SM-V1 is KVM-based — Docker is fully supported
curl -fsSL https://get.docker.com | sh
docker run --rm hello-world   # should print "Hello from Docker!"
apt install docker-compose-plugin -y

# ── App user ────────────────────────────────────────────────────────────────
useradd -m -s /bin/bash remembite
usermod -aG docker remembite

# Create app directory
mkdir -p /opt/remembite
chown remembite:remembite /opt/remembite
```

### 2.4 Install Nginx + SSL

```bash
apt install nginx certbot python3-certbot-nginx -y

# Get SSL certificate (domain must point to this server already — see 2.2)
certbot --nginx -d api.remembite.app

# Nginx config: /etc/nginx/sites-available/remembite
cat > /etc/nginx/sites-available/remembite << 'EOF'
server {
    server_name api.remembite.app;
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 60s;
        client_max_body_size 10M;
    }
    listen 443 ssl;
    # certbot fills in SSL config automatically
}
server {
    listen 80;
    server_name api.remembite.app;
    return 301 https://$host$request_uri;
}
EOF

ln -s /etc/nginx/sites-available/remembite /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
```

---

## 3. Database (Neon)

### 3.0 Create Neon account

```
1. Go to neon.tech → Sign Up (GitHub SSO works)
   Free tier: 0.5 GB storage, 1 compute — sufficient for MVP

2. After sign-in → New Project:
   Name: remembite
   Region: AWS ap-south-1 (Mumbai) — lowest latency for India
   Postgres version: 16
   → Create Project

3. On the dashboard copy the connection string:
   postgres://remembite:<password>@<host>.neon.tech/remembite?sslmode=require
   (Store this as DATABASE_URL in your .env.api)
```

### 3.1 Configure database branches

```
Neon Dashboard → remembite project → Branches:
  - main branch = production DB (default)
  - Create a "dev" branch for local development:
    Branches → Create Branch → Name: dev → Branch from: main
    Use this branch's connection string in your local .env.api
```

### 3.2 Run migrations

Migrations run automatically on backend startup. To run manually:

```bash
cargo install sqlx-cli --no-default-features --features postgres
cd backend
DATABASE_URL="postgres://..." sqlx migrate run
```

### 3.3 Neon settings

- **Compute**: Auto-suspend after 5 minutes idle (free tier default — fine for MVP)
- **Connection pooling**: Enable PgBouncer for production (Neon Dashboard → branch → Connection Pooling → Enable)

---

## 4. Cloudflare (R2 Image Storage + DNS)

### 4.0 Cloudflare account

Already set up in Phase 6. R2 bucket `remembite-images` exists. Skip to 4.2 if the API token is already saved.

### 4.1 Create bucket

```
1. Cloudflare Dashboard → R2 → Create bucket
2. Bucket name: remembite-images
3. Location: Auto (or APAC for India)
→ Create bucket
```

### 4.2 Create API token

```
1. R2 → Manage R2 API Tokens → Create API Token
2. Token name: remembite-backend
3. Permissions: Object Read & Write
4. Specify bucket: remembite-images (limit scope)
→ Create API Token

Copy and store (shown only once):
  - Account ID (shown at top of R2 page)
  - Access Key ID
  - Secret Access Key
```

### 4.3 Enable public access (for dish images CDN)

```
Option A — free r2.dev subdomain:
  R2 → remembite-images → Settings → Public Access → Allow Access
  Copy the URL: https://pub-<hash>.r2.dev
  Use this as R2_PUBLIC_URL in .env.api

Option B — custom domain (recommended):
  R2 → remembite-images → Settings → Custom Domains → Connect Domain
  Enter: images.remembite.app
  Cloudflare adds a CNAME automatically if your domain is on Cloudflare
  Use https://images.remembite.app as R2_PUBLIC_URL
```

---

## 5. Firebase (FCM Push Notifications)

### 5.0 Firebase project

Already set up in Phase 1. Project `remembite-7df00` exists, `google-services.json` is in `app/android/app/`. Skip to 5.1 if the service account JSON is already saved.

### 5.1 Service account for backend

```
1. Firebase Console → Project Settings → Service Accounts
2. Click "Generate new private key" → Download JSON
   Save as: remembite-firebase-adminsdk.json (DO NOT commit this file)
3. Minify to single line for use as env var:
   cat remembite-firebase-adminsdk.json | jq -c .
4. Store the minified JSON as FCM_SERVICE_ACCOUNT_JSON in .env.api
```

### 5.2 Get project ID

```
Firebase Console → Project Settings → General → Project ID
e.g. remembite-7df00
Store as FCM_PROJECT_ID in .env.api
```

---

## 6. Google Cloud Setup

### 6.0 Google Cloud project

Already set up in Phase 5.5 (Maps/Places) and Phase 1 (OAuth). Project `remembite-7df00` is the Firebase-linked GCP project. Billing is already enabled. Skip to 6.1 if credentials are already saved.

### 6.1 Google Sign-In OAuth client

```
1. Google Cloud Console → APIs & Services → Credentials
2. Create Credentials → OAuth 2.0 Client ID
   Application type: Web application
   Name: Remembite Backend
   Authorised JavaScript origins: https://api.remembite.app
   Authorised redirect URIs: (leave empty — app uses ID token flow, not redirect)
3. Copy Client ID → GOOGLE_CLIENT_ID in .env.api

Also create an Android OAuth client (for app to generate valid ID tokens):
   Application type: Android
   Package name: com.fennsaji.remembite
   SHA-1: (run: cd app/android && ./gradlew signingReport)
```

### 6.2 Maps + Places API key

```
1. APIs & Services → Library → Search and enable:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Places API (New)
   - Geocoding API

2. APIs & Services → Credentials → Create Credentials → API key
   Name: Remembite Maps Key
   Application restrictions: Android apps + iOS apps
   API restrictions: restrict to the 4 APIs above

3. Copy key → add to android/local.properties:
   MAPS_API_KEY=AIza...

4. Build with: flutter run --dart-define=MAPS_API_KEY=AIza...
```

### 6.3 Gemini API key

```
1. Go to aistudio.google.com → Sign in with Google
2. Get API key → Create API key in existing project → select "remembite"
3. Copy key → GEMINI_API_KEY in .env.api

Free tier: 15 requests/min, 1M tokens/day — sufficient for MVP
```

---

## 7. Google Play Console

### 7.0 Developer account

Already set up in Phase 7. App `com.fennsaji.remembite` exists in Play Console with subscriptions created. Skip to 7.2 if the service account JSON is already saved.

### 7.1 Create subscription products

```
Play Console → Remembite → Monetize → Subscriptions → Create subscription

Product 1:
  Product ID:  remembite_pro_monthly
  Name:        Remembite Pro Monthly
  Price:       ₹49.00 / month
  Grace period: 3 days

Product 2:
  Product ID:  remembite_pro_annual
  Name:        Remembite Pro Annual
  Price:       ₹399.00 / year
  Grace period: 3 days
```

### 7.2 Google Play service account

```
1. Google Cloud Console → IAM & Admin → Service Accounts → Create Service Account
   Name: remembite-play-api
   → Create and continue
   Role: (skip — permissions are set in Play Console)
   → Done

2. Click the service account → Keys → Add Key → JSON → Create
   Download JSON → save as play-service-account.json (DO NOT commit)
   Minify: cat play-service-account.json | jq -c .
   Store as GOOGLE_PLAY_SERVICE_ACCOUNT_JSON in .env.api

3. Play Console → Setup → API access
   → Link to Google Cloud project → select "remembite-7df00"
   → Grant access to the service account:
     remembite-play-api@remembite-7df00.iam.gserviceaccount.com
     Role: Financial data viewer (allows reading subscription state)
   → Invite user → Send invitation
```

### 7.3 Pub/Sub webhook (real-time subscription events)

```
1. Google Cloud Console → Pub/Sub → Topics → Create Topic
   Topic ID: remembite-subscription-events
   → Create

2. Create push subscription:
   Topics → remembite-subscription-events → Create subscription
   Subscription ID: remembite-subscription-push
   Delivery type: Push
   Endpoint URL: https://api.remembite.app/webhooks/google-play?token=<GOOGLE_PUBSUB_WEBHOOK_TOKEN>
   Acknowledgement deadline: 30s
   → Create

3. Play Console → Monetize → Subscriptions → Real-time developer notifications
   Topic: projects/remembite-7df00/topics/remembite-subscription-events
   → Save
```

### 7.4 Test the webhook

```bash
# Verify endpoint is reachable
curl -X POST "https://api.remembite.app/webhooks/google-play?token=<token>" \
  -H "Content-Type: application/json" \
  -d '{"message":{"data":"dGVzdA=="}}'
# Expected: 200 OK
```

---

## 8. Backend Environment Variables

Create `/opt/remembite/.env.api` on the VPS:

```env
# Database
DATABASE_URL=postgres://remembite:<password>@<host>.neon.tech/remembite?sslmode=require

# JWT
JWT_SECRET=<generate: openssl rand -hex 64>
JWT_ACCESS_EXPIRY_HOURS=24
JWT_REFRESH_EXPIRY_DAYS=30

# Google
GOOGLE_CLIENT_ID=<from Google Cloud Console OAuth client>

# Gemini AI
GEMINI_API_KEY=<from Google AI Studio — see Section 6.3>

# Cloudflare R2
R2_ACCOUNT_ID=<from Cloudflare dashboard — top of R2 page>
R2_ACCESS_KEY_ID=<from R2 API token>
R2_SECRET_ACCESS_KEY=<from R2 API token>
R2_BUCKET=remembite-images
R2_PUBLIC_URL=https://images.remembite.app

# Firebase FCM
FCM_SERVICE_ACCOUNT_JSON=<minified JSON from Firebase service account — see Section 5.1>
FCM_PROJECT_ID=remembite-7df00

# Google Play Billing
GOOGLE_PLAY_PACKAGE_NAME=com.fennsaji.remembite
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=<minified JSON from play-service-account.json — see Section 7.2>
GOOGLE_PUBSUB_WEBHOOK_TOKEN=<generate: openssl rand -hex 32>

# Server
SERVER_PORT=8080
RUST_LOG=info
```

Generate secrets:

```bash
openssl rand -hex 64   # for JWT_SECRET
openssl rand -hex 32   # for GOOGLE_PUBSUB_WEBHOOK_TOKEN
```

---

## 9. Backend Docker Deployment

### 9.1 Create production Dockerfile

Create `backend/Dockerfile.prod`:

```dockerfile
FROM rust:1.87-slim-bookworm AS builder
WORKDIR /app
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs && cargo build --release && rm -rf src
COPY src ./src
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates libssl-dev && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/remembite-backend /usr/local/bin/remembite-backend
EXPOSE 8080
CMD ["remembite-backend"]
```

### 9.2 Create production docker-compose

Create `docker-compose.prod.yml` on the VPS at `/opt/remembite/`:

```yaml
services:
  backend:
    image: remembite-backend:latest
    env_file: .env.api
    ports:
      - "8080:8080"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### 9.3 Deploy

```bash
# On your local machine — build and push image to VPS
docker build -f backend/Dockerfile.prod -t remembite-backend:latest ./backend
docker save remembite-backend:latest | ssh root@<server-ip> docker load

# On VPS
cd /opt/remembite
docker compose -f docker-compose.prod.yml up -d

# Check logs
docker compose -f docker-compose.prod.yml logs -f
```

### 9.4 Redeploy on update

```bash
# Build new image locally
docker build -f backend/Dockerfile.prod -t remembite-backend:latest ./backend
docker save remembite-backend:latest | ssh root@<server-ip> docker load

# Zero-downtime restart
ssh root@<server-ip> "cd /opt/remembite && docker compose -f docker-compose.prod.yml up -d --no-deps backend"
```

---

## 10. Flutter App Release Build (Android)

### 10.1 Signing config

```bash
# Generate keystore (one-time — keep this file safe, losing it = can't update the app)
keytool -genkey -v -keystore ~/remembite-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias remembite

# Add to app/android/key.properties (never commit this file)
storePassword=<your-password>
keyPassword=<your-password>
keyAlias=remembite
storeFile=/Users/<you>/remembite-release.jks
```

### 10.2 Build release AAB

```bash
cd app
flutter build appbundle \
  --release \
  --dart-define=API_URL=https://api.remembite.app \
  --dart-define=MAPS_API_KEY=<your-maps-api-key>

# Output: build/app/outputs/bundle/release/app-release.aab
```

### 10.3 Upload to Play Console

```
Play Console → Remembite → Release → Testing → Internal testing → Create new release
(Start with Internal testing for first upload — Google reviews the app before Production)

Upload: app-release.aab
Release notes (en-IN): Initial release
→ Save → Review release → Start rollout

Once approved, promote to Production:
Release → Production → Promote release
```

---

## 11. Verify Production Checklist

Run these after deployment:

```bash
# Backend health
curl https://api.remembite.app/health
# Expected: {"status":"ok"}

# Auth endpoint reachable
curl -X POST https://api.remembite.app/auth/google \
  -H "Content-Type: application/json" \
  -d '{"id_token":"invalid"}'
# Expected: 401 (not 500 — confirms DB + JWT wired up)

# Search endpoint
curl "https://api.remembite.app/search?q=biryani"
# Expected: {"restaurants":[],"dishes":[]}

# Webhook token
curl -X POST "https://api.remembite.app/webhooks/google-play?token=WRONG"
# Expected: 401

# SSL cert valid
curl -I https://api.remembite.app/health
# Expected: HTTP/2 200
```

---

## 12. Post-Deploy Monitoring

> **When to scale**: See `docs/RoadMap.md` → Section 15 (Scale-Up Track) for trigger signals and ordered steps. Summary: enable Cloudflare Load Balancing ($5/mo) + add second Contabo VPS when CPU >70% sustained; upgrade Neon when compute hours approach limit; migrate job queue to Redis when queue depth grows.

| What | How |
|---|---|
| Backend logs | `docker compose -f docker-compose.prod.yml logs -f` |
| Nginx logs | `tail -f /var/log/nginx/access.log` |
| DB connections | Neon Console → Monitoring |
| R2 usage | Cloudflare Dashboard → R2 → Metrics |
| FCM delivery | Firebase Console → Cloud Messaging → Reports |
| Subscription events | Play Console → Monetize → Subscriptions |

---

## 13. Renewing SSL Certificate

Certbot auto-renews every 90 days via a systemd timer. To force renew:

```bash
certbot renew --dry-run   # test
certbot renew             # actual
systemctl reload nginx
```

---

## 14. Quick Reference — Useful Commands

```bash
# Restart backend
ssh root@<server-ip> "cd /opt/remembite && docker compose -f docker-compose.prod.yml restart backend"

# View live logs
ssh root@<server-ip> "docker compose -f docker-compose.prod.yml logs -f --tail=100"

# Run DB migrations manually
ssh root@<server-ip> "docker run --rm --env-file /opt/remembite/.env.api \
  remembite-backend:latest remembite-backend --migrate-only"
# Note: migrations run automatically on startup — this is only needed for manual runs

# Check disk usage
ssh root@<server-ip> df -h

# Rotate JWT secret (forces all users to re-login)
# 1. Generate new secret: openssl rand -hex 64
# 2. Update JWT_SECRET in /opt/remembite/.env.api
# 3. Restart: docker compose -f docker-compose.prod.yml restart backend
```
