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

## Entitlements (Session 2 Foundation)

- Zentrale Feature-Aufloesung liegt in:
  - `app/services/entitlement_service.py`
- Serverseitige Feature-Enforcement-Helper liegen in:
  - `app/services/entitlement_guard_service.py`
- `premium_available` beschreibt nur noch:
  - ob Premium-Action-/Detail-Features fuer den Tenant freigeschaltet sind
  - (nicht mehr pauschal `true`)
- `deep_scan` ist Teil der gemeinsamen Analysebasis fuer Free und Premium.

### Matrix-Check ausfuehren

Vom `backend`-Ordner:

- `python -m scripts.check_entitlements`

Erwartetes Ergebnis:

- `Entitlement matrix check OK (8 states validated).`

## Billing Setup (Stripe)

### Benoetigte ENV Variablen
- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `STRIPE_PRICE_ID_PREMIUM`
- optional: `STRIPE_PRICE_ID_PREMIUM_YEARLY`
- optional: `BILLING_SUCCESS_URL`
- optional: `BILLING_CANCEL_URL`
- optional: `BILLING_PORTAL_RETURN_URL`

### Listenpreis aendern (Marketing, App-Berechnung, Stripe)

Die interne Berechnung und Marketing-Defaults folgen `config/pricing_canonical.json` bzw. der Tabelle `license_pricing_config` (siehe `docs/product/pricing-canonical.md`). Die Landingpage liest oeffentliche Preisinfos zuerst ueber `GET /public/pricing` und faellt nur bei Fehlern auf `pricing-snapshot.js` zurueck. **Stripe** arbeitet mit **Price IDs**, nicht mit dem Betrag im Code: Wenn sich der veroeffentlichte Monats- oder Jahrespreis aendert, legt ihr in Stripe Dashboard neue **Prices** an (oder dupliziert bestehende und passt Betrag/Intervall an), traegt die neuen IDs in die Umgebung ein:

- `STRIPE_PRICE_ID_PREMIUM` (monatlich)
- `STRIPE_PRICE_ID_PREMIUM_YEARLY` (jaehrlich, optional)

Danach Deploy/Restart, damit Checkout die neuen IDs nutzt. Abgleich: Listenpreis in canonical/DB sollte zum abgerechneten Stripe-Betrag passen; bestehende Abonnements behalten ihre gebuchte Price-Version, bis ihr sie in Stripe migriert.

### API Endpunkte
- `POST /billing/checkout/session`
  - erstellt eine Stripe Checkout Session fuer Premium
  - unterstuetzt `billing_interval` = `monthly` | `yearly`
- `GET /billing/subscription/status`
  - liefert den aktuellen Abo-Status des Tenants
- `GET /billing/checkout/session/status?session_id=...`
  - synchronisiert nach Checkout den Stripe-Subscription-Status aktiv in den Tenant
- `POST /billing/portal`
  - erstellt eine Stripe Billing Portal Session (self-service)
- `POST /billing/webhook`
  - verarbeitet Stripe Webhooks (mit `Stripe-Signature`)

### Stripe Event Matrix (v1)
Unterstuetzte Events:
- `checkout.session.completed` (wird protokolliert, kein State-Write)
- `checkout.session.expired` (wird protokolliert, kein State-Write)
- `customer.subscription.created` -> `subscription.created`
- `customer.subscription.updated` -> `subscription.updated`
- `customer.subscription.deleted` -> `subscription.deleted`
- `invoice.paid` -> Rechnung upsert
- `invoice.payment_failed` -> Rechnung upsert
- `invoice.voided` -> Rechnung upsert
- `invoice.finalized` -> Rechnung upsert
- `invoice.updated` -> Rechnung upsert
- `invoice.marked_uncollectible` -> Rechnung upsert

Nicht unterstuetzte Events werden explizit als `ignored` beantwortet.

### E2E Billing Testablauf (empfohlen)
1. Checkout Session erstellen:
   - `POST /billing/checkout/session` (mit `billing_interval=monthly` oder `yearly`)
2. Stripe Checkout abschliessen.
3. Session aktiv synchronisieren:
   - `GET /billing/checkout/session/status?session_id=...`
4. Subscription Status pruefen:
   - `GET /billing/subscription/status`
5. Optional Self-Service testen:
   - `POST /billing/portal`
6. Webhook-Delivery in Stripe Dashboard pruefen:
   - relevante Events `delivered` ohne Retry-Stau.

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
- `partner_applications` (public partner registration intake)
  - inkl. `mail_status`, `last_mail_error`, `last_mail_sent_at_utc`

### Neue API Endpunkte (Landingpage Partner-Portal)
- `POST /api/partners/register`
  - oeffentliche Partner-Registrierung (Firma, Kontakt, E-Mail, Einwilligung)
  - schreibt einen Datensatz in `partner_applications` (Status `new`)
  - sendet optional eine Eingangs-Bestaetigung per E-Mail
- `POST /api/partners/auth/login`
  - Login per `email + password`
  - liefert `access_token` (Bearer JWT)
- `POST /api/partners/auth/reset/request`
  - startet "Passwort vergessen" per E-Mail (Antwort immer generisch)
- `POST /api/partners/auth/set-credentials` (Admin Basic-Auth)
  - setzt/aktualisiert Login-Daten (`partner_code`, `email`, `password`)
- `POST /api/partners/auth/reset/confirm`
  - setzt Passwort per einmaligem Reset-Token (`token`, `new_password`)
- `GET /api/partners/me` (Bearer)
  - liefert Partner-Profil fuer das Portal
- `POST /api/partners/me/profile` (Bearer)
  - aktualisiert Partner-Profil (aktuell: `name`, optional `new_password`)
  - Login-E-Mail bleibt absichtlich unveraenderbar im Portal
- `GET /api/partners/me/referrals` (Bearer)
  - liefert tenant-basierte Referrals inkl. Lizenz-/Subscription-Status
- `GET /api/partners/me/commissions` (Bearer)
  - liefert Provisionshistorie des Partners

### Admin UI Erweiterungen (Partner Access)
- Partner Applications Review-Workflow:
  - Status: `new`, `reviewed`, `accepted`, `rejected`
  - bei `accepted`: Partner wird angelegt/aktualisiert und per Set-Password-Link eingeladen
  - Mailversand-Status und letzte Fehlerursache sichtbar
  - CSV-Export: `GET /admin/partners/applications.csv`
  - Filter/Search in Admin (`app_status`, `mail_status`, `company/contact/email`) plus KPI counters
- Passwort-Generator direkt im Partner-Credentials-Formular.
- `POST /admin/partners/{partner_id}/reset-link`
  - erzeugt einen Reset-Link fuer `partner-reset-password.html?token=...`
  - Token-Laufzeit folgt `TOKEN_EXPIRE_MINUTES`
  - inklusive Copy-to-Clipboard auf der Ausgabe-Seite
- `POST /admin/partners/{partner_id}/delete`
  - loescht Partner nur, wenn keine Referrals/Provisionen verknuepft sind
  - sonst bewusst Blockierung (Audit-/Abrechnungs-Historie bleibt erhalten)
- Optionales ENV: `PARTNER_RESET_URL_BASE`
  - wenn gesetzt, wird diese Base-URL fuer Reset-Links verwendet
  - sonst wird `request.base_url` genutzt

### Basis Abuse-Protection
- Partner-Registrierung (`POST /api/partners/register`): max. 4 Versuche pro IP / 5 Minuten.
- Login (`POST /api/partners/auth/login`): max. 8 Versuche pro IP / 60 Sekunden.
- Reset-Request (`POST /api/partners/auth/reset/request`): max. 4 Versuche pro IP / 5 Minuten.
- Reset-Confirm (`POST /api/partners/auth/reset/confirm`): max. 6 Versuche pro IP / 5 Minuten.

### SMTP fuer Partner-Reset-Mails
- `SMTP_HOST`
- `SMTP_PORT` (Default: `587`)
- `SMTP_USERNAME` (optional)
- `SMTP_PASSWORD` (optional)
- `SMTP_USE_TLS` (Default: `true`)
- `SMTP_FROM_EMAIL` (erforderlich fuer Versand)
- `SMTP_FROM_NAME` (Default: `BCSentinel`)

### Tenant-Logik im Partner-Portal
- Referral-Zuordnung bleibt tenant-zentriert (`partner_referrals.tenant_id` unique).
- Portal-Daten werden pro Partner gefiltert (`partner_id`) und tenantweise angezeigt.
- Subscription-Status pro Tenant wird aus den neuesten Subscriptions pro `tenant_id` abgeleitet.

### Provisionserzeugung
- Bei `invoice.paid` wird nach erfolgreichem Invoice-Upsert automatisch eine Provision erzeugt, falls ein Referral fuer den Tenant existiert.
- Provisionen sind idempotent auf `provider_invoice_id` (keine doppelten Eintraege pro Rechnung).
- Partner-Policy (v3):
  - Standardrate: `30%`
  - Renewal-Rate: `15%` (ab der zweiten provisionsfaehigen Rechnung je Partner+Tenant)
  - Provisionserzeugung nur bei `invoice.status = paid`
  - Bei Reversal-Status (`voided`, `uncollectible`, `refunded`) werden nicht-ausgezahlte Provisionen automatisch auf `rejected` gesetzt.
