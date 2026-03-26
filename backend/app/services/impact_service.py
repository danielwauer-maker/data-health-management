from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable

from app.models import ImpactSettingsConfig, IssueImpactConfig

DEFAULT_HOURLY_RATE_EUR = 50.0
DEFAULT_POTENTIAL_SAVING_FACTOR = 0.7


@dataclass(frozen=True)
class ImpactDefinition:
    title: str
    minutes_per_occurrence: float
    probability: float
    frequency_per_year: float


EXPLICIT_ISSUE_IMPACTS: dict[str, ImpactDefinition] = {
    "BLOCKED_CUSTOMERS_WITH_OPEN_LEDGER": ImpactDefinition("Blocked customers with open ledger", 22, 0.60, 12),
    "BLOCKED_VENDORS_WITH_OPEN_LEDGER": ImpactDefinition("Blocked vendors with open ledger", 22, 0.60, 12),
    "BLOCKED_CUSTOMERS_WITH_OPEN_SALES_DOCS": ImpactDefinition("Blocked customers with open sales docs", 18, 0.50, 12),
    "BLOCKED_VENDORS_WITH_OPEN_PURCHASE_DOCS": ImpactDefinition("Blocked vendors with open purchase docs", 18, 0.50, 12),
    "BLOCKED_ITEMS_WITH_INVENTORY": ImpactDefinition("Blocked items with inventory", 14, 0.50, 12),
    "PURCHASE_LINES_WITH_BLOCKED_ITEMS": ImpactDefinition("Purchase lines with blocked items", 14, 0.50, 12),
    "SALES_LINES_WITH_BLOCKED_ITEMS": ImpactDefinition("Sales lines with blocked items", 14, 0.50, 12),
    "CUSTOMERS_DUPLICATE_EMAIL": ImpactDefinition("Customers duplicate email", 18, 0.25, 12),
    "VENDORS_DUPLICATE_EMAIL": ImpactDefinition("Vendors duplicate email", 18, 0.25, 12),
    "CUSTOMERS_DUPLICATE_NAME_POST_CITY": ImpactDefinition("Customers duplicate name/post/city", 25, 0.25, 12),
    "VENDORS_DUPLICATE_NAME_POST_CITY": ImpactDefinition("Vendors duplicate name/post/city", 25, 0.25, 12),
    "CUSTOMERS_DUPLICATE_NAME_POST_CODE_CITY": ImpactDefinition("Customers duplicate name/post code/city", 25, 0.25, 12),
    "VENDORS_DUPLICATE_NAME_POST_CODE_CITY": ImpactDefinition("Vendors duplicate name/post code/city", 25, 0.25, 12),
    "CUSTOMERS_DUPLICATE_VAT": ImpactDefinition("Customers duplicate VAT", 30, 0.35, 12),
    "VENDORS_DUPLICATE_VAT": ImpactDefinition("Vendors duplicate VAT", 30, 0.35, 12),
    "CUSTOMERS_MISSING_ADDRESS": ImpactDefinition("Customers missing address", 6, 0.35, 8),
    "VENDORS_MISSING_ADDRESS": ImpactDefinition("Vendors missing address", 6, 0.35, 8),
    "CUSTOMERS_MISSING_CITY": ImpactDefinition("Customers missing city", 4, 0.25, 8),
    "VENDORS_MISSING_CITY": ImpactDefinition("Vendors missing city", 4, 0.25, 8),
    "CUSTOMERS_MISSING_COUNTRY": ImpactDefinition("Customers missing country", 4, 0.20, 8),
    "CUSTOMERS_MISSING_COUNTRY_CODE": ImpactDefinition("Customers missing country code", 4, 0.20, 8),
    "VENDORS_MISSING_COUNTRY": ImpactDefinition("Vendors missing country", 4, 0.20, 8),
    "VENDORS_MISSING_COUNTRY_CODE": ImpactDefinition("Vendors missing country code", 4, 0.20, 8),
    "CUSTOMERS_MISSING_CUSTOMER_POSTING_GROUP": ImpactDefinition("Customers missing customer posting group", 12, 0.45, 12),
    "CUSTOMERS_MISSING_POSTING_GROUP": ImpactDefinition("Customers missing posting group", 12, 0.45, 12),
    "VENDORS_MISSING_VENDOR_POSTING_GROUP": ImpactDefinition("Vendors missing vendor posting group", 12, 0.45, 12),
    "VENDORS_MISSING_POSTING_GROUP": ImpactDefinition("Vendors missing posting group", 12, 0.45, 12),
    "CUSTOMERS_MISSING_EMAIL": ImpactDefinition("Customers missing email", 3, 0.30, 12),
    "VENDORS_MISSING_EMAIL": ImpactDefinition("Vendors missing email", 3, 0.30, 12),
    "CUSTOMERS_MISSING_GEN_BUS_POSTING": ImpactDefinition("Customers missing gen. bus. posting", 10, 0.40, 12),
    "CUSTOMERS_MISSING_GEN_BUS_POSTING_GROUP": ImpactDefinition("Customers missing gen. bus. posting group", 10, 0.40, 12),
    "VENDORS_MISSING_GEN_BUS_POSTING": ImpactDefinition("Vendors missing gen. bus. posting", 10, 0.40, 12),
    "VENDORS_MISSING_GEN_BUS_POSTING_GROUP": ImpactDefinition("Vendors missing gen. bus. posting group", 10, 0.40, 12),
    "CUSTOMERS_MISSING_NAME": ImpactDefinition("Customers missing name", 8, 0.60, 12),
    "VENDORS_MISSING_NAME": ImpactDefinition("Vendors missing name", 8, 0.60, 12),
    "CUSTOMERS_MISSING_PAYMENT_METHOD": ImpactDefinition("Customers missing payment method", 7, 0.30, 12),
    "VENDORS_MISSING_PAYMENT_METHOD": ImpactDefinition("Vendors missing payment method", 7, 0.28, 12),
    "CUSTOMERS_MISSING_PAYMENT_TERMS": ImpactDefinition("Customers missing payment terms", 10, 0.30, 12),
    "VENDORS_MISSING_PAYMENT_TERMS": ImpactDefinition("Vendors missing payment terms", 9, 0.30, 12),
    "CUSTOMERS_MISSING_PHONE": ImpactDefinition("Customers missing phone", 2, 0.20, 12),
    "CUSTOMERS_MISSING_PHONE_NO": ImpactDefinition("Customers missing phone no.", 2, 0.20, 12),
    "VENDORS_MISSING_PHONE": ImpactDefinition("Vendors missing phone", 2, 0.20, 12),
    "VENDORS_MISSING_PHONE_NO": ImpactDefinition("Vendors missing phone no.", 2, 0.20, 12),
    "CUSTOMERS_MISSING_POST_CODE": ImpactDefinition("Customers missing post code", 4, 0.25, 8),
    "CUSTOMERS_MISSING_POSTCODE": ImpactDefinition("Customers missing postcode", 4, 0.25, 8),
    "VENDORS_MISSING_POST_CODE": ImpactDefinition("Vendors missing post code", 4, 0.25, 8),
    "VENDORS_MISSING_POSTCODE": ImpactDefinition("Vendors missing postcode", 4, 0.25, 8),
    "CUSTOMERS_MISSING_SEARCH_NAME": ImpactDefinition("Customers missing search name", 2, 0.20, 12),
    "VENDORS_MISSING_SEARCH_NAME": ImpactDefinition("Vendors missing search name", 2, 0.20, 12),
    "CUSTOMERS_MISSING_VAT_BUS_POSTING": ImpactDefinition("Customers missing VAT bus. posting", 10, 0.40, 12),
    "CUSTOMERS_MISSING_VAT_BUS_POSTING_GROUP": ImpactDefinition("Customers missing VAT bus. posting group", 10, 0.40, 12),
    "VENDORS_MISSING_VAT_BUS_POSTING": ImpactDefinition("Vendors missing VAT bus. posting", 10, 0.40, 12),
    "VENDORS_MISSING_VAT_BUS_POSTING_GROUP": ImpactDefinition("Vendors missing VAT bus. posting group", 10, 0.40, 12),
    "CUSTOMERS_MISSING_VAT_REG_NO": ImpactDefinition("Customers missing VAT reg. no.", 15, 0.40, 12),
    "CUSTOMER_LEDGER_OVERDUE_30": ImpactDefinition("Customer ledger overdue 30", 16, 0.35, 12),
    "VENDOR_LEDGER_OVERDUE_30": ImpactDefinition("Vendor ledger overdue 30", 16, 0.35, 12),
    "ITEMS_MISSING_BASE_UOM": ImpactDefinition("Items missing base UOM", 7, 0.35, 12),
    "ITEMS_MISSING_BASE_UNIT": ImpactDefinition("Items missing base unit", 7, 0.35, 12),
    "ITEMS_MISSING_CATEGORY": ImpactDefinition("Items missing category", 4, 0.20, 12),
    "ITEMS_MISSING_DESCRIPTION": ImpactDefinition("Items missing description", 2, 0.15, 24),
    "ITEMS_MISSING_GEN_PROD_POSTING": ImpactDefinition("Items missing gen. prod. posting", 10, 0.45, 12),
    "ITEMS_MISSING_GEN_PROD_POSTING_GROUP": ImpactDefinition("Items missing gen. prod. posting group", 10, 0.45, 12),
    "ITEMS_MISSING_INVENTORY_POSTING": ImpactDefinition("Items missing inventory posting", 12, 0.45, 12),
    "ITEMS_MISSING_INVENTORY_POSTING_GROUP": ImpactDefinition("Items missing inventory posting group", 12, 0.45, 12),
    "ITEMS_MISSING_VAT_PROD_POSTING_GROUP": ImpactDefinition("Items missing VAT prod. posting group", 9, 0.35, 12),
    "ITEMS_WITHOUT_VENDOR_NO": ImpactDefinition("Items without vendor no.", 4, 0.20, 12),
    "ITEMS_MISSING_VENDOR_NO": ImpactDefinition("Items missing vendor no.", 4, 0.20, 12),
    "ITEMS_NEGATIVE_INVENTORY": ImpactDefinition("Items negative inventory", 20, 0.60, 12),
    "ITEMS_WITHOUT_UNIT_COST": ImpactDefinition("Items without unit cost", 12, 0.60, 12),
    "ITEMS_WITHOUT_UNIT_PRICE": ImpactDefinition("Items without unit price", 12, 0.70, 12),
    "PURCHASE_DOCS_WITH_BLOCKED_VENDORS": ImpactDefinition("Purchase docs with blocked vendors", 15, 0.50, 12),
    "SALES_DOCS_WITH_BLOCKED_CUSTOMERS": ImpactDefinition("Sales docs with blocked customers", 15, 0.50, 12),
    "PURCHASE_LINES_MISSING_DIMENSIONS": ImpactDefinition("Purchase lines missing dimensions", 5, 0.25, 12),
    "SALES_LINES_MISSING_DIMENSIONS": ImpactDefinition("Sales lines missing dimensions", 5, 0.25, 12),
    "PURCHASE_LINES_MISSING_NO": ImpactDefinition("Purchase lines missing no.", 12, 0.50, 12),
    "SALES_LINES_MISSING_NO": ImpactDefinition("Sales lines missing no.", 12, 0.50, 12),
    "PURCHASE_LINES_ZERO_COST": ImpactDefinition("Purchase lines zero cost", 14, 0.65, 12),
    "SALES_LINES_ZERO_PRICE": ImpactDefinition("Sales lines zero price", 15, 0.70, 12),
    "PURCHASE_LINES_ZERO_QUANTITY": ImpactDefinition("Purchase lines zero quantity", 8, 0.40, 12),
    "SALES_LINES_ZERO_QUANTITY": ImpactDefinition("Sales lines zero quantity", 8, 0.40, 12),
    "PURCHASE_ORDERS_MISSING_EXPECTED_DATE": ImpactDefinition("Purchase orders missing expected date", 7, 0.30, 12),
    "PURCHASE_ORDERS_OLD_OPEN": ImpactDefinition("Purchase orders old open", 10, 0.40, 12),
    "SALES_ORDERS_OLD_OPEN": ImpactDefinition("Sales orders old open", 10, 0.40, 12),
    "SALES_ORDERS_MISSING_SHIPMENT_DATE": ImpactDefinition("Sales orders missing shipment date", 8, 0.35, 12),
    "VENDORS_MISSING_BANK_ACCOUNT": ImpactDefinition("Vendors missing bank account", 12, 0.55, 12),
}


def _normalize_code(code: str) -> str:
    return str(code or "").strip().upper()


def _fallback_definition(code: str) -> ImpactDefinition:
    normalized = _normalize_code(code)
    if "DUPLICATE" in normalized:
        return ImpactDefinition(normalized, 20, 0.25, 12)
    if "ZERO_PRICE" in normalized or "WITHOUT_UNIT_PRICE" in normalized:
        return ImpactDefinition(normalized, 15, 0.70, 12)
    if "ZERO_COST" in normalized or "WITHOUT_UNIT_COST" in normalized:
        return ImpactDefinition(normalized, 14, 0.65, 12)
    if "NEGATIVE_INVENTORY" in normalized or "BLOCKED_" in normalized:
        return ImpactDefinition(normalized, 18, 0.50, 12)
    if "PAYMENT" in normalized or "POSTING" in normalized:
        return ImpactDefinition(normalized, 10, 0.40, 12)
    if "EMAIL" in normalized:
        return ImpactDefinition(normalized, 3, 0.30, 12)
    if "PHONE" in normalized:
        return ImpactDefinition(normalized, 2, 0.20, 12)
    if "ADDRESS" in normalized or "POST_CODE" in normalized or "POSTCODE" in normalized:
        return ImpactDefinition(normalized, 4, 0.25, 8)
    return ImpactDefinition(normalized, 5, 0.20, 12)


def ensure_default_impact_config(db) -> None:
    for code, definition in EXPLICIT_ISSUE_IMPACTS.items():
        existing = db.get(IssueImpactConfig, code)
        if existing is None:
            db.add(
                IssueImpactConfig(
                    code=code,
                    title=definition.title,
                    minutes_per_occurrence=definition.minutes_per_occurrence,
                    probability=definition.probability,
                    frequency_per_year=definition.frequency_per_year,
                    is_active=True,
                )
            )

    settings = {
        "default_hourly_rate_eur": (DEFAULT_HOURLY_RATE_EUR, "Default hourly rate (EUR)"),
        "potential_saving_factor": (DEFAULT_POTENTIAL_SAVING_FACTOR, "Potential saving factor"),
    }
    for key, (value, title) in settings.items():
        existing = db.get(ImpactSettingsConfig, key)
        if existing is None:
            db.add(ImpactSettingsConfig(key=key, value_number=value, title=title))

    db.commit()


def get_hourly_rate_eur(db) -> float:
    row = db.get(ImpactSettingsConfig, "default_hourly_rate_eur")
    if row is None:
        return DEFAULT_HOURLY_RATE_EUR
    return float(row.value_number or DEFAULT_HOURLY_RATE_EUR)


def get_potential_saving_factor(db) -> float:
    row = db.get(ImpactSettingsConfig, "potential_saving_factor")
    if row is None:
        return DEFAULT_POTENTIAL_SAVING_FACTOR
    return float(row.value_number or DEFAULT_POTENTIAL_SAVING_FACTOR)


def get_impact_definition(db, issue_code: str) -> ImpactDefinition:
    normalized = _normalize_code(issue_code)
    row = db.get(IssueImpactConfig, normalized)
    if row is not None and bool(row.is_active):
        return ImpactDefinition(
            title=row.title or normalized,
            minutes_per_occurrence=float(row.minutes_per_occurrence or 0.0),
            probability=float(row.probability or 0.0),
            frequency_per_year=float(row.frequency_per_year or 0.0),
        )
    explicit = EXPLICIT_ISSUE_IMPACTS.get(normalized)
    if explicit is not None:
        return explicit
    return _fallback_definition(normalized)


def calculate_issue_impact(db, issue_code: str, affected_count: int) -> float:
    count = max(int(affected_count or 0), 0)
    if count <= 0:
        return 0.0

    definition = get_impact_definition(db, issue_code)
    hourly_rate = get_hourly_rate_eur(db)
    impact_per_record = (definition.minutes_per_occurrence / 60.0) * definition.probability * definition.frequency_per_year * hourly_rate
    return round(count * impact_per_record, 2)


def calculate_issue_impacts(db, issues: Iterable[object]) -> list[dict[str, object]]:
    result: list[dict[str, object]] = []
    for issue in issues:
        code = _normalize_code(getattr(issue, "code", ""))
        definition = get_impact_definition(db, code)
        affected_count = max(int(getattr(issue, "affected_count", 0) or 0), 0)
        impact = calculate_issue_impact(db, code, affected_count)
        result.append(
            {
                "code": code,
                "title": getattr(issue, "title", "") or definition.title or code,
                "severity": (getattr(issue, "severity", "low") or "low").strip().lower(),
                "affected_count": affected_count,
                "premium_only": bool(getattr(issue, "premium_only", False)),
                "recommendation_preview": getattr(issue, "recommendation_preview", None),
                "estimated_impact_eur": impact,
                "minutes_per_occurrence": round(definition.minutes_per_occurrence, 2),
                "probability": round(definition.probability, 4),
                "frequency_per_year": round(definition.frequency_per_year, 2),
                "hourly_rate_eur": round(get_hourly_rate_eur(db), 2),
            }
        )
    return result
