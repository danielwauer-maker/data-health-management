# Canonical license pricing (Pflege)

## Single source of truth

| Schicht | Rolle |
|--------|--------|
| **`config/pricing_canonical.json`** | Kanonische Listenpreis-Parameter (Basis EUR/Monat, `included_records`, Zuschlag pro 1000 Records, Marketing-Formatstrings). Wird vom Backend als Default geladen und fuer Snapshot-Fallbacks verwendet. |
| **`license_pricing_config` (DB)** | Laufzeit fuer API-Berechnung, Analytics, Admin und den oeffentlichen Pricing-Pfad. Sobald Zeilen existieren, gelten diese Werte. |
| **`GET /public/pricing`** | Oeffentlicher Read-Pfad fuer Landing/Marketing. Liest bevorzugt DB-Werte und faellt sonst auf die kanonische Repo-Quelle zurueck. |
| **`ensure_default_license_pricing`** | Legt nur fehlende Plan-Zeilen an; ueberschreibt keine bestehenden DB-Werte. |

## Aenderung im Alltag

1. `config/pricing_canonical.json` bearbeiten (Zahlen plus optional `marketing`-Templates).
2. Landing-Fallback aktualisieren: `python scripts/generate_landing_pricing.py` aus dem Repo-Root ausfuehren. Das aktualisiert `landingpage/pricing-snapshot.js`, `landingpage/live/pricing-snapshot.js` und `pricing_premium_chip` in `landingpage/lang/*.json` und `live/lang`.
3. Backend: Nach Deploy liest der Prozess `DEFAULT_LICENSE_PRICING` neu aus der JSON-Datei. Bestehende DB-Zeilen bleiben unveraendert.
4. Produktion - DB anpassen: Entweder Admin-API/UI (`POST /admin/config/license-pricing/{plan_code}`) oder Migration/SQL, damit Rechnungslogik, Analytics und `GET /public/pricing` den neuen Stand nutzen.

## Checks

```bash
python scripts/check_pricing_consistency.py
```

Ohne installiertes Backend-venv werden nur kanonische JSON plus Landing-Snapshot geprueft; mit venv zusaetzlich Abgleich mit `DEFAULT_LICENSE_PRICING`.

## Stripe

Nicht in dieser Datei gepflegt: Stripe Price IDs (`STRIPE_PRICE_ID_PREMIUM`, `STRIPE_PRICE_ID_PREMIUM_YEARLY`). Bei geaendertem Listenpreis neue Prices in Stripe anlegen und Env aktualisieren - siehe `backend/README.md` (Abschnitt Billing).
