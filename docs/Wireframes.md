# Remembite – App Wireframes (Full Intelligent System Aligned)

---

## Rating Systems

### Dish Reactions (Emotional)

🔥 So Yummy
😋 Tasty
🙂 Pretty Good
😐 Meh
🤢 Never Again

### Restaurant Rating (Separate)

⭐ 1–5 Stars (Public average + count)

---

## 1. Onboarding Screen

---

| Remembite Logo                                 |
| "Remember What You Loved."                    |
|                                                |
| [ Get Started ]                                |
| [ Continue with Google ]                       |
--------------------------------------------------

---

### After Sign-In: Taste Bootstrapping (Optional)

---

| Quick — let us learn your taste               |
| (Takes about 30 seconds. You can skip.)       |
|                                               |
| Butter Chicken                                |
| 🔥  😋  🙂  😐  🤢  [ Skip ]                  |
|                                               |
| Biryani                                       |
| 🔥  😋  🙂  😐  🤢  [ Skip ]                  |
|                                               |
| Tiramisu                                      |
| 🔥  😋  🙂  😐  🤢  [ Skip ]                  |
|                                               |
| ... (10–15 common dishes across cuisines)     |
|                                               |
| [ Done ]         [ Skip All ]                 |
-------------------------------------------------

Note: Bootstrapping reactions count toward ≥10 personal reaction threshold for AI predictions. Skipping is always visible and never blocked.

---

## 2. Home Screen (Decision-Optimized)

---

| Search Restaurants / Dishes...                   |     |           |         |
| ------------------------------------------------ | --- | --------- | ------- |
| 🕘 Recently Visited                              |     |           |         |
| • Barbeque Nation                                |     |           |         |
| ------------------------------------------------ |     |           |         |
| 📍 Nearby Restaurants                            |     |           |         |
| • Barbeque Nation ⭐4.3                           |     |           |         |
| • Cafe Delhi Heights ⭐4.0                        |     |           |         |
| ------------------------------------------------ |     |           |         |
| [ Scan Menu ]                                    |     |           |         |
| (Floating Action Button — secondary action)      |     |           |         |
| ------------------------------------------------ |     |           |         |
| Bottom Navigation                                |     |           |         |
| Home                                             | Map | Favorites | Profile |

---

Recently Visited is surfaced first — returning users act on existing context, not OCR.
Scan Menu FAB is available but not the primary CTA.
Search includes fuzzy matching across restaurants & dishes.

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

## If potential duplicate detected:

| Similar restaurant found nearby                |
| [ View Existing ] [ Create Anyway ]           |
-------------------------------------------------

---

## 4. Restaurant Super Screen

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

Community favorites require minimum vote threshold.

---

## 5. Passive Restaurant Rating (Bottom Sheet)

Triggered after 2+ dish reactions.

---

| How was the overall experience? |
| ⭐ ⭐ ⭐ ⭐ ⭐                      |
| [ Submit ]                      |
-----------------------------------

One rating per user (editable).

---

## 6. Menu Scan (OCR Flow)

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

Backend triggers async AI classification.
Saved dishes immediately visible with "Classifying..." attribute state until LLM job completes.

---

## 7. Dish Detail Screen (Intelligence-Enhanced)

---

| Dish Name                                        |
| ------------------------------------------------ |
| Your Reaction: 🔥 So Yummy                       |
|                                                  |
| [Classifying...] (shown while LLM job pending)  |
| 🔥 You'll probably love this                     |
| (Shown only if confidence threshold met — Pro)  |
| ------------------------------------------------ |
| Notes (Private)                                  |
| [ ____________________________ ]                 |
|                                                  |
| Add Photo: [ + ]                                 |
| ( ) Make Image Public                            |
|                                                  |
| Optional Attribute Voting                        |
| How spicy was it?                                |
| 🌶 Mild  🌶🌶 Medium  🌶🌶🌶 Hot  [Skip]         |
|                                                  |
| How sweet was it?                                |
| 🍬 Low  🍬🍬 Medium  🍬🍬🍬 High  [Skip]         |
|                                                  |
| [ Save Changes ]                                 |

---

---

## 8. Suggest Edit Modal

---

| Suggest Change                       |
| ------------------------------------ |
| Field: [ Name / Location / Cuisine ] |
| Proposed Change: [_____________]     |
|                                      |
| [ Submit Suggestion ]                |

---

---

## 9. Pending Community Edits

---

| Pending Edits                               |
| ------------------------------------------- |
| "Cafe Dehli Heights" → "Cafe Delhi Heights" |
| 👍 2 Approvals                              |
| [ Approve ]                                 |

---

Auto-apply when net upvotes ≥ 3 within 7 days. Edit expires if no consensus.
In early stages, admin manually reviews and applies edits.

---

## 10. Favorites Screen

---

| Favorite Dishes                                  |
| ------------------------------------------------ |
| • Butter Chicken 🔥                              |
| • Tiramisu 🔥                                    |
| ------------------------------------------------ |
| Filter: [ By Reaction ] [ By Restaurant ]        |
| Sort: [ Most Recent ] [ Highest Rated ]          |

---

---

## 11. Map View Screen

---

| Map View                            |
| ----------------------------------- |
| Default: Visited Restaurants Only   |
| [ Toggle: Show Nearby Restaurants ] |
|                                     |
| Tap Pin → Restaurant Super Screen   |

---

---

## 12. Visit Timeline Screen

---

| Visit Timeline                                   |
| ------------------------------------------------ |
| Jan 2026 – Cafe Delhi Heights                    |
| • Tiramisu  • 🔥 So Yummy                        |
| ------------------------------------------------ |
| Dec 2025 – Barbeque Nation                       |
| • Butter Chicken • 🔥 So Yummy                   |

---

Private to user.

---

## 13. Search Results Screen

---

| Search Results                                   |
| ------------------------------------------------ |
| Restaurants                                      |
| • Barbeque Nation ⭐4.3                           |
|                                                  |
| Dishes                                           |
| • Butter Chicken – 3 Restaurants                 |
| ------------------------------------------------ |

Results prioritized by:

1. Exact match
2. Partial match
3. Popularity

---

## 14. Profile Screen

---

| Profile                                          |
| ------------------------------------------------ |
| Total Restaurants Visited: 24                    |
| Total Dishes Tracked: 86                         |
| Most Used Reaction: 🔥 So Yummy                  |
| ------------------------------------------------ |
| Your Taste Profile                               |
| ████████░░  80% complete                         |
| "React to 2 more dishes to unlock predictions"  |
| ------------------------------------------------ |
| Taste Insights (Pro)                             |
| • Prefers spicy food                             |
| • Frequently dislikes very sweet dishes          |
| [ Unlock Taste Insights → ]                      |
| ------------------------------------------------ |
| [ Upgrade to Pro ]                               |
| [ Settings ]                                     |

---

Taste vector is private.
"Taste Profile" progress bar drives organic upgrade pressure without artificial dish caps.
Clicking "Unlock Taste Insights →" takes user to Upgrade Screen.

---

## 15. Settings Screen

---

| Settings         |
| ---------------- |
| Account          |
| Cloud Sync       |
| Export Data      |
| Subscription     |
| Privacy Controls |
| Help & Support   |

---

---

## 16. Upgrade Screen (Pro Intelligence)

Feature order leads with the primary value driver. Annual plan is highlighted as recommended.

---

| Unlock Pro                              |
| --------------------------------------- |
| ✓ AI Taste Compatibility Predictions   |
| ✓ Advanced Taste Insights              |
| ✓ Cloud Sync (cross-device)            |
| ✓ Unlimited Dish Tracking              |
|                                         |
| ₹399 / year   ← Recommended (save 32%) |
| ₹49 / month                            |
|                                         |
| [ Subscribe Now ]                       |

---

---

End of Wireframes
