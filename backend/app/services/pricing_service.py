from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from app.models import LicensePricingConfig

PRICING_NOTE_MONTHLY = "Monthly billing is recalculated from your current scanned records."
PRICING_NOTE_ANNUAL = (
    "Annual billing locks in your current price for 12 months, even if your record volume increases."
)

_REPO_ROOT = Path(__file__).resolve().parents[3]
_CANONICAL_JSON = _REPO_ROOT / "config" / "pricing_canonical.json"
# Public alias for scripts/tests (same path as _CANONICAL_JSON).
CANONICAL_PRICING_JSON_PATH = _CANONICAL_JSON

# Inline fallback if config file is missing (e.g. mis-deployed artifact). Keep in sync with config/pricing_canonical.json.
_FALLBACK_LICENSE_PRICING: dict[str, dict[str, float | int | str | bool]] = {
    "free": {
        "display_name": "Free",
        "base_price_monthly": 0.0,
        "included_records": 0,
        "additional_price_per_1000_records": 0.0,
        "is_active": True,
    },
    "premium": {
        "display_name": "Premium",
        "base_price_monthly": 149.0,
        "included_records": 2000,
        "additional_price_per_1000_records": 8.0,
        "is_active": True,
    },
}


def _load_canonical_pricing_document() -> dict[str, Any]:
    if not _CANONICAL_JSON.is_file():
        return {}
    try:
        return json.loads(_CANONICAL_JSON.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError, TypeError, ValueError):
        return {}


def _load_default_license_pricing_from_canonical() -> dict[str, dict[str, float | int | str | bool]]:
    data = _load_canonical_pricing_document()
    if not data:
        return dict(_FALLBACK_LICENSE_PRICING)
    try:
        plans = data.get("plans") or {}
        out: dict[str, dict[str, float | int | str | bool]] = {}
        for code, row in plans.items():
            out[str(code)] = {
                "display_name": str(row.get("display_name", code)),
                "base_price_monthly": float(row.get("base_price_monthly", 0)),
                "included_records": int(row.get("included_records", 0)),
                "additional_price_per_1000_records": float(row.get("additional_price_per_1000_records", 0)),
                "is_active": bool(row.get("is_active", True)),
            }
        if "free" in out and "premium" in out:
            return out
    except (OSError, json.JSONDecodeError, TypeError, ValueError):
        pass
    return dict(_FALLBACK_LICENSE_PRICING)


# Single source for list-price defaults: config/pricing_canonical.json (see docs/product/pricing-canonical.md)
DEFAULT_LICENSE_PRICING: dict[str, dict[str, float | int | str | bool]] = _load_default_license_pricing_from_canonical()


def ensure_default_license_pricing(db) -> None:
    """
    Inserts LicensePricingConfig rows for any plan_code present in DEFAULT_LICENSE_PRICING
    that does not yet exist in the database.

    Does **not** update existing rows — production changes to list prices must be done via
    Admin UI (/admin/config/license-pricing/{plan_code}) or a migration/SQL so you do not
    silently overwrite deliberate DB edits on every deploy.
    """
    for plan_code, config in DEFAULT_LICENSE_PRICING.items():
        existing = db.get(LicensePricingConfig, plan_code)
        if existing is None:
            db.add(
                LicensePricingConfig(
                    plan_code=plan_code,
                    display_name=str(config["display_name"]),
                    base_price_monthly=float(config["base_price_monthly"]),
                    included_records=int(config["included_records"]),
                    additional_price_per_1000_records=float(config["additional_price_per_1000_records"]),
                    is_active=bool(config["is_active"]),
                )
            )

    legacy_standard = db.get(LicensePricingConfig, "standard")
    if legacy_standard is not None:
        legacy_standard.is_active = False

    db.commit()



def get_license_pricing(db, plan_code: str = "premium") -> LicensePricingConfig | None:
    return db.get(LicensePricingConfig, plan_code)



def calculate_variable_price(total_records: int, pricing: LicensePricingConfig | None) -> float:
    total_records = max(int(total_records or 0), 0)
    if pricing is None or not pricing.is_active:
        pricing_dict = DEFAULT_LICENSE_PRICING["premium"]
        step_records = int(pricing_dict["included_records"])
        price_per_step = float(pricing_dict["additional_price_per_1000_records"])
    else:
        step_records = int(pricing.included_records or 0)
        price_per_step = float(pricing.additional_price_per_1000_records or 0.0)

    if step_records <= 0 or price_per_step <= 0 or total_records <= 0:
        return 0.0

    return round((total_records / step_records) * price_per_step, 2)



def round_to_friendly_price(raw_price: float) -> float:
    raw_price = round(float(raw_price or 0.0), 2)
    if raw_price <= 0:
        return 0.0

    integer_price = int(round(raw_price))
    if integer_price % 10 == 9 and abs(raw_price - integer_price) < 0.01:
        return float(integer_price)

    lower_ending_9 = ((integer_price // 10) * 10) - 1
    upper_ending_9 = lower_ending_9 + 10

    if lower_ending_9 <= 0:
        return float(max(9, upper_ending_9))

    if abs(raw_price - lower_ending_9) <= abs(upper_ending_9 - raw_price):
        return float(lower_ending_9)
    return float(upper_ending_9)



def calculate_monthly_price(total_records: int, pricing: LicensePricingConfig | None, *, friendly_rounding: bool = True) -> float:
    total_records = max(int(total_records or 0), 0)
    if pricing is None or not pricing.is_active:
        pricing_dict = DEFAULT_LICENSE_PRICING["premium"]
        base_price = float(pricing_dict["base_price_monthly"])
    else:
        base_price = float(pricing.base_price_monthly or 0.0)

    raw_price = round(base_price + calculate_variable_price(total_records, pricing), 2)
    if not friendly_rounding:
        return raw_price
    return round_to_friendly_price(raw_price)



def get_pricing_breakdown(total_records: int, pricing: LicensePricingConfig | None, *, friendly_rounding: bool = True) -> dict[str, float | int]:
    total_records = max(int(total_records or 0), 0)
    if pricing is None or not pricing.is_active:
        pricing_dict = DEFAULT_LICENSE_PRICING["premium"]
        base_price = float(pricing_dict["base_price_monthly"])
        step_records = int(pricing_dict["included_records"])
        price_per_step = float(pricing_dict["additional_price_per_1000_records"])
    else:
        base_price = float(pricing.base_price_monthly or 0.0)
        step_records = int(pricing.included_records or 0)
        price_per_step = float(pricing.additional_price_per_1000_records or 0.0)

    variable_price = calculate_variable_price(total_records, pricing)
    raw_price = round(base_price + variable_price, 2)
    final_price = round_to_friendly_price(raw_price) if friendly_rounding else raw_price

    return {
        "total_records": total_records,
        "base_price_monthly": round(base_price, 2),
        "step_records": step_records,
        "price_per_step": round(price_per_step, 2),
        "variable_price_monthly": round(variable_price, 2),
        "raw_price_monthly": raw_price,
        "final_price_monthly": round(final_price, 2),
    }


def build_embed_pricing_breakdown(total_records: int, pricing: LicensePricingConfig | None) -> dict[str, Any]:
    """
    Single source for analytics/embed UI: components + annual projection + copy.
    Uses get_pricing_breakdown only (no duplicate formulas).
    """
    bd = get_pricing_breakdown(total_records, pricing)
    final = float(bd["final_price_monthly"])
    return {
        "base_price_monthly": bd["base_price_monthly"],
        "step_records": bd["step_records"],
        "price_per_step": bd["price_per_step"],
        "variable_price_monthly": bd["variable_price_monthly"],
        "final_price_monthly": round(final, 2),
        "annual_fixed_price": round(final * 12, 2),
        "monthly_note": PRICING_NOTE_MONTHLY,
        "annual_note": PRICING_NOTE_ANNUAL,
    }


def _format_public_marketing_strings(base_price: float, currency: str, marketing: dict[str, Any]) -> dict[str, dict[str, str]]:
    rounded_base = int(round(float(base_price or 0.0)))
    currency_symbol = "EUR" if (currency or "").upper() != "EUR" else "€"
    return {
        "de": {
            "plan_premium_price": str(marketing.get("format_de_plan_price", "Ab {currency} {base}")).format(
                currency=currency_symbol,
                base=rounded_base,
            ),
            "pricing_premium_chip": str(marketing.get("format_de_chip", "Ab {currency} {base} / Monat")).format(
                currency=currency_symbol,
                base=rounded_base,
            ),
        },
        "en": {
            "plan_premium_price": str(marketing.get("format_en_plan_price", "From {currency} {base}")).format(
                currency=currency_symbol,
                base=rounded_base,
            ),
            "pricing_premium_chip": str(marketing.get("format_en_chip", "From {currency} {base} / month")).format(
                currency=currency_symbol,
                base=rounded_base,
            ),
        },
    }


def get_public_pricing_payload(db, plan_code: str = "premium") -> dict[str, Any]:
    canonical = _load_canonical_pricing_document()
    currency = str(canonical.get("currency") or "EUR").upper()
    marketing = canonical.get("marketing") or {}

    pricing = get_license_pricing(db, plan_code)
    if pricing is None or not pricing.is_active:
        fallback = DEFAULT_LICENSE_PRICING.get(plan_code, DEFAULT_LICENSE_PRICING["premium"])
        base_price = float(fallback.get("base_price_monthly", 0.0))
        included_records = int(fallback.get("included_records", 0))
        step_price = float(fallback.get("additional_price_per_1000_records", 0.0))
        display_name = str(fallback.get("display_name", plan_code.title()))
        source = "canonical"
    else:
        base_price = float(pricing.base_price_monthly or 0.0)
        included_records = int(pricing.included_records or 0)
        step_price = float(pricing.additional_price_per_1000_records or 0.0)
        display_name = str(pricing.display_name or plan_code.title())
        source = "database"

    return {
        "source": source,
        "currency": currency,
        "plan_code": plan_code,
        "display_name": display_name,
        "base_price": round(base_price, 2),
        "included_records": included_records,
        "step_records": included_records,
        "step_price": round(step_price, 2),
        "marketing": _format_public_marketing_strings(base_price, currency, marketing),
    }
