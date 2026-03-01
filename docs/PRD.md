# Remembite – Product Requirements Document (PRD)

---

## 1. UI Screen Coverage

All screens below are mandatory functional coverage for MVP + AI-enhanced roadmap.

### 1.1 Home Screen

Components:

* Search bar (fuzzy match across restaurants & dishes)
* Nearby Restaurants list (with star rating)
* Recently Visited list
* Floating Action Button: Scan Menu (secondary flow — not primary onboarding path)
* Bottom Navigation: Home | Map | Favorites | Profile

Behavior:

* Auto-detect nearby restaurants via GPS
* Manual "Add New" option inside search
* Default entry point for returning users is the Recently Visited list, not OCR

---

### 1.2 Restaurant Super Screen

Sections (in order):

1. Header (Name + Star Rating + Rate + Suggest Edit)
2. "Your Top Bites" (sorted by user reactions)
3. "Community Favorites" (sorted by weighted reactions, minimum 5 votes)
4. Full Menu (collapsed by default, first 5 visible)
5. Subtle "Pending Community Updates" link

---

### 1.3 Dish Detail Screen

Must support:

* Display selected reaction
* AI compatibility signal (shown only if confidence threshold met — Pro users only)
* "Classifying..." attribute state while LLM job is pending
* Private notes input
* Image upload with public/private toggle
* Optional spice intensity voting
* Optional sweetness intensity voting
* Save changes

---

### 1.4 Passive Restaurant Rating Bottom Sheet

Trigger:

* After 2+ dish reactions in same session

Must support:

* 1–5 star selection
* One rating per user (editable)
* Single prompt per session

---

### 1.5 Suggest Edit Flow

Modal includes:

* Select editable field (Name / Location / Cuisine)
* Proposed value input
* Submit button

Pending Edits View:

* Proposed change display
* Net approval count
* Approve button
* Auto-apply when net upvotes ≥ 3 within 7 days
* Edit expires if no consensus within 7 days

Note: In early stages (pre-community scale), admin manually applies edits. Community voting UI is visible but approval is admin-gated until user density justifies automation.

---

### 1.6 Map View

Default:

* Display only visited restaurants

Toggle:

* Show nearby restaurants

Pin interaction:

* Opens Restaurant Super Screen

---

### 1.7 Favorites Screen

Must support:

* List of favorited dishes
* Filter by reaction level
* Filter by restaurant
* Sorting by most recent
* Sorting by highest reaction weight

---

### 1.8 Profile Screen

Must display:

* Total restaurants visited
* Total dishes tracked
* Most used reaction
* Taste Profile Completion indicator (e.g., "Your taste profile is 60% complete — react to 4 more dishes to unlock predictions")

Pro Section:

* Taste insights summary
* Upgrade to Pro button

---

### 1.9 Upgrade Screen

Feature order must lead with the primary value driver (AI intelligence), not restriction removal:

* AI Taste Compatibility Predictions
* Advanced Taste Insights
* Cloud Sync (cross-device access)
* Unlimited Dish Tracking

Pricing:

* ₹49 / month
* ₹399 / year (save 32%) — displayed as primary option

Behavior:

* Subscribe button
* Annual plan highlighted as recommended

---

### 1.10 Visit Timeline Screen

Must display:

* Chronological list of visits grouped by month/year
* Each entry: restaurant name + dishes reacted to + reaction emoji

Behavior:

* Private to user — never exposed publicly
* No pagination required in MVP

---

### 1.11 Search Results Screen

Must display:

* Grouped results: Restaurants section + Dishes section
* Dish results show which restaurants serve them

Prioritization:

1. Exact match
2. Partial match
3. Popularity (rating or reaction count)

---

### 1.12 Settings Screen

Must include:

* Account management
* Cloud Sync toggle (Pro only)
* Export Data option
* Subscription management
* Privacy Controls
* Help & Support

---

### 1.13 Onboarding Screen

Must support:

* App intro + tagline ("Remember What You Loved.")
* Sign in / continue with Google
* Taste bootstrapping step: "Quick — pick a few dishes you love or hate" (optional, skippable)
  * Presents 10–15 common dishes across cuisines
  * User reacts (🔥 / 🤢 / Skip)
  * Pre-populates taste vector to accelerate first predictions
  * Clearly labeled as "Help us learn your taste — takes 30 seconds"
* Skip option must always be visible

Behavior:

* Bootstrapping reactions count toward the ≥10 personal reaction threshold for AI predictions
* Skipping does not block access — user builds profile through normal use

---

## 2. Ranking & Display Logic

### 2.1 Dish Reaction Weight Mapping

Reactions are internally mapped to numeric weights:

* 🔥 So Yummy = 5
* 😋 Tasty = 4
* 🙂 Pretty Good = 3
* 😐 Meh = 2
* 🤢 Never Again = 1

---

### 2.2 Community Dish Ranking

Public dish ranking score:

```
weighted_score = (5*yummy + 4*tasty + 3*pretty_good + 2*meh + 1*never_again) / total_votes
```

Threshold:

* Minimum 5 votes required before surfacing in "Community Favorites"
* Below threshold → marked as "New"

---

### 2.3 Your Top Bites Sorting

Sorted by:

1. Highest reaction weight
2. Most recent reaction (tie-breaker)

No time decay in MVP.

---

## 3. Search & Filtering Specifications

### 3.1 Search Scope

Search must support:

* Restaurant name search
* Dish name search
* Fuzzy matching
* Case-insensitive matching

Search results prioritized by:

1. Exact match
2. Partial match
3. Popularity (rating count or reaction count)

Note: Basic functional search must ship with core utility (Phase 1), not deferred to later optimization phases.

---

### 3.2 Favorites Filtering

Favorites screen must support:

* Filter by reaction level
* Filter by restaurant
* Sorting by most recent
* Sorting by highest reaction weight

---

## 4. Duplicate Detection & Merge Logic

When adding restaurant:

* Check existing restaurants within geo radius
* Perform name similarity match

If duplicate detected:

* Present "View Existing" vs "Create Anyway" options
* Admin can force merge

Merge behavior:

* Combine ratings
* Combine dishes
* Preserve creator history
* Recalculate aggregates

---

## 5. Public Image Moderation

Image Rules:

* User chooses public/private at upload
* Public images visible to all
* Private images accessible only to uploader via signed URLs

Moderation:

* Users can report image
* Admin review queue
* Automated basic filtering (optional future)

Storage:

* Image size limit enforced
* CDN delivery via S3-compatible object storage

---

## 6. Data Contribution Integrity

Constraints:

* One reaction per user per dish (overwriteable)
* One restaurant rating per user (editable)
* Attribute voting optional and overwriteable

Anti-abuse:

* Rate limiting per user
* Admin moderation tools
* Community reporting mechanism

---

## 7. Minimum Data Threshold for AI Predictions

Compatibility predictions displayed only when both conditions are met:

* User has ≥ 10 personal reactions to dishes with overlapping attributes
* Dish has ≥ 10 community votes (attribute confidence stable)

Below either threshold → no prediction shown. Never display an uncertain AI guess.

Threshold progression path:

* Onboarding taste bootstrapping counts toward user's 10-reaction threshold
* "Taste Profile Completion" indicator on Profile screen shows progress toward first prediction
* Thresholds may be tuned post-launch based on observed data density — start at 10, loosen to 5 if warranted

---

## 8. Free Tier Definition

The free tier is gated by intelligence access, not by data quantity. Users may use Remembite without limits on tracking, then discover the insights behind their data require Pro.

| Feature | Free | Pro |
|---|---|---|
| Dish reactions (unlimited) | ✓ | ✓ |
| Restaurant tracking (unlimited) | ✓ | ✓ |
| Private notes | ✓ | ✓ |
| Menu OCR | ✓ | ✓ |
| Visit timeline | ✓ | ✓ |
| Community reactions & favorites | ✓ | ✓ |
| Community dish attributes | ✓ | ✓ |
| AI taste compatibility predictions | — | ✓ |
| Advanced taste insights | — | ✓ |
| Cloud sync (cross-device) | — | ✓ |
| Data export | — | ✓ |

No hard cap on dish count. Free users build rich history; upgrading reveals the intelligence behind it.

Free-to-Pro conversion trigger: User sees "Taste Profile Complete" on Profile, clicks taste insights → paywall. This is the natural upgrade moment.

---

## 9. Payment Infrastructure Requirements

Must support:

* Indian payment stack: Razorpay or equivalent (UPI, cards, netbanking)
* Monthly subscription at ₹49/month
* Annual subscription at ₹399/year
* In-app subscription management (upgrade, downgrade, cancel)
* Graceful degradation on cancellation (data retained, Pro features locked)
* Webhook handling for payment events
* Pro feature flag enforcement at API layer

Note: Payment infrastructure must be implemented before AI predictions ship, so the upgrade moment exists when users first see predictions gated.

---

End of PRD
