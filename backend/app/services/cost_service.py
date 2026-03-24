from __future__ import annotations

from dataclasses import replace
from typing import Iterable, List, Tuple

from app.schemas.scan import ScanIssue

DEFAULT_ISSUE_COSTS_EUR: dict[str, float] = {
    "CUSTOMERS_MISSING_POSTCODE": 8.0,
    "CUSTOMERS_MISSING_PAYMENT_TERMS": 45.0,
    "CUSTOMERS_MISSING_COUNTRY_CODE": 8.0,
    "CUSTOMERS_MISSING_VAT_REG_NO": 20.0,
    "CUSTOMERS_MISSING_EMAIL": 6.0,
    "CUSTOMERS_MISSING_PHONE_NO": 4.0,
    "CUSTOMERS_MISSING_CUSTOMER_POSTING_GROUP": 35.0,
    "CUSTOMERS_MISSING_GEN_BUS_POSTING_GROUP": 30.0,
    "VENDORS_MISSING_PAYMENT_TERMS": 45.0,
    "VENDORS_MISSING_COUNTRY_CODE": 8.0,
    "VENDORS_MISSING_EMAIL": 6.0,
    "VENDORS_MISSING_PHONE_NO": 4.0,
    "VENDORS_MISSING_VENDOR_POSTING_GROUP": 35.0,
    "VENDORS_MISSING_GEN_BUS_POSTING_GROUP": 30.0,
    "ITEMS_MISSING_CATEGORY": 12.0,
    "ITEMS_MISSING_BASE_UNIT": 15.0,
    "ITEMS_MISSING_GEN_PROD_POSTING_GROUP": 25.0,
    "ITEMS_MISSING_INVENTORY_POSTING_GROUP": 25.0,
    "ITEMS_MISSING_VAT_PROD_POSTING_GROUP": 20.0,
    "ITEMS_MISSING_VENDOR_NO": 10.0,
}

DEFAULT_COST_PER_ISSUE_EUR = 10.0


def get_issue_cost_per_record(issue_code: str) -> float:
    return float(DEFAULT_ISSUE_COSTS_EUR.get((issue_code or "").upper(), DEFAULT_COST_PER_ISSUE_EUR))


def enrich_issues_with_costs(issues: Iterable[ScanIssue]) -> Tuple[List[ScanIssue], float]:
    enriched: List[ScanIssue] = []
    total_loss = 0.0

    for issue in issues:
        impact = round(issue.affected_count * get_issue_cost_per_record(issue.code), 2)
        total_loss += impact
        enriched.append(replace(issue, estimated_impact_eur=impact))

    return enriched, round(total_loss, 2)
