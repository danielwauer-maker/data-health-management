# Go-Live Smoke Tests

Ziel: In 30-60 Minuten die kritischen Backend-Pfade einmal manuell pruefen.

## Vorbereitung

- Backend starten
- Test-/Dev-Datenbank erreichbar
- Fuer Billing: gueltige Stripe-Testkonfiguration aktiv
- Einen frischen Test-Tenant anlegen und `tenant_id` + `api_token` notieren

Platzhalter:

- `<API_BASE>` z. B. `http://localhost:8000` oder `https://dev-api.example.com`
- `<TENANT_ID>`
- `<API_TOKEN>`
- `<SESSION_ID>`

## DEV Smoke Tests

### 1. Health / Liveness

Schritt:

```bash
curl -i <API_BASE>/health
```

Erwartet:

- `200 OK`
- JSON mit `status=ok`
- Header `X-Request-Id` vorhanden

### 2. Readiness / DB

Schritt:

```bash
curl -i <API_BASE>/health/ready
```

Erwartet:

- `200 OK`
- JSON mit `checks.database=ok`

### 3. Tenant Registration

Schritt:

```bash
curl -s -X POST <API_BASE>/tenant/register \
  -H "Content-Type: application/json" \
  -d "{\"environment_name\":\"DEV\",\"app_version\":\"1.0.0\"}"
```

Erwartet:

- `200 OK`
- `tenant_id` und `api_token` in der Response

### 4. Quick Scan

Schritt:

```bash
curl -i -X POST <API_BASE>/scan/quick \
  -H "Content-Type: application/json" \
  -H "X-Tenant-Id: <TENANT_ID>" \
  -H "X-Api-Token: <API_TOKEN>" \
  -d @quick-scan.json
```

`quick-scan.json`:

- `tenant_id=<TENANT_ID>`
- gueltige `metrics`
- gueltiges `data_profile`

Erwartet:

- `200 OK`
- `scan_id`, `data_score`, `issues`, `premium_available`

### 5. Deep Scan / Scan Sync

Schritt:

```bash
curl -i -X POST <API_BASE>/scan/sync \
  -H "Content-Type: application/json" \
  -H "X-Tenant-Id: <TENANT_ID>" \
  -H "X-Api-Token: <API_TOKEN>" \
  -d @deep-scan-sync.json
```

`deep-scan-sync.json`:

- `tenant_id=<TENANT_ID>`
- `scan_type="deep"`
- feste `scan_id`
- realistische `total_records`

Erwartet:

- `200 OK`
- `status=ok`
- `scan_id`
- `commercials`

### 6. Scan History

Schritt:

```bash
curl -i "<API_BASE>/scan/history/<TENANT_ID>?limit=10" \
  -H "X-Tenant-Id: <TENANT_ID>" \
  -H "X-Api-Token: <API_TOKEN>"
```

Erwartet:

- `200 OK`
- Quick-/Deep-Scans erscheinen in `scans`

### 7. Scan Trend

Schritt:

```bash
curl -i <API_BASE>/scan/trend/<TENANT_ID> \
  -H "X-Tenant-Id: <TENANT_ID>" \
  -H "X-Api-Token: <API_TOKEN>"
```

Erwartet:

- `200 OK`
- `trend`, `latest_scan_id`, optional `previous_scan_id`

### 8. Analytics Token

Schritt:

```bash
curl -i <API_BASE>/analytics/get-token \
  -H "X-Tenant-Id: <TENANT_ID>" \
  -H "X-Api-Token: <API_TOKEN>"
```

Erwartet:

- `200 OK` mit gueltigen Analytics-Daten
- oder klarer Konfigurationsfehler
- kein `500` mit internem Detail-Leak

### 9. Analytics Embed

Schritt:

- Im Browser aufrufen:
  - `<API_BASE>/analytics/embed?tenant_id=<TENANT_ID>`

Erwartet:

- Seite laedt
- kein leerer Embed
- kein `500`

### 10. DEV-API Gegenprobe

Schritt:

- Alle Punkte 1-9 einmal gegen die echte Dev-URL ausfuehren

Erwartet:

- gleiches Verhalten wie lokal
- `X-Request-Id` vorhanden
- Logs im Dev-Logging auffindbar

## Billing Smoke Tests

### 1. Billing ENV Vorcheck

Pruefen:

- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`
- benoetigte `STRIPE_PRICE_ID_*`
- `APP_BASE_URL` oder explizit:
  - `BILLING_SUCCESS_URL`
  - `BILLING_CANCEL_URL`
  - `BILLING_PORTAL_RETURN_URL`

Erwartet:

- keine Platzhalter
- keine falsche Domain
- keine `localhost`-URL in Prod

### 2. Checkout Session erstellen

Schritt:

```bash
curl -i -X POST <API_BASE>/billing/checkout/session \
  -H "Content-Type: application/json" \
  -H "X-Tenant-Id: <TENANT_ID>" \
  -H "X-Api-Token: <API_TOKEN>" \
  -d "{\"tenant_id\":\"<TENANT_ID>\",\"plan_code\":\"premium\",\"billing_interval\":\"monthly\"}"
```

Erwartet:

- `200 OK`
- `provider=stripe`
- `checkout_url` vorhanden

Achte auf:

- keine `pending_integration`
- keine falsche Domain in der Response

### 3. Stripe Redirect pruefen

Schritt:

- `checkout_url` im Browser oeffnen

Erwartet:

- echte Stripe Checkout-Seite
- Produkt/Preis stimmen

Achte auf:

- korrekter Betrag
- korrekter Billing-Intervall
- korrekte Waehrung

### 4. Cancel URL pruefen

Schritt:

- Checkout oeffnen
- Abbrechen / zurueck

Erwartet:

- Redirect auf die konfigurierte Cancel-URL

Achte auf:

- Domain exakt korrekt
- kein Redirect auf alte Hardcoded-Domain

### 5. Success URL pruefen

Schritt:

- Checkout mit Stripe-Testkarte abschliessen
- z. B. `4242 4242 4242 4242`

Erwartet:

- Redirect auf die konfigurierte Success-URL
- `session_id` in der URL, falls vorgesehen

Achte auf:

- keine fremde Domain
- kein `404` auf der Rueckkehrseite

### 6. Lizenzstatus nach Zahlung

Schritt:

```bash
curl -i "<API_BASE>/billing/checkout/session/status?session_id=<SESSION_ID>" \
  -H "X-Tenant-Id: <TENANT_ID>" \
  -H "X-Api-Token: <API_TOKEN>"
```

Dann:

```bash
curl -i <API_BASE>/billing/subscription/status \
  -H "X-Tenant-Id: <TENANT_ID>" \
  -H "X-Api-Token: <API_TOKEN>"
```

Erwartet:

- `status=synced` oder sinnvoller Zwischenstatus
- `current_plan=premium`
- `license_status=active`

### 7. Webhook-Verarbeitung pruefen

Schritt lokal:

```bash
stripe listen --forward-to http://127.0.0.1:8000/billing/webhook
```

Schritt allgemein:

- Im Stripe Dashboard oder via CLI pruefen, ob relevante Events erfolgreich zugestellt wurden

Erwartet:

- keine Retry-Schleife
- Events wie `customer.subscription.updated` / `invoice.paid` erfolgreich

Achte auf:

- Fehler sauber im Log sichtbar
- keine internen Details im API-Response

### 8. Billing Portal oeffnen

Voraussetzung:

- aktive Subscription vorhanden

Schritt:

```bash
curl -i -X POST <API_BASE>/billing/portal \
  -H "Content-Type: application/json" \
  -H "X-Tenant-Id: <TENANT_ID>" \
  -H "X-Api-Token: <API_TOKEN>" \
  -d "{\"tenant_id\":\"<TENANT_ID>\"}"
```

Erwartet:

- `200 OK`
- `portal_url` vorhanden

Danach:

- `portal_url` im Browser oeffnen

Achte auf:

- Rueckkehr geht auf die richtige Return-URL
- Tenant/Subscription stimmen

### 9. Subscription Status pruefen

Schritt:

```bash
curl -i <API_BASE>/billing/subscription/status \
  -H "X-Tenant-Id: <TENANT_ID>" \
  -H "X-Api-Token: <API_TOKEN>"
```

Erwartet:

- Provider-Status konsistent mit Stripe
- `provider_subscription_id` gesetzt
- `amount_monthly` plausibel

### 10. Premium-Funktion nach Kauf pruefen

Schritt:

- Nach erfolgreichem Billing erneut Premium-relevanten Flow testen:
  - `analytics/embed`
  - ggf. weitere Premium-Features

Erwartet:

- Premium-Zugriff aktiv
- kein Fall `bezahlt, aber weiter gesperrt`

## PROD Go-Live Checkliste

### ENV & Config

- [ ] `SECRET_KEY` stark und nicht Default
- [ ] `ADMIN_PASSWORD` stark und nicht Default
- [ ] `DATABASE_URL` korrekt
- [ ] `STRIPE_SECRET_KEY` gesetzt
- [ ] `STRIPE_WEBHOOK_SECRET` gesetzt
- [ ] benoetigte `STRIPE_PRICE_ID_*` gesetzt
- [ ] `APP_BASE_URL` korrekt
- [ ] falls genutzt: `BILLING_SUCCESS_URL` gesetzt
- [ ] falls genutzt: `BILLING_CANCEL_URL` gesetzt
- [ ] falls genutzt: `BILLING_PORTAL_RETURN_URL` gesetzt
- [ ] keine Platzhalter aus `.env.example`
- [ ] keine Dev-/localhost-URLs in Prod aktiv

### Infrastruktur

- [ ] `/health` liefert `200`
- [ ] `/health/ready` liefert `200`
- [ ] DB erreichbar
- [ ] Alembic auf aktuellem Stand
- [ ] API oeffentlich erreichbar
- [ ] TLS / Reverse Proxy korrekt
- [ ] Stripe Webhook Endpoint oeffentlich erreichbar

### Security

- [ ] Tenant-geschuetzte Endpoints ohne Header liefern `401`
- [ ] falscher `X-Api-Token` liefert `403`
- [ ] fremde `tenant_id` gegen Header liefert Fehler
- [ ] keine internen Fehlerdetails in Responses
- [ ] keine Secrets in Logs sichtbar

### Monitoring

- [ ] Request-Logs sichtbar
- [ ] `X-Request-Id` wird erzeugt oder uebernommen
- [ ] Fehler im Logging auffindbar
- [ ] Billing-Events im Log sichtbar
- [ ] DB- und Stripe-Fehler sichtbar

### End-to-End

- [ ] Tenant registrieren
- [ ] Quick Scan erfolgreich
- [ ] Deep Scan / Sync erfolgreich
- [ ] Scan History sichtbar
- [ ] Analytics Token / Embed funktioniert
- [ ] Checkout startet
- [ ] Stripe Zahlung erfolgreich
- [ ] Success Redirect korrekt
- [ ] Webhook verarbeitet
- [ ] Subscription Status korrekt
- [ ] Premium-Funktion danach freigeschaltet
- [ ] Rueckweg in App / BC-Flow funktioniert

## Fehlerfaelle

### 1. Falscher Token

Schritt:

```bash
curl -i <API_BASE>/billing/subscription/status \
  -H "X-Tenant-Id: <TENANT_ID>" \
  -H "X-Api-Token: wrong-token"
```

Erwartet:

- `403`
- kein `500`

### 2. Fehlende Billing-URL-Konfiguration

Schritt:

- In Dev/Stage `APP_BASE_URL` bzw. Billing-URLs bewusst entfernen
- Checkout und Portal erneut aufrufen

Erwartet:

- klarer Fehler
- kein Redirect auf falsche Domain

### 3. Stripe Fehler simulieren

Schritt:

- In Stage absichtlich falsche Price ID oder falschen Secret Key setzen
- Checkout oder Portal testen

Erwartet:

- sauberer Fehler
- im Log eindeutig sichtbar

### 4. DB down

Schritt:

- DB kurz stoppen oder Verbindung blockieren
- `/health` und `/health/ready` aufrufen

Erwartet:

- `/health` bleibt leichtgewichtig
- `/health/ready` schlaegt fehl

### 5. Webhook mit ungueltiger Signatur

Schritt:

```bash
curl -i -X POST <API_BASE>/billing/webhook \
  -H "Stripe-Signature: invalid" \
  -H "Content-Type: application/json" \
  -d "{}"
```

Erwartet:

- `400`
- kein `500`
- Fehler im Log sichtbar
