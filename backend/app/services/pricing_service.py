from __future__ import annotations

from app.models import LicensePricingConfig

DEFAULT_LICENSE_PRICING: dict[str, dict[str, float | int | str | bool]] = {
    "free": {
        "display_name": "Free",
        "base_price_monthly": 0.0,
        "included_records": 0,
        "additional_price_per_1000_records": 0.0,
        "is_active": True,
    },
    "standard": {
        "display_name": "Standard",
        "base_price_monthly": 49.0,
        "included_records": 10000,
        "additional_price_per_1000_records": 4.5,
        "is_active": True,
    },
    "premium": {
        "display_name": "Premium",
        "base_price_monthly": 149.0,
        "included_records": 25000,
        "additional_price_per_1000_records": 8.0,
        "is_active": True,
    },
}


def ensure_default_license_pricing(db) -> None:
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
    db.commit()


def get_license_pricing(db, plan_code: str = "premium") -> LicensePricingConfig | None:
    return db.get(LicensePricingConfig, plan_code)


def calculate_monthly_price(total_records: int, pricing: LicensePricingConfig | None) -> float:
    total_records = max(int(total_records or 0), 0)
    if pricing is None or not pricing.is_active:
        pricing_dict = DEFAULT_LICENSE_PRICING["premium"]
        base_price = float(pricing_dict["base_price_monthly"])
        included_records = int(pricing_dict["included_records"])
        additional_price_per_1000_records = float(pricing_dict["additional_price_per_1000_records"])
    else:
        base_price = float(pricing.base_price_monthly or 0.0)
        included_records = int(pricing.included_records or 0)
        additional_price_per_1000_records = float(pricing.additional_price_per_1000_records or 0.0)

    chargeable_records = max(total_records - included_records, 0)
    extra_units = (chargeable_records + 999) // 1000
    return round(base_price + (extra_units * additional_price_per_1000_records), 2)
