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

### Monthly Plan
* Price: ₹49/month
* Average retention: ~10 months (before churn at 8%/month)
* LTV: ₹49 × 10 = **~₹490**

### Annual Plan
* Price: ₹399/year
* Renewal rate: 75% (25% churn at renewal)
* LTV (Year 1 + renewal): ₹399 + 0.75 × ₹399 = **~₹699**

### Blended LTV (60% annual, 40% monthly)
* Blended LTV: 0.6 × ₹699 + 0.4 × ₹490 = **~₹615 per paying user**

---

## 4. Monthly Recurring Revenue Model

MRR from monthly subscribers + annualized ARR from annual subscribers.

For simplicity, annual plan revenue is recognized monthly (₹399 / 12 = ₹33/month per annual subscriber).

```
MRR = (monthly_subs × ₹49) + (annual_subs × ₹33)
```

---

## 5. Growth Projections by Phase

### Phase 1 — Closed Beta (Months 1–2)
Goal: Validate habit loop. No revenue.

| Metric | Target |
|---|---|
| Test users | 20–50 |
| Paying users | 0 |
| MRR | ₹0 |
| Key question | Do users return within 7 days? |

---

### Phase 2 — Soft Launch with Pro Tier (Months 3–4)
Pro tier live. AI predictions not yet available — cloud sync and early access position the upgrade.

| Metric | Conservative | Base | Optimistic |
|---|---|---|---|
| Total users | 200 | 400 | 800 |
| Active users (≥1 visit/month) | 100 | 200 | 400 |
| Pro subscribers (4%) | 4 | 8 | 16 |
| MRR | ₹200 | ₹400 | ₹800 |

---

### Phase 3 — AI Layer Live (Months 5–6)
AI taste predictions unlock. This is the first genuine upgrade moment.

| Metric | Conservative | Base | Optimistic |
|---|---|---|---|
| Total users | 800 | 2,000 | 5,000 |
| Active users | 400 | 1,000 | 2,500 |
| Pro subscribers (4%) | 16 | 40 | 100 |
| MRR | ₹800 | ₹2,000 | ₹5,000 |

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
| VPS (Rust backend + PostgreSQL) | ₹2,000–5,000 |
| Object storage (images, CDN) | ₹500–2,000 |
| LLM API (per dish classified) | ₹0.05–0.10 per dish; ~₹500–2,000/month at early scale |
| Payment gateway fees (Razorpay ~2%) | Variable |
| Total operating costs | ~₹3,000–9,000/month |

### Break-Even MRR

At ₹6,000/month operating cost midpoint:

```
Break-even = ₹6,000 / blended revenue per subscriber per month
Blended monthly revenue per Pro user = 0.6 × ₹33 + 0.4 × ₹49 = ₹39.40
Break-even subscribers = ₹6,000 / ₹39.40 ≈ 152 Pro subscribers
```

**152 paying Pro users covers operating costs.**

At 4% conversion, this requires ~3,800 monthly active users.

This is a realistic Year 1 milestone for a focused single-city launch.

---

## 7. What Must Be True (Sensitivity Analysis)

The model is sensitive to two variables more than any other: **MAU growth** and **conversion rate**.

### Conversion Rate Sensitivity (at 10,000 MAU)

| Conversion Rate | Pro Subscribers | MRR |
|---|---|---|
| 2% | 200 | ₹7,880 |
| 4% | 400 | ₹15,760 |
| 6% | 600 | ₹23,640 |
| 8% | 800 | ₹31,520 |

If conversion stays below 2%, revisit upgrade trigger design before scaling user acquisition.

### MAU Sensitivity (at 4% conversion)

| MAU | Pro Subscribers | MRR |
|---|---|---|
| 2,000 | 80 | ₹3,152 |
| 5,000 | 200 | ₹7,880 |
| 10,000 | 400 | ₹15,760 |
| 25,000 | 1,000 | ₹39,400 |
| 50,000 | 2,000 | ₹78,800 |

Meaningful monthly revenue (₹1L+) requires ~25,000 MAU at current pricing. That is a significant but achievable growth target for Year 2 in a metro with strong dining culture.

---

## 8. LLM Cost Monitoring

LLM classification is the main variable cost that could surprise.

| Scale | New dishes/month (est.) | LLM cost @ ₹0.10/dish |
|---|---|---|
| 1,000 MAU | ~500 new dishes | ₹50/month |
| 10,000 MAU | ~3,000 new dishes | ₹300/month |
| 1,00,000 MAU | ~20,000 new dishes | ₹2,000/month |

LLM costs are not a concern at early scale. Monitor at 50,000+ MAU.

Caching: dishes are classified once and reused. LLM cost does not scale with reactions, only with new dish additions.

---

## 9. Key Milestones

| Milestone | Target | Signal |
|---|---|---|
| First paying subscriber | Month 3 | Payment stack works |
| Break-even (ops costs) | Month 10–14 | ~152 Pro subscribers |
| ₹1L MRR | Year 2 | ~2,500 Pro subscribers |
| ₹10L MRR | Year 3+ | ~25,000 Pro subscribers |

₹10L MRR is a meaningful scale target. At current pricing it requires either a very large user base (250,000+ MAU at 4% conversion) or a price increase in Year 2.

---

## 10. When to Revisit Pricing

Review ₹49/month pricing if:

* Conversion rate exceeds 8% (demand signal — the product is priced below willingness to pay)
* Annual plan mix falls below 40% (users treating Pro as low-commitment monthly, churn will be high)
* CAC rises above ₹200 (blended LTV of ₹615 gives ~3× payback at ₹200 CAC, which is acceptable but thin)
* Operating costs exceed ₹50,000/month (requires ~1,270 Pro subscribers to cover at current pricing)

A move to ₹79 or ₹99/month in Year 2 roughly doubles revenue per subscriber without requiring growth in user base.

---

End of Financial Projections
