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
    "premium": {
        "display_name": "Premium",
        "base_price_monthly": 149.0,
        "included_records": 2000,
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
