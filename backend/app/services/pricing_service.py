from __future__ import annotations

from app.schemas.scan import DataProfile

DEFAULT_FREE_RECORDS_INCLUDED = 5000
DEFAULT_BASE_PREMIUM_PRICE_MONTHLY = 49.0
DEFAULT_ADDITIONAL_RECORD_PRICE = 0.0025


def calculate_estimated_premium_price_monthly(data_profile: DataProfile) -> float:
    total_records = max(0, int(data_profile.total_records or 0))
    chargeable_records = max(0, total_records - DEFAULT_FREE_RECORDS_INCLUDED)
    variable_price = chargeable_records * DEFAULT_ADDITIONAL_RECORD_PRICE
    return round(DEFAULT_BASE_PREMIUM_PRICE_MONTHLY + variable_price, 2)


def calculate_roi_eur(estimated_loss_eur: float, estimated_premium_price_monthly: float) -> float:
    return round(float(estimated_loss_eur) - float(estimated_premium_price_monthly), 2)
