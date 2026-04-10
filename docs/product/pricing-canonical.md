# Canonical license pricing (Pflege)

## Single source of truth

| Schicht | Rolle |
|--------|--------|
| **`config/pricing_canonical.json`** | Kanonische **Listenpreis-Parameter** (Basis €/Monat, `included_records`, Zuschlag pro 1000 Records, Marketing-Formatstrings). Wird vom Backend als Default geladen und für die Landingpage generiert. |
| **`license_pricing_config` (DB)** | **Laufzeit** für API-Berechnung, Analytics und Admin. Sobald Zeilen existieren, gelten diese Werte. |
| **`ensure_default_license_pricing`** | Legt nur **fehlende** Plan-Zeilen an; **überschreibt keine** bestehenden DB-Werte. |

## Änderung im Alltag

1. **`config/pricing_canonical.json`** bearbeiten (Zahlen + ggf. `marketing`-Templates).
2. **Landing**: `python scripts/generate_landing_pricing.py` aus dem Repo-Root ausführen. Aktualisiert `landingpage/pricing-snapshot.js`, `landingpage/live/pricing-snapshot.js` und `pricing_premium_chip` in `landingpage/lang/*.json` (und `live/lang`).
3. **Backend**: Nach Deploy liest der Prozess `DEFAULT_LICENSE_PRICING` neu aus der JSON-Datei. **Bestehende DB-Zeilen** bleiben unverändert.
4. **Produktion – DB anpassen**: Entweder **Admin-API/UI** (`POST /admin/config/license-pricing/{plan_code}`) oder **Migration/SQL**, damit Rechnungslogik und Analytics den neuen Stand nutzen.

## Checks

```bash
python scripts/check_pricing_consistency.py
```

Ohne installiertes Backend-venv werden nur kanonische JSON + Landing-Snapshot geprüft; mit venv zusätzlich Abgleich mit `DEFAULT_LICENSE_PRICING`.

## Stripe

Nicht in dieser Datei gepflegt: **Stripe Price IDs** (`STRIPE_PRICE_ID_PREMIUM`, `STRIPE_PRICE_ID_PREMIUM_YEARLY`). Bei geändertem Listenpreis neue Prices in Stripe anlegen und Env aktualisieren — siehe `backend/README.md` (Abschnitt Billing).
