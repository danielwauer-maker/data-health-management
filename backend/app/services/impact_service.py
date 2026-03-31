from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable

from app.models import ImpactSettingsConfig, IssueImpactConfig

DEFAULT_HOURLY_RATE_EUR = 50.0
DEFAULT_POTENTIAL_SAVING_FACTOR = 0.7


@dataclass(frozen=True)
class ImpactDefinition:
    title: str
    category: str
    minutes_per_occurrence: float
    probability: float
    frequency_per_year: float


EXPLICIT_ISSUE_IMPACTS: dict[str, ImpactDefinition] = {
    "BLOCKED_CUSTOMERS_WITH_OPEN_LEDGER": ImpactDefinition("Blocked customers with open ledger", "customers", 22, 0.60, 12),
    "BLOCKED_VENDORS_WITH_OPEN_LEDGER": ImpactDefinition("Blocked vendors with open ledger", "vendors", 22, 0.60, 12),
    "BLOCKED_CUSTOMERS_WITH_OPEN_SALES_DOCS": ImpactDefinition("Blocked customers with open sales docs", "sales", 18, 0.50, 12),
    "BLOCKED_VENDORS_WITH_OPEN_PURCHASE_DOCS": ImpactDefinition("Blocked vendors with open purchase docs", "purchase", 18, 0.50, 12),
    "BLOCKED_ITEMS_WITH_INVENTORY": ImpactDefinition("Blocked items with inventory", "items", 14, 0.50, 12),
    "PURCHASE_LINES_WITH_BLOCKED_ITEMS": ImpactDefinition("Purchase lines with blocked items", "general", 14, 0.50, 12),
    "SALES_LINES_WITH_BLOCKED_ITEMS": ImpactDefinition("Sales lines with blocked items", "general", 14, 0.50, 12),
    "CUSTOMERS_DUPLICATE_EMAIL": ImpactDefinition("Customers duplicate email", "general", 18, 0.25, 12),
    "VENDORS_DUPLICATE_EMAIL": ImpactDefinition("Vendors duplicate email", "general", 18, 0.25, 12),
    "CUSTOMERS_DUPLICATE_NAME_POST_CITY": ImpactDefinition("Customers duplicate name/post/city", "general", 25, 0.25, 12),
    "VENDORS_DUPLICATE_NAME_POST_CITY": ImpactDefinition("Vendors duplicate name/post/city", "general", 25, 0.25, 12),
    "CUSTOMERS_DUPLICATE_NAME_POST_CODE_CITY": ImpactDefinition("Customers duplicate name/post code/city", "general", 25, 0.25, 12),
    "VENDORS_DUPLICATE_NAME_POST_CODE_CITY": ImpactDefinition("Vendors duplicate name/post code/city", "general", 25, 0.25, 12),
    "CUSTOMERS_DUPLICATE_VAT": ImpactDefinition("Customers duplicate VAT", "general", 30, 0.35, 12),
    "VENDORS_DUPLICATE_VAT": ImpactDefinition("Vendors duplicate VAT", "general", 30, 0.35, 12),
    "CUSTOMERS_MISSING_ADDRESS": ImpactDefinition("Customers missing address", "general", 6, 0.35, 8),
    "VENDORS_MISSING_ADDRESS": ImpactDefinition("Vendors missing address", "general", 6, 0.35, 8),
    "CUSTOMERS_MISSING_CITY": ImpactDefinition("Customers missing city", "general", 4, 0.25, 8),
    "VENDORS_MISSING_CITY": ImpactDefinition("Vendors missing city", "general", 4, 0.25, 8),
    "CUSTOMERS_MISSING_COUNTRY": ImpactDefinition("Customers missing country", "general", 4, 0.20, 8),
    "CUSTOMERS_MISSING_COUNTRY_CODE": ImpactDefinition("Customers missing country code", "general", 4, 0.20, 8),
    "VENDORS_MISSING_COUNTRY": ImpactDefinition("Vendors missing country", "general", 4, 0.20, 8),
    "VENDORS_MISSING_COUNTRY_CODE": ImpactDefinition("Vendors missing country code", "general", 4, 0.20, 8),
    "CUSTOMERS_MISSING_CUSTOMER_POSTING_GROUP": ImpactDefinition("Customers missing customer posting group", "general", 12, 0.45, 12),
    "CUSTOMERS_MISSING_POSTING_GROUP": ImpactDefinition("Customers missing posting group", "general", 12, 0.45, 12),
    "VENDORS_MISSING_VENDOR_POSTING_GROUP": ImpactDefinition("Vendors missing vendor posting group", "general", 12, 0.45, 12),
    "VENDORS_MISSING_POSTING_GROUP": ImpactDefinition("Vendors missing posting group", "general", 12, 0.45, 12),
    "CUSTOMERS_MISSING_EMAIL": ImpactDefinition("Customers missing email", "general", 3, 0.30, 12),
    "VENDORS_MISSING_EMAIL": ImpactDefinition("Vendors missing email", "general", 3, 0.30, 12),
    "CUSTOMERS_MISSING_GEN_BUS_POSTING": ImpactDefinition("Customers missing gen. bus. posting", "general", 10, 0.40, 12),
    "CUSTOMERS_MISSING_GEN_BUS_POSTING_GROUP": ImpactDefinition("Customers missing gen. bus. posting group", "general", 10, 0.40, 12),
    "VENDORS_MISSING_GEN_BUS_POSTING": ImpactDefinition("Vendors missing gen. bus. posting", "general", 10, 0.40, 12),
    "VENDORS_MISSING_GEN_BUS_POSTING_GROUP": ImpactDefinition("Vendors missing gen. bus. posting group", "general", 10, 0.40, 12),
    "CUSTOMERS_MISSING_NAME": ImpactDefinition("Customers missing name", "general", 8, 0.60, 12),
    "VENDORS_MISSING_NAME": ImpactDefinition("Vendors missing name", "general", 8, 0.60, 12),
    "CUSTOMERS_MISSING_PAYMENT_METHOD": ImpactDefinition("Customers missing payment method", "general", 7, 0.30, 12),
    "VENDORS_MISSING_PAYMENT_METHOD": ImpactDefinition("Vendors missing payment method", "general", 7, 0.28, 12),
    "CUSTOMERS_MISSING_PAYMENT_TERMS": ImpactDefinition("Customers missing payment terms", "general", 10, 0.30, 12),
    "VENDORS_MISSING_PAYMENT_TERMS": ImpactDefinition("Vendors missing payment terms", "general", 9, 0.30, 12),
    "CUSTOMERS_MISSING_PHONE": ImpactDefinition("Customers missing phone", "general", 2, 0.20, 12),
    "CUSTOMERS_MISSING_PHONE_NO": ImpactDefinition("Customers missing phone no.", "general", 2, 0.20, 12),
    "VENDORS_MISSING_PHONE": ImpactDefinition("Vendors missing phone", "general", 2, 0.20, 12),
    "VENDORS_MISSING_PHONE_NO": ImpactDefinition("Vendors missing phone no.", "general", 2, 0.20, 12),
    "CUSTOMERS_MISSING_POST_CODE": ImpactDefinition("Customers missing post code", "general", 4, 0.25, 8),
    "CUSTOMERS_MISSING_POSTCODE": ImpactDefinition("Customers missing postcode", "general", 4, 0.25, 8),
    "VENDORS_MISSING_POST_CODE": ImpactDefinition("Vendors missing post code", "general", 4, 0.25, 8),
    "VENDORS_MISSING_POSTCODE": ImpactDefinition("Vendors missing postcode", "general", 4, 0.25, 8),
    "CUSTOMERS_MISSING_SEARCH_NAME": ImpactDefinition("Customers missing search name", "general", 2, 0.20, 12),
    "VENDORS_MISSING_SEARCH_NAME": ImpactDefinition("Vendors missing search name", "general", 2, 0.20, 12),
    "CUSTOMERS_MISSING_VAT_BUS_POSTING": ImpactDefinition("Customers missing VAT bus. posting", "general", 10, 0.40, 12),
    "CUSTOMERS_MISSING_VAT_BUS_POSTING_GROUP": ImpactDefinition("Customers missing VAT bus. posting group", "general", 10, 0.40, 12),
    "VENDORS_MISSING_VAT_BUS_POSTING": ImpactDefinition("Vendors missing VAT bus. posting", "general", 10, 0.40, 12),
    "VENDORS_MISSING_VAT_BUS_POSTING_GROUP": ImpactDefinition("Vendors missing VAT bus. posting group", "general", 10, 0.40, 12),
    "CUSTOMERS_MISSING_VAT_REG_NO": ImpactDefinition("Customers missing VAT reg. no.", "general", 15, 0.40, 12),
    "CUSTOMER_LEDGER_OVERDUE_30": ImpactDefinition("Customer ledger overdue 30", "general", 16, 0.35, 12),
    "VENDOR_LEDGER_OVERDUE_30": ImpactDefinition("Vendor ledger overdue 30", "general", 16, 0.35, 12),
    "ITEMS_MISSING_BASE_UOM": ImpactDefinition("Items missing base UOM", "general", 7, 0.35, 12),
    "ITEMS_MISSING_BASE_UNIT": ImpactDefinition("Items missing base unit", "general", 7, 0.35, 12),
    "ITEMS_MISSING_CATEGORY": ImpactDefinition("Items missing category", "general", 4, 0.20, 12),
    "ITEMS_MISSING_DESCRIPTION": ImpactDefinition("Items missing description", "general", 2, 0.15, 24),
    "ITEMS_MISSING_GEN_PROD_POSTING": ImpactDefinition("Items missing gen. prod. posting", "general", 10, 0.45, 12),
    "ITEMS_MISSING_GEN_PROD_POSTING_GROUP": ImpactDefinition("Items missing gen. prod. posting group", "general", 10, 0.45, 12),
    "ITEMS_MISSING_INVENTORY_POSTING": ImpactDefinition("Items missing inventory posting", "general", 12, 0.45, 12),
    "ITEMS_MISSING_INVENTORY_POSTING_GROUP": ImpactDefinition("Items missing inventory posting group", "general", 12, 0.45, 12),
    "ITEMS_MISSING_VAT_PROD_POSTING_GROUP": ImpactDefinition("Items missing VAT prod. posting group", "general", 9, 0.35, 12),
    "ITEMS_WITHOUT_VENDOR_NO": ImpactDefinition("Items without vendor no.", "general", 4, 0.20, 12),
    "ITEMS_MISSING_VENDOR_NO": ImpactDefinition("Items missing vendor no.", "general", 4, 0.20, 12),
    "ITEMS_NEGATIVE_INVENTORY": ImpactDefinition("Items negative inventory", "general", 20, 0.60, 12),
    "ITEMS_WITHOUT_UNIT_COST": ImpactDefinition("Items without unit cost", "general", 12, 0.60, 12),
    "ITEMS_WITHOUT_UNIT_PRICE": ImpactDefinition("Items without unit price", "general", 12, 0.70, 12),
    "PURCHASE_DOCS_WITH_BLOCKED_VENDORS": ImpactDefinition("Purchase docs with blocked vendors", "general", 15, 0.50, 12),
    "SALES_DOCS_WITH_BLOCKED_CUSTOMERS": ImpactDefinition("Sales docs with blocked customers", "general", 15, 0.50, 12),
    "PURCHASE_LINES_MISSING_DIMENSIONS": ImpactDefinition("Purchase lines missing dimensions", "general", 5, 0.25, 12),
    "SALES_LINES_MISSING_DIMENSIONS": ImpactDefinition("Sales lines missing dimensions", "general", 5, 0.25, 12),
    "PURCHASE_LINES_MISSING_NO": ImpactDefinition("Purchase lines missing no.", "general", 12, 0.50, 12),
    "SALES_LINES_MISSING_NO": ImpactDefinition("Sales lines missing no.", "general", 12, 0.50, 12),
    "PURCHASE_LINES_ZERO_COST": ImpactDefinition("Purchase lines zero cost", "general", 14, 0.65, 12),
    "SALES_LINES_ZERO_PRICE": ImpactDefinition("Sales lines zero price", "general", 15, 0.70, 12),
    "PURCHASE_LINES_ZERO_QUANTITY": ImpactDefinition("Purchase lines zero quantity", "general", 8, 0.40, 12),
    "SALES_LINES_ZERO_QUANTITY": ImpactDefinition("Sales lines zero quantity", "general", 8, 0.40, 12),
    "PURCHASE_ORDERS_MISSING_EXPECTED_DATE": ImpactDefinition("Purchase orders missing expected date", "general", 7, 0.30, 12),
    "PURCHASE_ORDERS_OLD_OPEN": ImpactDefinition("Purchase orders old open", "general", 10, 0.40, 12),
    "SALES_ORDERS_OLD_OPEN": ImpactDefinition("Sales orders old open", "general", 10, 0.40, 12),
    "SALES_ORDERS_MISSING_SHIPMENT_DATE": ImpactDefinition("Sales orders missing shipment date", "general", 8, 0.35, 12),
    "VENDORS_MISSING_BANK_ACCOUNT": ImpactDefinition("Vendors missing bank account", "general", 12, 0.55, 12),
}


def _normalize_code(code: str) -> str:
    return str(code or "").strip().upper()


def _infer_category(code: str) -> str:
    normalized = _normalize_code(code)
    if normalized.startswith("CUSTOMER") or normalized.startswith("CUSTOMERS"):
        return "customers"
    if normalized.startswith("VENDOR") or normalized.startswith("VENDORS"):
        return "vendors"
    if normalized.startswith("ITEM") or normalized.startswith("ITEMS"):
        return "items"
    if normalized.startswith("SALES"):
        return "sales"
    if normalized.startswith("PURCHASE"):
        return "purchase"
    if "LEDGER" in normalized:
        return "finance"
    return "general"

def clamp_potential_saving_factor(value: float) -> float:
    try:
        value = float(value)
    except (TypeError, ValueError):
        value = DEFAULT_POTENTIAL_SAVING_FACTOR

    if value < 0:
        return 0.0
    if value > 1:
        return 1.0
    return value


def normalize_commercials(
    estimated_loss_eur: float,
    potential_saving_factor: float,
    estimated_premium_price_monthly: float,
) -> tuple[float, float, float]:
    estimated_loss_eur = max(0.0, round(float(estimated_loss_eur or 0.0), 2))
    estimated_premium_price_monthly = max(0.0, round(float(estimated_premium_price_monthly or 0.0), 2))

    factor = clamp_potential_saving_factor(potential_saving_factor)
    potential_saving_eur = round(estimated_loss_eur * factor, 2)
    potential_saving_eur = min(potential_saving_eur, estimated_loss_eur)

    roi_eur = round(potential_saving_eur - (estimated_premium_price_monthly * 12), 2)
    return estimated_loss_eur, potential_saving_eur, roi_eur


def _fallback_definition(code: str) -> ImpactDefinition:
    normalized = _normalize_code(code)
    if "DUPLICATE" in normalized:
        return ImpactDefinition(normalized, _infer_category(normalized), 20, 0.25, 12)
    if "ZERO_PRICE" in normalized or "WITHOUT_UNIT_PRICE" in normalized:
        return ImpactDefinition(normalized, _infer_category(normalized), 15, 0.70, 12)
    if "ZERO_COST" in normalized or "WITHOUT_UNIT_COST" in normalized:
        return ImpactDefinition(normalized, _infer_category(normalized), 14, 0.65, 12)
    if "NEGATIVE_INVENTORY" in normalized or "BLOCKED_" in normalized:
        return ImpactDefinition(normalized, _infer_category(normalized), 18, 0.50, 12)
    if "PAYMENT" in normalized or "POSTING" in normalized:
        return ImpactDefinition(normalized, _infer_category(normalized), 10, 0.40, 12)
    if "EMAIL" in normalized:
        return ImpactDefinition(normalized, _infer_category(normalized), 3, 0.30, 12)
    if "PHONE" in normalized:
        return ImpactDefinition(normalized, _infer_category(normalized), 2, 0.20, 12)
    if "ADDRESS" in normalized or "POST_CODE" in normalized or "POSTCODE" in normalized:
        return ImpactDefinition(normalized, _infer_category(normalized), 4, 0.25, 8)
    return ImpactDefinition(normalized, _infer_category(normalized), 5, 0.20, 12)


def ensure_default_impact_config(db) -> None:
    for code, definition in EXPLICIT_ISSUE_IMPACTS.items():
        existing = db.get(IssueImpactConfig, code)
        if existing is None:
            db.add(
                IssueImpactConfig(
                    code=code,
                    title=definition.title,
                    category=definition.category or _infer_category(code),
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
        return clamp_potential_saving_factor(DEFAULT_POTENTIAL_SAVING_FACTOR)
    return clamp_potential_saving_factor(float(row.value_number or DEFAULT_POTENTIAL_SAVING_FACTOR))


def get_impact_definition(db, issue_code: str) -> ImpactDefinition:
    normalized = _normalize_code(issue_code)
    row = db.get(IssueImpactConfig, normalized)
    if row is not None and bool(row.is_active):
        return ImpactDefinition(
            title=row.title or normalized,
            category=getattr(row, "category", None) or _infer_category(normalized),
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


def calculate_scan_commercials(
    db,
    *,
    issues: Iterable[object],
    total_records: int,
    supplied_estimated_loss_eur: float = 0.0,
    supplied_estimated_premium_price_monthly: float = 0.0,
    pricing=None,
) -> dict[str, object]:
    from app.services.pricing_service import calculate_monthly_price, get_license_pricing

    total_records = max(int(total_records or 0), 0)

    recalculated_issues = calculate_issue_impacts(db, issues)
    estimated_loss_eur = round(
        sum(float(issue["estimated_impact_eur"]) for issue in recalculated_issues), 2
    )

    supplied_estimated_loss_eur = max(float(supplied_estimated_loss_eur or 0.0), 0.0)
    if supplied_estimated_loss_eur > 0 and not recalculated_issues:
        estimated_loss_eur = round(supplied_estimated_loss_eur, 2)

    if pricing is None:
        pricing = get_license_pricing(db, "premium")

    estimated_premium_price_monthly = max(
        float(supplied_estimated_premium_price_monthly or 0.0), 0.0
    )
    if estimated_premium_price_monthly <= 0:
        estimated_premium_price_monthly = round(
            calculate_monthly_price(total_records, pricing), 2
        )

    estimated_loss_eur, potential_saving_eur, roi_eur = normalize_commercials(
        estimated_loss_eur=estimated_loss_eur,
        potential_saving_factor=get_potential_saving_factor(db),
        estimated_premium_price_monthly=estimated_premium_price_monthly,
    )

    return {
        "total_records": total_records,
        "estimated_loss_eur": estimated_loss_eur,
        "potential_saving_eur": potential_saving_eur,
        "estimated_premium_price_monthly": estimated_premium_price_monthly,
        "roi_eur": roi_eur,
        "issues": recalculated_issues,
    }


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
