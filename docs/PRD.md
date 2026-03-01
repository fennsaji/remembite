# Remembite – Complete Wireframes (Aligned with PRD)

---

## 1. Onboarding

---

| Remembite Logo                                 |
| "Remember What You Loved."                    |
|                                                |
| [ Get Started ]                                |
| [ Continue with Google ]                       |
--------------------------------------------------

---

## 2. Home Screen (Decision Optimized)

---

| Search Restaurants...                            |     |           |         |
| ------------------------------------------------ | --- | --------- | ------- |
| 📍 Nearby Restaurants                            |     |           |         |
| • Barbeque Nation ⭐4.3                           |     |           |         |
| • Cafe Delhi Heights ⭐4.0                        |     |           |         |
| ------------------------------------------------ |     |           |         |
| 🕘 Recently Visited                              |     |           |         |
| • Barbeque Nation                                |     |           |         |
| ------------------------------------------------ |     |           |         |
| [ Scan Menu ]                                    |     |           |         |
| (Primary Floating Action Button)                 |     |           |         |
| ------------------------------------------------ |     |           |         |
| Bottom Navigation                                |     |           |         |
| Home                                             | Map | Favorites | Profile |

---

Manual Add Restaurant available via Search → "Add New"

---

## 3. Add Restaurant Screen

---

| Add Restaurant                      |
| ----------------------------------- |
| Restaurant Name: [______________]   |
| Location: [ Auto Detect / Edit ]    |
| Cuisine Type: [ Optional Dropdown ] |
|                                     |
| [ Save ]                            |

---

System:

* Checks duplicates (name + geo proximity)
* Creator becomes temporary editor

---

## 4. Scan Menu (OCR Flow)

---

| Scan Menu             |
| --------------------- |
| [ Camera Viewfinder ] |
|                       |
| Tap to Capture        |

---

After Capture:

---

| Extracted Dishes (Editable)                    |
|  ☑ Butter Chicken                              |
|  ☑ Paneer Lababdar                             |
|  ☑ Dal Makhani                                 |
|                                                |
| [ Edit Text ]  [ Remove ]                      |
|                                                |
| [ Save Dishes ]                                |
--------------------------------------------------

Backend:

* Async AI classification triggered per dish

---

## 5. Restaurant Super Screen

---

| Restaurant Name                                |
| ⭐ 4.3 (124 ratings)                           |

| [ Rate ]   [ Suggest Edit ]                      |
| ------------------------------------------------ |
| 🔥 Your Top Bites                                |
| • Butter Chicken 🔥                              |
| • Paneer Lababdar 😋                             |
| ------------------------------------------------ |
| 🌍 Community Favorites                           |
| • Butter Chicken (🔥 124)                        |
| • Dal Makhani (🔥 98)                            |
| ------------------------------------------------ |
| Full Menu (Collapsed)                            |
| • Dal Makhani   🔥 😋 🙂 😐 🤢                   |
| • Kadhai Paneer 🔥 😋 🙂 😐 🤢                   |
| [ View All ]                                     |
| ------------------------------------------------ |
| "3 community updates pending" (subtle link)      |

---

---

## 6. One-Tap Dish Reaction

Inline under each dish:

🔥 😋 🙂 😐 🤢

Tap → Instant save (<200ms local)
Background sync to backend

Long Press → Dish Detail

---

## 7. Dish Detail Screen

---

| Dish Name                                |
| ---------------------------------------- |
| Your Reaction: 🔥 So Yummy               |
|                                          |
| Notes (Private):                         |
| [ ____________________________ ]         |
|                                          |
| Add Photo: [ + ]                         |
| ( ) Make Image Public                    |
|                                          |
| Optional Attribute Vote:                 |
| How spicy was it?                        |
| 🌶 Mild  🌶🌶 Medium  🌶🌶🌶 Hot  [Skip] |
|                                          |
| How sweet was it?                        |
| 🍬 Low  🍬🍬 Medium  🍬🍬🍬 High  [Skip] |
|                                          |
| [ Save Changes ]                         |

---

---

## 8. Passive Restaurant Rating (Bottom Sheet)

After 2+ dish reactions:

---

| How was the overall experience? |
| ⭐ ⭐ ⭐ ⭐ ⭐                      |
| [ Submit ]                      |
-----------------------------------

One rating per user. Editable.

---

## 9. Suggest Edit (Modal)

---

| Suggest Change                       |
| ------------------------------------ |
| Field: [ Name / Location / Cuisine ] |
| Proposed Change: [_____________]     |
|                                      |
| [ Submit Suggestion ]                |

---

---

## 10. Pending Edits (Community Governance)

---

| Pending Community Edits                     |
| ------------------------------------------- |
| "Cafe Dehli Heights" → "Cafe Delhi Heights" |
| 👍 2 Approvals                              |
| [ Approve ]                                 |

---

If approvals ≥ N → Auto Apply
Admin override available

---

## 11. Map View

---

| Map View                            |
| ----------------------------------- |
| Default: Visited Restaurants Only   |
| [ Toggle: Show Nearby Restaurants ] |
|                                     |
| Tap Pin → Restaurant Super Screen   |

---

---

## 12. Favorites Screen

---

| Favorite Dishes                                  |
| ------------------------------------------------ |
| • Butter Chicken 🔥                              |
| • Tiramisu 🔥                                    |
| ------------------------------------------------ |
| Filter: [ By Reaction ] [ By Restaurant ]        |

---

---

## 13. Profile Screen

---

| Profile                                          |
| ------------------------------------------------ |
| Total Restaurants Visited: 24                    |
| Total Dishes Tracked: 86                         |
| Most Used Reaction: 🔥 So Yummy                  |
| ------------------------------------------------ |
| Taste Insights (Pro)                             |
| • Prefers Spicy Food                             |
| • Often dislikes very sweet dishes               |
| ------------------------------------------------ |
| [ Upgrade to Pro ]                               |
| [ Settings ]                                     |

---

---

## 14. Upgrade Screen (Paywall)

---

| Unlock Pro                |
| ------------------------- |
| ✓ Unlimited Dish Tracking |
| ✓ AI Taste Predictions    |
| ✓ Cloud Sync              |
| ✓ Advanced Insights       |
|                           |
| ₹49 / month               |
|                           |
| [ Subscribe Now ]         |

---

---

## 15. Backend Intelligence (Not Visible in UI)

* AI dish classification runs asynchronously
* LLM outputs structured attribute JSON
* Hybrid Bayesian smoothing applied
* Community votes override AI over time
* Compatibility scoring shown only to Pro users

---

End of Complete Wireframes

---

# 13. UI Screen Coverage (Aligned with Wireframes)

This section ensures all wireframe screens are formally defined in the PRD.

## 13.1 Home Screen

Components:

* Search bar
* Nearby Restaurants list (with star rating)
* Recently Visited list
* Floating Action Button: Scan Menu
* Bottom Navigation: Home | Map | Favorites | Profile

Behavior:

* Auto-detect nearby restaurants via GPS
* Manual "Add New" option inside search

---

## 13.2 Restaurant Super Screen

Sections (in order):

1. Header (Name + Star Rating + Rate + Suggest Edit)
2. "Your Top Bites" (sorted by user reactions)
3. "Community Favorites" (sorted by weighted reactions)
4. Full Menu (collapsed by default, first 5 visible)
5. Subtle "Pending Community Updates" link

---

## 13.3 Dish Detail Screen

Must support:

* Display selected reaction
* Private notes input
* Image upload with public/private toggle
* Optional spice intensity voting
* Optional sweetness intensity voting
* Save changes

---

## 13.4 Passive Restaurant Rating Bottom Sheet

Trigger:

* After 2+ dish reactions in same session

Must support:

* 1–5 star selection
* One rating per user (editable)

---

## 13.5 Suggest Edit Flow

Modal includes:

* Select editable field (Name / Location / Cuisine)
* Proposed value input
* Submit button

Pending Edits View:

* Proposed change display
* Approval count
* Approve button
* Auto-apply if approvals ≥ N

---

## 13.6 Map View

Default:

* Display only visited restaurants

Toggle:

* Show nearby restaurants

Pin interaction:

* Opens Restaurant Super Screen

---

## 13.7 Favorites Screen

Must support:

* List of favorited dishes
* Filter by reaction
* Filter by restaurant

---

## 13.8 Profile Screen

Must display:

* Total restaurants visited
* Total dishes tracked
* Most used reaction

Pro Section:

* Taste insights summary
* Upgrade to Pro button

---

## 13.9 Upgrade Screen

Must display:

* Unlimited dish tracking
* AI taste predictions
* Cloud sync
* Advanced insights
* Monthly pricing
* Subscribe button

---

All screens above are mandatory functional coverage for MVP + AI-enhanced roadmap.

---

---

# 14. Ranking & Display Logic (Implementation-Specific)

## 14.1 Dish Reaction Weight Mapping

Reactions are internally mapped to numeric weights:

* 🔥 So Yummy = 5
* 😋 Tasty = 4
* 🙂 Pretty Good = 3
* 😐 Meh = 2
* 🤢 Never Again = 1

## 14.2 Community Dish Ranking

Public dish ranking score:

weighted_score = (5*yummy + 4*tasty + 3*pretty_good + 2*meh + 1*never_again) / total_votes

Optional enhancement:

* Apply minimum vote threshold (e.g., 5 votes) before surfacing in “Community Favorites”
* Below threshold → mark as “New”

## 14.3 Your Top Bites Sorting

Sorted by:

1. Highest reaction weight
2. Most recent reaction (tie-breaker)

No time decay in MVP.

---

# 15. Search & Filtering Specifications

## 15.1 Search Scope

Search must support:

* Restaurant name search
* Dish name search
* Fuzzy matching
* Case-insensitive matching

Search results prioritized by:

1. Exact match
2. Partial match
3. Popularity (rating count or reaction count)

## 15.2 Favorites Filtering

Favorites screen must support:

* Filter by reaction level
* Filter by restaurant
* Sorting by most recent
* Sorting by highest reaction weight

---

# 16. Duplicate Detection & Merge Logic

When adding restaurant:

* Check existing restaurants within geo radius
* Perform name similarity match

If duplicate detected:

* Suggest merge
* Admin can force merge

Merge behavior:

* Combine ratings
* Combine dishes
* Preserve creator history
* Recalculate aggregates

---

# 17. Public Image Moderation

Image Rules:

* User chooses public/private at upload
* Public images visible to all
* Private images visible only to uploader

Moderation:

* Users can report image
* Admin review queue
* Automated basic filtering (optional future)

Storage:

* Image size limit enforced
* CDN storage recommended

---

# 18. Data Contribution Integrity

Constraints:

* One reaction per user per dish
* One restaurant rating per user
* Attribute voting optional and overwriteable

Anti-abuse:

* Rate limiting per user
* Admin moderation tools
* Community reporting mechanism

---

# 19. Minimum Data Threshold for AI Predictions

Compatibility predictions displayed only when:

* Dish has minimum attribute confidence
* User has minimum reaction history (e.g., ≥ 10 reactions)

Below threshold → no prediction shown.

---

End of Complete PRD
