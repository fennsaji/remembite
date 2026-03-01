# Remembite – Financial Projections

---

## 1. Disclaimer

These projections are planning assumptions, not forecasts. They exist to stress-test the business model, identify what must be true for the product to be viable, and set meaningful milestone targets. Revise them as real data replaces assumptions.

---

## 2. Key Assumptions

| Assumption | Value | Basis |
|---|---|---|
| Launch city | Bengaluru or Delhi NCR | High dining frequency, tech-forward user base |
| Primary target | Frequent restaurant-goers, 2–3× per week | Product requires enough visits to build taste vector |
| Pricing (monthly) | ₹49/month | Chosen |
| Pricing (annual) | ₹399/year | ~₹33/month equivalent, 32% discount |
| Annual/monthly mix | 60% annual, 40% monthly | Annual pushed as recommended default |
| Free-to-Pro conversion | 4% of active users | Conservative; typical freemium consumer apps: 2–5% |
| Monthly churn (monthly plan) | 8% | High; ₹49 is low-commitment |
| Annual churn (at renewal) | 25% | Users who lapsed during the year don't renew |
| Organic growth rate | Primary channel at launch | Referrals, word of mouth, App Store discovery |
| User acquisition cost (organic) | ~₹0 | No paid acquisition in Year 1 |
| User acquisition cost (paid) | ₹75–150 per install | If/when paid channels are added |

---

## 3. Revenue Per User

All LTV figures are **net** (after 15% Google Play / Apple App Store fee).

### Monthly Plan
* Gross: ₹49/month → Net: ₹41.65/month
* Average retention: ~10 months (before churn at 8%/month)
* Net LTV: ₹41.65 × 10 = **~₹416**

### Annual Plan
* Gross: ₹399/year → Net: ₹339.15/year
* Renewal rate: 75% (25% churn at renewal)
* Net LTV (Year 1 + renewal): ₹339.15 + 0.75 × ₹339.15 = **~₹594**

### Blended LTV (60% annual, 40% monthly)
* Net blended LTV: 0.6 × ₹594 + 0.4 × ₹416 = **~₹523 per paying user**

---

## 4. Monthly Recurring Revenue Model

MRR from monthly subscribers + annualized ARR from annual subscribers.

For simplicity, annual plan revenue is recognized monthly (₹399 / 12 = ₹33/month per annual subscriber).

```
MRR = (monthly_subs × ₹49) + (annual_subs × ₹33)
```

---

## 5. Growth Projections

All figures are **gross revenue** (what users pay before 15% platform fee). Net revenue = gross × 0.85.

### Early Access — Closed Beta (Months 1–2)
Goal: Test core habit loop with real users. No revenue.

| Metric | Target |
|---|---|
| Test users | 20–50 |
| Paying users | 0 |
| MRR | ₹0 |

---

### Soft Launch — Pro Tier Live (Months 3–4)
Full product live — all features including AI predictions shipped before public launch.

| Metric | Conservative | Base | Optimistic |
|---|---|---|---|
| Total users | 200 | 400 | 800 |
| Active users (≥1 visit/month) | 100 | 200 | 400 |
| Pro subscribers (4%) | 4 | 8 | 16 |
| MRR (gross) | ₹200 | ₹400 | ₹800 |

---

### Growth Phase (Months 5–6)
Word of mouth and App Store discovery begin driving organic growth.

| Metric | Conservative | Base | Optimistic |
|---|---|---|---|
| Total users | 800 | 2,000 | 5,000 |
| Active users | 400 | 1,000 | 2,500 |
| Pro subscribers (4%) | 16 | 40 | 100 |
| MRR (gross) | ₹800 | ₹2,000 | ₹5,000 |

---

### Month 12 — End of Year 1

Assumes word-of-mouth growth in launch city, App Store presence, no paid acquisition.

| Metric | Conservative | Base | Optimistic |
|---|---|---|---|
| Total registered users | 5,000 | 15,000 | 40,000 |
| Monthly active users | 2,000 | 6,000 | 16,000 |
| Pro subscribers (4% of MAU) | 80 | 240 | 640 |
| Monthly subscribers (40%) | 32 | 96 | 256 |
| Annual subscribers (60%) | 48 | 144 | 384 |
| MRR | ₹3,200 | ₹9,600 | ₹25,600 |
| ARR | ₹38,400 | ₹1,15,200 | ₹3,07,200 |

---

### Month 24 — End of Year 2

Assumes expansion to 2–3 cities, some paid acquisition, growing word of mouth.

| Metric | Conservative | Base | Optimistic |
|---|---|---|---|
| Monthly active users | 10,000 | 40,000 | 1,00,000 |
| Pro subscribers (5% of MAU) | 500 | 2,000 | 5,000 |
| MRR | ₹20,000 | ₹80,000 | ₹2,00,000 |
| ARR | ₹2,40,000 | ₹9,60,000 | ₹24,00,000 |
| ARR (USD approx.) | ~$2,850 | ~$11,400 | ~$28,500 |

---

## 6. Break-Even Analysis

Infrastructure costs at MVP scale are low (single VPS, object storage, LLM API calls).

### Estimated Monthly Operating Costs

| Cost Item | Monthly Estimate |
|---|---|
| Hetzner VPS (Rust backend + Nginx) | ₹340–400 (~€3.79/mo) |
| Neon PostgreSQL | ₹0 (free tier through early scale; ~₹1,350/mo on Launch plan if needed) |
| Cloudflare R2 (images, CDN) | ₹0 (free tier: 10GB, zero egress) |
| LLM API — Gemini 2.0 Flash | ₹0 (free tier covers early scale; ~₹0.01–0.03/dish beyond) |
| Google Play Store fee (15% of revenue) | Variable — deducted from gross revenue |
| Total infrastructure costs | ~₹340–500/month at MVP scale |

### Platform Fee Impact on Revenue

Google Play and Apple App Store take 15% of all subscription revenue. All revenue figures below are **net** (after platform fees).

| Plan | Gross | Net (after 15%) |
|---|---|---|
| Monthly ₹49 | ₹49 | ₹41.65 |
| Annual ₹399/year (₹33/mo equiv.) | ₹33 | ₹28.05 |

### Break-Even MRR

At ₹500/month infrastructure cost:

```
Break-even = ₹500 / net blended revenue per subscriber per month
Net blended monthly revenue per Pro user = 0.6 × ₹28.05 + 0.4 × ₹41.65 = ₹33.49
Break-even subscribers = ₹500 / ₹33.49 ≈ 15 Pro subscribers
```

**15 paying Pro users covers infrastructure costs.** (Infrastructure is extremely lean at MVP scale.)

At 4% conversion, this requires ~375 monthly active users — achievable in closed beta.

Note: The platform fee (15%) is a revenue share, not a fixed cost — it scales proportionally with revenue and does not affect break-even at the infrastructure level.

---

## 7. What Must Be True (Sensitivity Analysis)

The model is sensitive to two variables more than any other: **MAU growth** and **conversion rate**.

All MRR figures are **net** (after 15% platform fee). Net blended revenue per Pro subscriber = ₹33.49/month.

### Conversion Rate Sensitivity (at 10,000 MAU)

| Conversion Rate | Pro Subscribers | Net MRR |
|---|---|---|
| 2% | 200 | ₹6,698 |
| 4% | 400 | ₹13,396 |
| 6% | 600 | ₹20,094 |
| 8% | 800 | ₹26,792 |

If conversion stays below 2%, revisit upgrade trigger design before scaling user acquisition.

### MAU Sensitivity (at 4% conversion)

| MAU | Pro Subscribers | Net MRR |
|---|---|---|
| 2,000 | 80 | ₹2,679 |
| 5,000 | 200 | ₹6,698 |
| 10,000 | 400 | ₹13,396 |
| 25,000 | 1,000 | ₹33,490 |
| 50,000 | 2,000 | ₹66,980 |
| 75,000 | 3,000 | ₹1,00,470 |

Meaningful net monthly revenue (₹1L+) requires ~75,000 MAU at 4% conversion and current pricing. This is a Year 2–3 growth target for a multi-city presence.

---

## 8. LLM Cost Monitoring

LLM classification cost is negligible with Gemini 2.0 Flash (~₹0.02/dish).

| Scale | New dishes/month (est.) | LLM cost @ ₹0.02/dish |
|---|---|---|
| 1,000 MAU | ~500 new dishes | ~₹10/month |
| 10,000 MAU | ~3,000 new dishes | ~₹60/month |
| 1,00,000 MAU | ~20,000 new dishes | ~₹400/month |

LLM costs are not a concern at any practical scale. Free tier covers the first several thousand classifications.

Caching: dishes are classified once and reused. LLM cost does not scale with reactions, only with new dish additions.

---

## 9. Key Milestones

| Milestone | Target | Signal |
|---|---|---|
| First paying subscriber | Month 3 | Payment stack works |
| Break-even (infrastructure costs) | Early — ~15 Pro subscribers | Infrastructure is lean (~₹500/mo) |
| ₹1L net MRR | Year 2–3 | ~3,000 Pro subscribers / ~75,000 MAU |
| ₹10L net MRR | Year 3+ | ~30,000 Pro subscribers / ~750,000 MAU |

₹10L net MRR requires ~750,000 MAU at 4% conversion and current pricing — requires either significant national scale or a price increase. A move to ₹99/month in Year 2 cuts the MAU requirement by roughly half.

---

## 10. When to Revisit Pricing

Review ₹49/month pricing if:

* Conversion rate exceeds 8% (demand signal — the product is priced below willingness to pay)
* Annual plan mix falls below 40% (users treating Pro as low-commitment monthly, churn will be high)
* CAC rises above ₹170 (net blended LTV of ₹523 gives ~3× payback at ₹170 CAC, which is acceptable but thin)
* Infrastructure costs scale significantly (currently ~₹500/mo; at ₹50,000/mo scale requires ~1,493 net subscribers to cover)

A move to ₹79 or ₹99/month in Year 2 roughly doubles revenue per subscriber without requiring growth in user base.

---

End of Financial Projections
