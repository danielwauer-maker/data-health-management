# Data Health Management Backend

Erster MVP-Stand des Analyse-Backends.

## Enthalten
- FastAPI
- Health Endpoint
- Tenant Registration Endpoint
- Billing Foundation (Subscriptions, Invoices, Webhook Events)
- Stripe Checkout Session (Subscription Mode)
- Stripe Webhook Verarbeitung mit Signaturpruefung

## Start
Ueber Docker Compose im Projekt-Root.

## Billing Setup (Stripe)

### Benoetigte ENV Variablen
- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `STRIPE_PRICE_ID_PREMIUM`
- optional: `BILLING_SUCCESS_URL`
- optional: `BILLING_CANCEL_URL`

### API Endpunkte
- `POST /billing/checkout/session`
  - erstellt eine Stripe Checkout Session fuer Premium
- `GET /billing/subscription/status`
  - liefert den aktuellen Abo-Status des Tenants
- `POST /billing/webhook`
  - verarbeitet Stripe Webhooks (mit `Stripe-Signature`)

### Stripe Event Matrix (v1)
Unterstuetzte Events:
- `checkout.session.completed` (wird protokolliert, kein State-Write)
- `customer.subscription.created` -> `subscription.created`
- `customer.subscription.updated` -> `subscription.updated`
- `customer.subscription.deleted` -> `subscription.deleted`
- `invoice.paid` -> Rechnung upsert
- `invoice.payment_failed` -> Rechnung upsert
- `invoice.voided` -> Rechnung upsert

Nicht unterstuetzte Events werden explizit als `ignored` beantwortet.

### Lokaler Webhook-Test (Stripe CLI)
1. Stripe CLI Login:
   - `stripe login`
2. Webhooks weiterleiten:
   - `stripe listen --forward-to http://127.0.0.1:8000/billing/webhook`
3. Den ausgegebenen Secret-Wert als `STRIPE_WEBHOOK_SECRET` setzen.
4. Testevent senden:
   - `stripe trigger customer.subscription.created`

Hinweis: Fuer korrekte Tenant-Zuordnung muessen `tenant_id` und `plan_code` in den Stripe-Metadaten vorhanden sein (wird bei Checkout-Session automatisch gesetzt).

## Partnerprogramm Foundation (v1)

### Neue Tabellen
- `partners`
- `partner_referrals`
- `partner_commissions`

### API Endpunkte
- `POST /partners`
  - legt einen Partner an (Basic-Auth wie Admin)
- `POST /partners/referral/attach`
  - ordnet einen Tenant einem Partner-Code zu (Tenant-Header Auth)
- `GET /partners/referral/status`
  - liefert den aktuellen Referral-Status des authentifizierten Tenants

## Partner Portal & Auth (v2)

### Datenmodell-Erweiterung
- `partners.contact_email` (unique, optional)
- `partners.password_hash` (optional, PBKDF2-SHA256)
- `partners.last_login_at_utc` (optional)

### Neue API Endpunkte (Landingpage Partner-Portal)
- `POST /api/partners/auth/login`
  - Login per `email + password`
  - liefert `access_token` (Bearer JWT)
- `POST /api/partners/auth/set-credentials` (Admin Basic-Auth)
  - setzt/aktualisiert Login-Daten (`partner_code`, `email`, `password`)
- `GET /api/partners/me` (Bearer)
  - liefert Partner-Profil fuer das Portal
- `GET /api/partners/me/referrals` (Bearer)
  - liefert tenant-basierte Referrals inkl. Lizenz-/Subscription-Status
- `GET /api/partners/me/commissions` (Bearer)
  - liefert Provisionshistorie des Partners

### Tenant-Logik im Partner-Portal
- Referral-Zuordnung bleibt tenant-zentriert (`partner_referrals.tenant_id` unique).
- Portal-Daten werden pro Partner gefiltert (`partner_id`) und tenantweise angezeigt.
- Subscription-Status pro Tenant wird aus den neuesten Subscriptions pro `tenant_id` abgeleitet.

### Provisionserzeugung
- Bei `invoice.paid` wird nach erfolgreichem Invoice-Upsert automatisch eine Provision erzeugt, falls ein Referral fuer den Tenant existiert.
- Provisionen sind idempotent auf `provider_invoice_id` (keine doppelten Eintraege pro Rechnung).