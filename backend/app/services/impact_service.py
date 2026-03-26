from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable

from app.models import ImpactSettingsConfig, IssueImpactConfig

DEFAULT_HOURLY_RATE_EUR = 50.0
DEFAULT_POTENTIAL_SAVING_FACTOR = 0.7


@dataclass(frozen=True)
class ImpactProfile:
    title: str
    minutes_per_occurrence: float
    probability: float
    frequency_per_year: float
    category: str = "general"


DEFAULT_ISSUE_IMPACT_PROFILES: dict[str, ImpactProfile] = {
    "CUSTOMERS_MISSING_NAME": ImpactProfile("Customers missing name", 8, 0.60, 12, "customers"),
    "CUSTOMERS_MISSING_SEARCH_NAME": ImpactProfile("Customers missing search name", 2, 0.20, 12, "customers"),
    "CUSTOMERS_MISSING_ADDRESS": ImpactProfile("Customers missing address", 6, 0.35, 8, "customers"),
    "CUSTOMERS_MISSING_CITY": ImpactProfile("Customers missing city", 4, 0.25, 8, "customers"),
    "CUSTOMERS_MISSING_POST_CODE": ImpactProfile("Customers missing post code", 4, 0.25, 8, "customers"),
    "CUSTOMERS_MISSING_COUNTRY": ImpactProfile("Customers missing country", 4, 0.20, 8, "customers"),
    "CUSTOMERS_MISSING_VAT_REG_NO": ImpactProfile("Customers missing VAT registration no.", 15, 0.40, 12, "customers"),
    "CUSTOMERS_MISSING_EMAIL": ImpactProfile("Customers missing email", 3, 0.30, 12, "customers"),
    "CUSTOMERS_MISSING_PHONE": ImpactProfile("Customers missing phone", 2, 0.20, 12, "customers"),
    "CUSTOMERS_MISSING_PAYMENT_TERMS": ImpactProfile("Customers missing payment terms", 10, 0.30, 12, "customers"),
    "CUSTOMERS_MISSING_PAYMENT_METHOD": ImpactProfile("Customers missing payment method", 7, 0.30, 12, "customers"),
    "CUSTOMERS_MISSING_CUSTOMER_POSTING_GROUP": ImpactProfile("Customers missing customer posting group", 12, 0.45, 12, "customers"),
    "CUSTOMERS_MISSING_GEN_BUS_POSTING_GROUP": ImpactProfile("Customers missing Gen. Bus. Posting Group", 10, 0.40, 12, "customers"),
    "CUSTOMERS_MISSING_VAT_BUS_POSTING": ImpactProfile("Customers missing VAT Bus. Posting", 10, 0.40, 12, "customers"),
    "CUSTOMERS_DUPLICATE_EMAIL": ImpactProfile("Customers duplicate email", 18, 0.25, 12, "customers"),
    "CUSTOMERS_DUPLICATE_VAT": ImpactProfile("Customers duplicate VAT", 30, 0.35, 12, "customers"),
    "CUSTOMERS_DUPLICATE_NAME_POST_CITY": ImpactProfile("Customers duplicate name/post code/city", 25, 0.25, 12, "customers"),
    "VENDORS_MISSING_NAME": ImpactProfile("Vendors missing name", 8, 0.60, 12, "vendors"),
    "VENDORS_MISSING_SEARCH_NAME": ImpactProfile("Vendors missing search name", 2, 0.20, 12, "vendors"),
    "VENDORS_MISSING_ADDRESS": ImpactProfile("Vendors missing address", 6, 0.35, 8, "vendors"),
    "VENDORS_MISSING_CITY": ImpactProfile("Vendors missing city", 4, 0.25, 8, "vendors"),
    "VENDORS_MISSING_POST_CODE": ImpactProfile("Vendors missing post code", 4, 0.25, 8, "vendors"),
    "VENDORS_MISSING_COUNTRY": ImpactProfile("Vendors missing country", 4, 0.20, 8, "vendors"),
    "VENDORS_MISSING_EMAIL": ImpactProfile("Vendors missing email", 3, 0.30, 12, "vendors"),
    "VENDORS_MISSING_PHONE": ImpactProfile("Vendors missing phone", 2, 0.20, 12, "vendors"),
    "VENDORS_MISSING_PAYMENT_TERMS": ImpactProfile("Vendors missing payment terms", 9, 0.30, 12, "vendors"),
    "VENDORS_MISSING_PAYMENT_METHOD": ImpactProfile("Vendors missing payment method", 7, 0.28, 12, "vendors"),
    "VENDORS_MISSING_VENDOR_POSTING_GROUP": ImpactProfile("Vendors missing vendor posting group", 12, 0.45, 12, "vendors"),
    "VENDORS_MISSING_GEN_BUS_POSTING_GROUP": ImpactProfile("Vendors missing Gen. Bus. Posting Group", 10, 0.40, 12, "vendors"),
    "VENDORS_MISSING_VAT_BUS_POSTING": ImpactProfile("Vendors missing VAT Bus. Posting", 10, 0.40, 12, "vendors"),
    "VENDORS_MISSING_BANK_ACCOUNT": ImpactProfile("Vendors missing bank account", 12, 0.55, 12, "vendors"),
    "VENDORS_DUPLICATE_EMAIL": ImpactProfile("Vendors duplicate email", 18, 0.25, 12, "vendors"),
    "VENDORS_DUPLICATE_VAT": ImpactProfile("Vendors duplicate VAT", 30, 0.35, 12, "vendors"),
    "VENDORS_DUPLICATE_NAME_POST_CITY": ImpactProfile("Vendors duplicate name/post code/city", 25, 0.25, 12, "vendors"),
    "ITEMS_MISSING_DESCRIPTION": ImpactProfile("Items missing description", 2, 0.15, 24, "items"),
    "ITEMS_MISSING_BASE_UNIT": ImpactProfile("Items missing base unit", 7, 0.35, 12, "items"),
    "ITEMS_MISSING_CATEGORY": ImpactProfile("Items missing category", 4, 0.20, 12, "items"),
    "ITEMS_MISSING_GEN_PROD_POSTING_GROUP": ImpactProfile("Items missing Gen. Prod. Posting Group", 10, 0.45, 12, "items"),
    "ITEMS_MISSING_INVENTORY_POSTING_GROUP": ImpactProfile("Items missing inventory posting group", 12, 0.45, 12, "items"),
    "ITEMS_MISSING_VAT_PROD_POSTING_GROUP": ImpactProfile("Items missing VAT Prod. Posting Group", 9, 0.35, 12, "items"),
    "ITEMS_MISSING_VENDOR_NO": ImpactProfile("Items missing vendor no.", 4, 0.20, 12, "items"),
    "ITEMS_WITHOUT_UNIT_COST": ImpactProfile("Items without unit cost", 12, 0.60, 12, "items"),
    "ITEMS_WITHOUT_UNIT_PRICE": ImpactProfile("Items without unit price", 12, 0.70, 12, "items"),
    "ITEMS_NEGATIVE_INVENTORY": ImpactProfile("Items with negative inventory", 20, 0.60, 12, "items"),
    "BLOCKED_ITEMS_WITH_INVENTORY": ImpactProfile("Blocked items with inventory", 15, 0.45, 12, "items"),
    "SALES_ORDERS_MISSING_SHIPMENT_DATE": ImpactProfile("Sales orders missing shipment date", 8, 0.35, 12, "sales"),
    "SALES_ORDERS_OLD_OPEN": ImpactProfile("Old open sales orders", 10, 0.40, 12, "sales"),
    "SALES_LINES_MISSING_NO": ImpactProfile("Sales lines missing item no.", 12, 0.50, 12, "sales"),
    "SALES_LINES_ZERO_QUANTITY": ImpactProfile("Sales lines with zero quantity", 8, 0.40, 12, "sales"),
    "SALES_LINES_ZERO_PRICE": ImpactProfile("Sales lines with zero price", 15, 0.70, 12, "sales"),
    "SALES_LINES_MISSING_DIMENSIONS": ImpactProfile("Sales lines missing dimensions", 5, 0.25, 12, "sales"),
    "SALES_DOCS_WITH_BLOCKED_CUSTOMERS": ImpactProfile("Sales docs with blocked customers", 15, 0.50, 12, "sales"),
    "SALES_LINES_WITH_BLOCKED_ITEMS": ImpactProfile("Sales lines with blocked items", 14, 0.50, 12, "sales"),
    "PURCHASE_ORDERS_OLD_OPEN": ImpactProfile("Old open purchase orders", 10, 0.40, 12, "purchasing"),
    "PURCHASE_ORDERS_MISSING_EXPECTED_DATE": ImpactProfile("Purchase orders missing expected date", 7, 0.30, 12, "purchasing"),
    "PURCHASE_LINES_MISSING_NO": ImpactProfile("Purchase lines missing item no.", 12, 0.50, 12, "purchasing"),
    "PURCHASE_LINES_ZERO_QUANTITY": ImpactProfile("Purchase lines with zero quantity", 8, 0.40, 12, "purchasing"),
    "PURCHASE_LINES_ZERO_COST": ImpactProfile("Purchase lines with zero cost", 14, 0.65, 12, "purchasing"),
    "PURCHASE_LINES_MISSING_DIMENSIONS": ImpactProfile("Purchase lines missing dimensions", 5, 0.25, 12, "purchasing"),
    "PURCHASE_DOCS_WITH_BLOCKED_VENDORS": ImpactProfile("Purchase docs with blocked vendors", 15, 0.50, 12, "purchasing"),
    "PURCHASE_LINES_WITH_BLOCKED_ITEMS": ImpactProfile("Purchase lines with blocked items", 14, 0.50, 12, "purchasing"),
    "BLOCKED_CUSTOMERS_WITH_OPEN_SALES_DOCS": ImpactProfile("Blocked customers with open sales docs", 18, 0.50, 12, "customers"),
    "BLOCKED_CUSTOMERS_WITH_OPEN_LEDGER": ImpactProfile("Blocked customers with open ledger", 22, 0.60, 12, "finance"),
    "BLOCKED_VENDORS_WITH_OPEN_PURCHASE_DOCS": ImpactProfile("Blocked vendors with open purchase docs", 18, 0.50, 12, "vendors"),
    "BLOCKED_VENDORS_WITH_OPEN_LEDGER": ImpactProfile("Blocked vendors with open ledger", 22, 0.60, 12, "finance"),
    "CUSTOMER_LEDGER_OVERDUE_30": ImpactProfile("Customer ledger overdue 30 days", 16, 0.35, 12, "finance"),
    "VENDOR_LEDGER_OVERDUE_30": ImpactProfile("Vendor ledger overdue 30 days", 16, 0.35, 12, "finance"),
}


def _safe_float(value: object, default: float) -> float:
    try:
        return float(value if value is not None else default)
    except (TypeError, ValueError):
        return default


def _clamp(value: float, minimum: float, maximum: float) -> float:
    return max(minimum, min(maximum, value))


def _heuristic_profile(issue_code: str) -> ImpactProfile:
    code = (issue_code or "").upper()

    if "DUPLICATE" in code:
        return ImpactProfile(issue_code, 20, 0.30, 12)
    if "ZERO_PRICE" in code or "WITHOUT_UNIT_PRICE" in code:
        return ImpactProfile(issue_code, 15, 0.70, 12)
    if "ZERO_COST" in code or "WITHOUT_UNIT_COST" in code:
        return ImpactProfile(issue_code, 14, 0.60, 12)
    if "NEGATIVE_INVENTORY" in code:
        return ImpactProfile(issue_code, 20, 0.60, 12)
    if "PAYMENT" in code:
        return ImpactProfile(issue_code, 8, 0.30, 12)
    if "POSTING" in code:
        return ImpactProfile(issue_code, 10, 0.40, 12)
    if "BANK_ACCOUNT" in code:
        return ImpactProfile(issue_code, 12, 0.55, 12)
    if "EMAIL" in code:
        return ImpactProfile(issue_code, 3, 0.30, 12)
    if "PHONE" in code:
        return ImpactProfile(issue_code, 2, 0.20, 12)
    if "ADDRESS" in code or "CITY" in code or "POST_CODE" in code or "POSTCODE" in code:
        return ImpactProfile(issue_code, 4, 0.25, 8)

    return ImpactProfile(issue_code, 5, 0.20, 12)


def ensure_default_impact_profiles(db) -> None:
    for code, profile in DEFAULT_ISSUE_IMPACT_PROFILES.items():
        existing = db.get(IssueImpactConfig, code)
        if existing is None:
            db.add(
                IssueImpactConfig(
                    code=code,
                    title=profile.title,
                    minutes_per_occurrence=profile.minutes_per_occurrence,
                    probability=profile.probability,
                    frequency_per_year=profile.frequency_per_year,
                    category=profile.category,
                    is_active=True,
                )
            )

    if db.get(ImpactSettingsConfig, "default_hourly_rate_eur") is None:
        db.add(ImpactSettingsConfig(key="default_hourly_rate_eur", decimal_value=DEFAULT_HOURLY_RATE_EUR))
    if db.get(ImpactSettingsConfig, "potential_saving_factor") is None:
        db.add(ImpactSettingsConfig(key="potential_saving_factor", decimal_value=DEFAULT_POTENTIAL_SAVING_FACTOR))

    db.commit()


def get_hourly_rate(db) -> float:
    setting = db.get(ImpactSettingsConfig, "default_hourly_rate_eur")
    return round(_safe_float(getattr(setting, "decimal_value", None), DEFAULT_HOURLY_RATE_EUR), 2)


def get_potential_saving_factor(db) -> float:
    setting = db.get(ImpactSettingsConfig, "potential_saving_factor")
    return _clamp(_safe_float(getattr(setting, "decimal_value", None), DEFAULT_POTENTIAL_SAVING_FACTOR), 0.0, 1.0)


def _load_profile_row_map(db) -> dict[str, IssueImpactConfig]:
    rows: Iterable[IssueImpactConfig] = (
        db.query(IssueImpactConfig)
        .filter(IssueImpactConfig.is_active.is_(True))
        .all()
    )
    return {row.code: row for row in rows}


def get_issue_impact_definition_map(db) -> dict[str, dict[str, float | str]]:
    row_map = _load_profile_row_map(db)
    result: dict[str, dict[str, float | str]] = {}

    for code, profile in DEFAULT_ISSUE_IMPACT_PROFILES.items():
        row = row_map.get(code)
        if row is None:
            result[code] = {
                "title": profile.title,
                "minutes_per_occurrence": profile.minutes_per_occurrence,
                "probability": profile.probability,
                "frequency_per_year": profile.frequency_per_year,
                "category": profile.category,
            }
        else:
            result[code] = {
                "title": row.title or profile.title,
                "minutes_per_occurrence": _safe_float(row.minutes_per_occurrence, profile.minutes_per_occurrence),
                "probability": _clamp(_safe_float(row.probability, profile.probability), 0.0, 1.0),
                "frequency_per_year": max(_safe_float(row.frequency_per_year, profile.frequency_per_year), 0.0),
                "category": row.category or profile.category,
            }

    for code, row in row_map.items():
        if code not in result:
            fallback = _heuristic_profile(code)
            result[code] = {
                "title": row.title or fallback.title,
                "minutes_per_occurrence": _safe_float(row.minutes_per_occurrence, fallback.minutes_per_occurrence),
                "probability": _clamp(_safe_float(row.probability, fallback.probability), 0.0, 1.0),
                "frequency_per_year": max(_safe_float(row.frequency_per_year, fallback.frequency_per_year), 0.0),
                "category": row.category or fallback.category,
            }

    return result


def calculate_issue_impact(
    issue_code: str,
    affected_count: int,
    definition_map: dict[str, dict[str, float | str]],
    hourly_rate_eur: float,
) -> float:
    count = max(int(affected_count or 0), 0)
    if count <= 0:
        return 0.0

    definition = definition_map.get(issue_code)
    if definition is None:
        profile = _heuristic_profile(issue_code)
        minutes_per_occurrence = profile.minutes_per_occurrence
        probability = profile.probability
        frequency_per_year = profile.frequency_per_year
    else:
        minutes_per_occurrence = _safe_float(definition.get("minutes_per_occurrence"), 5.0)
        probability = _clamp(_safe_float(definition.get("probability"), 0.20), 0.0, 1.0)
        frequency_per_year = max(_safe_float(definition.get("frequency_per_year"), 12.0), 0.0)

    impact = count * probability * (minutes_per_occurrence / 60.0) * max(hourly_rate_eur, 0.0) * frequency_per_year
    return round(impact, 2)


def calculate_scan_commercials(
    issues: list[tuple[str, int]],
    total_records: int,
    premium_price_monthly: float,
    db,
) -> dict[str, float]:
    definition_map = get_issue_impact_definition_map(db)
    hourly_rate_eur = get_hourly_rate(db)
    estimated_loss = round(
        sum(
            calculate_issue_impact(code, affected_count, definition_map, hourly_rate_eur)
            for code, affected_count in issues
        ),
        2,
    )
    potential_saving_factor = get_potential_saving_factor(db)
    potential_saving = round(estimated_loss * potential_saving_factor, 2)
    roi_eur = round(potential_saving - (max(premium_price_monthly, 0.0) * 12), 2)

    return {
        "hourly_rate_eur": hourly_rate_eur,
        "estimated_loss_eur": estimated_loss,
        "potential_saving_eur": potential_saving,
        "roi_eur": roi_eur,
        "potential_saving_factor": potential_saving_factor,
        "total_records": max(int(total_records or 0), 0),
    }
