from __future__ import annotations

from typing import Iterable

from app.models import IssueCostConfig

DEFAULT_ISSUE_COSTS: dict[str, tuple[str, float]] = {
    "CUSTOMERS_MISSING_ADDRESS": ("Customers missing address", 15.0),
    "CUSTOMERS_MISSING_EMAIL": ("Customers missing email", 8.0),
    "CUSTOMERS_MISSING_PAYMENT_TERMS": ("Customers missing payment terms", 35.0),
    "CUSTOMERS_MISSING_PAYMENT_METHOD": ("Customers missing payment method", 35.0),
    "VENDORS_MISSING_ADDRESS": ("Vendors missing address", 15.0),
    "VENDORS_MISSING_PAYMENT_TERMS": ("Vendors missing payment terms", 35.0),
    "VENDORS_MISSING_PAYMENT_METHOD": ("Vendors missing payment method", 35.0),
    "VENDORS_MISSING_BANK_ACCOUNT": ("Vendors missing bank account", 55.0),
    "ITEMS_MISSING_BASE_UNIT": ("Items missing base unit", 25.0),
    "ITEMS_MISSING_INVENTORY_POSTING_GROUP": ("Items missing inventory posting group", 50.0),
    "ITEMS_MISSING_UNIT_PRICE": ("Items missing sales price", 65.0),
    "ITEMS_MISSING_UNIT_COST": ("Items missing unit cost", 75.0),
    "ITEMS_NEGATIVE_INVENTORY": ("Items with negative inventory", 95.0),
}


def ensure_default_issue_costs(db) -> None:
    for code, (title, cost_per_record) in DEFAULT_ISSUE_COSTS.items():
        existing = db.get(IssueCostConfig, code)
        if existing is None:
            db.add(
                IssueCostConfig(
                    code=code,
                    title=title,
                    cost_per_record=cost_per_record,
                    is_active=True,
                )
            )
    db.commit()


def get_issue_cost_map(db) -> dict[str, float]:
    rows: Iterable[IssueCostConfig] = db.query(IssueCostConfig).filter(IssueCostConfig.is_active.is_(True)).all()
    if not rows:
        return {code: cost for code, (_, cost) in DEFAULT_ISSUE_COSTS.items()}
    return {row.code: float(row.cost_per_record or 0.0) for row in rows}


def calculate_issue_impact(issue_code: str, affected_count: int, cost_map: dict[str, float]) -> float:
    count = max(int(affected_count or 0), 0)
    unit_cost = float(cost_map.get(issue_code, 10.0))
    return round(count * unit_cost, 2)
