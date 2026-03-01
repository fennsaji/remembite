# Remembite – Product Requirements Document (PRD)

---

## 1. UI Screen Coverage

All screens below are mandatory functional coverage for MVP + AI-enhanced roadmap.

### 1.1 Home Screen

Components:

* Search bar (fuzzy match across restaurants & dishes)
* Nearby Restaurants list (with star rating)
* Recently Visited list
* Floating Action Button: Scan Menu
* Bottom Navigation: Home | Map | Favorites | Profile

Behavior:

* Auto-detect nearby restaurants via GPS
* Manual "Add New" option inside search

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

Pro Section:

* Taste insights summary
* Upgrade to Pro button

---

### 1.9 Upgrade Screen

Must display:

* Unlimited dish tracking
* AI taste predictions
* Cloud sync
* Advanced insights
* Monthly pricing (₹49/month)
* Subscribe button

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

---

End of PRD
