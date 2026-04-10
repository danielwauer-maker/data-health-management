# BCSentinel Pricing (Sales-ready draft)

## Positioning
BCSentinel is sold as a Business Central data quality and business impact platform with two clear plans:
- **Free** for trust-building and initial diagnosis
- **Premium** for execution and measurable improvement

## Plan structure

### Free
- Price: **EUR 0 / month**
- Includes:
  - Full scan baseline
  - Data Health Score
  - Issue category overview and counts
  - Monetized impact visibility (loss/savings estimate)
- Best fit:
  - New users evaluating business relevance
  - Teams preparing internal business case for rollout

### Premium
- Price model: **base monthly fee + usage step**
- Includes everything in Free, plus:
  - Record-level issue details
  - Prioritized recommendations
  - Action-oriented workflow in BC
  - Partner-enabled rollout support
- Best fit:
  - Teams actively fixing master/process data quality
  - Multi-tenant partners serving BC customers

## Operational source of truth
For implemented list prices, defaults, DB seeding, and landing snapshots, see **`docs/product/pricing-canonical.md`** and **`config/pricing_canonical.json`**.

## Price governance
- Billing cadence: monthly
- Currency default: EUR
- Cancellation: end of current billing period
- Invoices: generated and tracked via Stripe webhook lifecycle

## Partner economics
- Standard referral commission: **30%** on qualified Premium subscription revenue
- Partner payout flow:
  - commission status: `pending -> approved -> paid`
  - payout overview by partner and currency in Admin UI

## Conversion copy recommendations
- Hero CTA: **Start free ERP health scan**
- Mid-page CTA: **See your current data quality cost**
- Pricing CTA Free: **Start free**
- Pricing CTA Premium: **Upgrade for actionable fixes**

## Sales FAQ anchors
- "What can I do in Free vs Premium?"
- "How is Premium priced as data volume grows?"
- "How fast can we see first measurable ROI?"
- "Can a partner manage multiple tenant referrals?"
