from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable


DEFAULT_COST_PER_ISSUE_EUR = 25.0

ISSUE_COST_MAP_EUR: dict[str, float] = {
    "CUSTOMERS_MISSING_NAME": 35.0,
    "CUSTOMERS_MISSING_SEARCH_NAME": 10.0,
    "CUSTOMERS_MISSING_ADDRESS": 15.0,
    "CUSTOMERS_MISSING_CITY": 12.0,
    "CUSTOMERS_MISSING_POST_CODE": 12.0,
    "CUSTOMERS_MISSING_POSTCODE": 12.0,
    "CUSTOMERS_MISSING_COUNTRY": 10.0,
    "CUSTOMERS_MISSING_COUNTRY_CODE": 10.0,
    "CUSTOMERS_MISSING_VAT_REG_NO": 35.0,
    "CUSTOMERS_MISSING_EMAIL": 8.0,
    "CUSTOMERS_MISSING_PHONE": 6.0,
    "CUSTOMERS_MISSING_PHONE_NO": 6.0,
    "CUSTOMERS_MISSING_PAYMENT_TERMS": 45.0,
    "CUSTOMERS_MISSING_PAYMENT_METHOD": 30.0,
    "CUSTOMERS_MISSING_POSTING_GROUP": 55.0,
    "CUSTOMERS_MISSING_CUSTOMER_POSTING_GROUP": 55.0,
    "CUSTOMERS_MISSING_GEN_BUS_POSTING": 45.0,
    "CUSTOMERS_MISSING_GEN_BUS_POSTING_GROUP": 45.0,
    "CUSTOMERS_MISSING_VAT_BUS_POSTING": 45.0,
    "CUSTOMERS_MISSING_CREDIT_LIMIT": 20.0,
    "BLOCKED_CUSTOMERS_WITH_OPEN_SALES_DOCS": 120.0,
    "BLOCKED_CUSTOMERS_WITH_OPEN_LEDGER": 150.0,
    "CUSTOMERS_DUPLICATE_EMAIL": 140.0,
    "CUSTOMERS_DUPLICATE_VAT": 220.0,
    "CUSTOMERS_DUPLICATE_NAME_POST_CITY": 160.0,
    "VENDORS_MISSING_NAME": 35.0,
    "VENDORS_MISSING_SEARCH_NAME": 10.0,
    "VENDORS_MISSING_ADDRESS": 15.0,
    "VENDORS_MISSING_CITY": 12.0,
    "VENDORS_MISSING_POST_CODE": 12.0,
    "VENDORS_MISSING_COUNTRY": 10.0,
    "VENDORS_MISSING_COUNTRY_CODE": 10.0,
    "VENDORS_MISSING_EMAIL": 8.0,
    "VENDORS_MISSING_PHONE": 6.0,
    "VENDORS_MISSING_PHONE_NO": 6.0,
    "VENDORS_MISSING_PAYMENT_TERMS": 40.0,
    "VENDORS_MISSING_PAYMENT_METHOD": 30.0,
    "VENDORS_MISSING_POSTING_GROUP": 55.0,
    "VENDORS_MISSING_VENDOR_POSTING_GROUP": 55.0,
    "VENDORS_MISSING_GEN_BUS_POSTING": 45.0,
    "VENDORS_MISSING_GEN_BUS_POSTING_GROUP": 45.0,
    "VENDORS_MISSING_VAT_BUS_POSTING": 45.0,
    "VENDORS_MISSING_BANK_ACCOUNT": 90.0,
    "BLOCKED_VENDORS_WITH_OPEN_PURCHASE_DOCS": 120.0,
    "BLOCKED_VENDORS_WITH_OPEN_LEDGER": 150.0,
    "VENDORS_DUPLICATE_EMAIL": 120.0,
    "VENDORS_DUPLICATE_VAT": 200.0,
    "VENDORS_DUPLICATE_NAME_POST_CITY": 140.0,
    "ITEMS_MISSING_DESCRIPTION": 12.0,
    "ITEMS_MISSING_BASE_UOM": 30.0,
    "ITEMS_MISSING_BASE_UNIT": 30.0,
    "ITEMS_MISSING_CATEGORY": 20.0,
    "ITEMS_MISSING_GEN_PROD_POSTING": 55.0,
    "ITEMS_MISSING_GEN_PROD_POSTING_GROUP": 55.0,
    "ITEMS_MISSING_INVENTORY_POSTING": 55.0,
    "ITEMS_MISSING_INVENTORY_POSTING_GROUP": 55.0,
    "ITEMS_MISSING_VAT_PROD_POSTING_GROUP": 45.0,
    "ITEMS_WITHOUT_VENDOR_NO": 18.0,
    "ITEMS_MISSING_VENDOR_NO": 18.0,
    "ITEMS_WITHOUT_UNIT_COST": 95.0,
    "ITEMS_WITHOUT_UNIT_PRICE": 110.0,
    "ITEMS_NEGATIVE_INVENTORY": 150.0,
    "BLOCKED_ITEMS_WITH_INVENTORY": 130.0,
    "SALES_ORDERS_MISSING_SHIPMENT_DATE": 40.0,
    "SALES_ORDERS_OLD_OPEN": 70.0,
    "SALES_LINES_MISSING_NO": 80.0,
    "SALES_LINES_ZERO_QUANTITY": 60.0,
    "SALES_LINES_ZERO_PRICE": 140.0,
    "SALES_LINES_MISSING_DIMENSIONS": 35.0,
    "SALES_DOCS_WITH_BLOCKED_CUSTOMERS": 120.0,
    "SALES_LINES_WITH_BLOCKED_ITEMS": 130.0,
    "PURCHASE_ORDERS_MISSING_EXPECTED_DATE": 35.0,
    "PURCHASE_ORDERS_OLD_OPEN": 70.0,
    "PURCHASE_LINES_MISSING_NO": 80.0,
    "PURCHASE_LINES_ZERO_QUANTITY": 60.0,
    "PURCHASE_LINES_ZERO_COST": 120.0,
    "PURCHASE_LINES_MISSING_DIMENSIONS": 35.0,
    "PURCHASE_DOCS_WITH_BLOCKED_VENDORS": 120.0,
    "PURCHASE_LINES_WITH_BLOCKED_ITEMS": 130.0,
    "CUSTOMER_LEDGER_OVERDUE_30": 90.0,
    "VENDOR_LEDGER_OVERDUE_30": 90.0,
}


@dataclass(frozen=True)
class CostedIssue:
    code: str
    affected_count: int


@dataclass(frozen=True)
class CostSummary:
    estimated_loss_eur: float
    potential_saving_eur: float


def get_cost_per_issue_eur(issue_code: str) -> float:
    normalized_code = (issue_code or "").strip().upper()
    if normalized_code in ISSUE_COST_MAP_EUR:
        return ISSUE_COST_MAP_EUR[normalized_code]

    if "DUPLICATE" in normalized_code:
        return 150.0
    if "ZERO_PRICE" in normalized_code or "WITHOUT_UNIT_PRICE" in normalized_code:
        return 120.0
    if "ZERO_COST" in normalized_code or "WITHOUT_UNIT_COST" in normalized_code:
        return 100.0
    if "NEGATIVE_INVENTORY" in normalized_code or "BLOCKED_" in normalized_code:
        return 130.0
    if "PAYMENT" in normalized_code or "POSTING" in normalized_code:
        return 45.0
    if "EMAIL" in normalized_code:
        return 8.0
    if "PHONE" in normalized_code:
        return 6.0
    if "ADDRESS" in normalized_code or "POST_CODE" in normalized_code or "POSTCODE" in normalized_code:
        return 12.0

    return DEFAULT_COST_PER_ISSUE_EUR


def calculate_issue_impact_eur(issue_code: str, affected_count: int) -> float:
    safe_affected_count = max(int(affected_count or 0), 0)
    return round(get_cost_per_issue_eur(issue_code) * safe_affected_count, 2)


def calculate_scan_cost_summary(issues: Iterable[CostedIssue]) -> CostSummary:
    estimated_loss = round(
        sum(calculate_issue_impact_eur(issue.code, issue.affected_count) for issue in issues),
        2,
    )
    return CostSummary(
        estimated_loss_eur=estimated_loss,
        potential_saving_eur=estimated_loss,
    )
