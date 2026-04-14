from __future__ import annotations

import math
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import parse_qsl, quote, urlencode, urlparse, urlunparse

from fastapi import APIRouter, Cookie, Depends, HTTPException, Query, Request
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy import select

from app.core.settings import settings
from app.db import SessionLocal
from app.models import Scan, ScanIssueRecord, Tenant
from app.routers.billing import (
    BillingPortalRequest,
    CheckoutSessionRequest,
    create_billing_portal_session,
    create_checkout_session,
)
from app.security.tenant import (
    enforce_tenant_match,
    load_authenticated_tenant,
    require_tenant_headers,
)
from app.security.token import create_token, verify_token
from app.services.entitlement_guard_service import get_tenant_features, require_tenant_feature
from app.services.entitlement_service import is_premium_actions_enabled
from app.services.impact_service import normalize_stored_commercials
from app.services.pricing_service import (
    build_embed_pricing_breakdown,
    calculate_monthly_price,
    get_license_pricing,
)

router = APIRouter(tags=["analytics"])
TEMPLATES = Jinja2Templates(directory=str(Path(__file__).resolve().parent.parent / "templates"))
ANALYTICS_EMBED_COOKIE_NAME = "bcs_at"
ANALYTICS_EMBED_COOKIE_MAX_AGE_SECONDS = 15 * 60


def _safe_int(value: Any, default: int = 0) -> int:
    try:
        return int(value or default)
    except (TypeError, ValueError):
        return default


def _safe_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value or default)
    except (TypeError, ValueError):
        return default


def _normalize_severity(value: Any) -> str:
    text = str(value or "").strip().lower()
    if text in {"high", "medium", "low"}:
        return text
    return "low"


def _severity_rank(value: Any) -> int:
    severity = _normalize_severity(value)
    if severity == "high":
        return 0
    if severity == "medium":
        return 1
    return 2


def _normalize_plan(value: Any) -> str:
    plan = str(value or "").strip().lower()
    if plan in {"free", "standard", "premium"}:
        return "premium" if plan == "standard" else plan
    return "free"


def _issue_group_from_code(code: str) -> str:
    code_upper = (code or "").upper()

    # CRM
    if code_upper.startswith("CUSTOMERS_") or code_upper.startswith("CUSTOMER_"):
        return "CRM"

    # Purchasing
    if code_upper.startswith("VENDORS_") or code_upper.startswith("VENDOR_"):
        return "Purchasing"
    if code_upper.startswith("PURCHASE_") or code_upper.startswith("PURCH_"):
        return "Purchasing"

    # Inventory
    if code_upper.startswith("ITEMS_") or code_upper.startswith("ITEM_"):
        return "Inventory"
    if code_upper.startswith("INVENTORY_"):
        return "Inventory"
    if (
        code_upper.startswith("WAREHOUSE_")
        or code_upper.startswith("VALUE_ENTRY_")
        or code_upper.startswith("VALUE_ENTRIES_")
    ):
        return "Inventory"

    # Sales
    if code_upper.startswith("SALES_") or code_upper.startswith("SALE_"):
        return "Sales"

    # Finance
    if code_upper.startswith("GL_") or code_upper.startswith("G_L_") or "LEDGER" in code_upper:
        return "Finance"

    # Service
    if (
        code_upper.startswith("SERVICE_")
        or code_upper.startswith("SERV_")
        or code_upper.startswith("SERVICE_ITEM_")
    ):
        return "Service"

    # Jobs
    if code_upper.startswith("JOB_") or code_upper.startswith("JOBS_"):
        return "Jobs"

    # HR
    if (
        code_upper.startswith("HR_")
        or code_upper.startswith("EMPLOYEE_")
        or code_upper.startswith("EMPLOYEES_")
        or code_upper.startswith("RESOURCE_")
    ):
        return "HR"

    # Manufacturing
    if (
        code_upper.startswith("MFG_")
        or code_upper.startswith("MANUFACTURING_")
        or code_upper.startswith("PRODUCTION_")
        or code_upper.startswith("PROD_")
        or code_upper.startswith("BOM_")
        or code_upper.startswith("ROUTING_")
        or code_upper.startswith("WORKCENTER_")
        or code_upper.startswith("MACHINECENTER_")
    ):
        return "Manufacturing"

    # System
    if code_upper.startswith("SYSTEM_"):
        return "System"

    return "System"


def _normalize_issue_category(category: str | None, code: str) -> str:
    normalized = str(category or "").strip().upper()
    if normalized == "SYSTEM":
        return "System"
    if normalized == "FINANCE":
        return "Finance"
    if normalized == "SALES":
        return "Sales"
    if normalized in {"PURCHASE", "PURCHASING"}:
        return "Purchasing"
    if normalized in {"INVENTORY", "ITEM"}:
        return "Inventory"
    if normalized in {"CRM", "CUSTOMER"}:
        return "CRM"
    if normalized == "MANUFACTURING":
        return "Manufacturing"
    if normalized == "SERVICE":
        return "Service"
    if normalized in {"JOB", "JOBS"}:
        return "Jobs"
    if normalized == "HR":
        return "HR"
    return _issue_group_from_code(code)


def _issue_recommendation(issue: ScanIssueRecord) -> str:
    preview = (issue.recommendation_preview or "").strip()
    if preview:
        return preview

    group = _normalize_issue_category(getattr(issue, "category", None), issue.code)
    if group == "CRM":
        return "Review impacted customer and relationship data and complete the missing setup in Business Central."
    if group == "Purchasing":
        return "Resolve purchasing and vendor-related setup gaps before they create follow-up workload."
    if group == "Inventory":
        return "Prioritize inventory and item issues that affect planning, costing, or stock transactions."
    if group == "Sales":
        return "Resolve sales-side issues that can reduce margin, delay fulfillment, or create rework."
    if group == "Finance":
        return "Investigate financial postings and open entries with missing or inconsistent setup."
    if group == "Service":
        return "Review service-related records and complete the missing configuration before the next service cycle."
    if group == "Jobs":
        return "Review project and job-related records so postings and planning remain consistent."
    if group == "Manufacturing":
        return "Review manufacturing-related setup and master data before it impacts planning or execution."
    if group == "HR":
        return "Review HR-related configuration and records to avoid downstream process gaps."
    return "Review the affected records and resolve the underlying setup issue in Business Central."


def _build_open_in_bc_url(bc_issue_launch_url: str | None, issue_code: str | None) -> str:
    base_url = str(bc_issue_launch_url or "").strip()
    normalized_issue_code = str(issue_code or "").strip().upper()
    if not base_url or not normalized_issue_code:
        return ""

    direct_url = _build_direct_open_in_bc_url(base_url, normalized_issue_code)
    if direct_url:
        return direct_url

    separator = "&" if "?" in base_url else "?"
    filter_value = f"'Issue Drilldown Code' IS '{normalized_issue_code}'"
    return f"{base_url}{separator}filter={quote(filter_value, safe='')}"


def _replace_bc_page_url(base_url: str, page_id: int, filter_value: str | None = None) -> str:
    parsed = urlparse(base_url)
    query_items = [
        (key, value)
        for key, value in parse_qsl(parsed.query, keep_blank_values=True)
        if key.lower() not in {"page", "filter"}
    ]
    query_items.append(("page", str(page_id)))
    if filter_value:
        query_items.append(("filter", filter_value))

    return urlunparse(parsed._replace(query=urlencode(query_items, doseq=True)))


def _build_direct_open_in_bc_url(base_url: str, normalized_issue_code: str) -> str:
    customer_filters = {
        "CUSTOMERS_MISSING_NAME": "Name IS ''",
        "CUSTOMERS_MISSING_SEARCH_NAME": "'Search Name' IS ''",
        "CUSTOMERS_MISSING_ADDRESS": "Address IS ''",
        "CUSTOMERS_MISSING_CITY": "City IS ''",
        "CUSTOMERS_MISSING_POST_CODE": "'Post Code' IS ''",
        "CUSTOMERS_MISSING_COUNTRY": "'Country/Region Code' IS ''",
        "CUSTOMERS_MISSING_EMAIL": "'E-Mail' IS ''",
        "CUSTOMERS_MISSING_PHONE": "'Phone No.' IS ''",
        "CUSTOMERS_MISSING_PAYMENT_TERMS": "'Payment Terms Code' IS ''",
        "CUSTOMERS_MISSING_PAYMENT_METHOD": "'Payment Method Code' IS ''",
        "CUSTOMERS_MISSING_POSTING_GROUP": "'Customer Posting Group' IS ''",
        "CUSTOMERS_MISSING_GEN_BUS_POSTING": "'Gen. Bus. Posting Group' IS ''",
        "CUSTOMERS_MISSING_VAT_BUS_POSTING": "'VAT Bus. Posting Group' IS ''",
        "CUSTOMERS_MISSING_CREDIT_LIMIT": "'Credit Limit (LCY)' IS '0'",
    }
    vendor_filters = {
        "VENDORS_MISSING_NAME": "Name IS ''",
        "VENDORS_MISSING_SEARCH_NAME": "'Search Name' IS ''",
        "VENDORS_MISSING_ADDRESS": "Address IS ''",
        "VENDORS_MISSING_CITY": "City IS ''",
        "VENDORS_MISSING_POST_CODE": "'Post Code' IS ''",
        "VENDORS_MISSING_COUNTRY": "'Country/Region Code' IS ''",
        "VENDORS_MISSING_EMAIL": "'E-Mail' IS ''",
        "VENDORS_MISSING_PHONE": "'Phone No.' IS ''",
        "VENDORS_MISSING_PAYMENT_TERMS": "'Payment Terms Code' IS ''",
        "VENDORS_MISSING_PAYMENT_METHOD": "'Payment Method Code' IS ''",
        "VENDORS_MISSING_POSTING_GROUP": "'Vendor Posting Group' IS ''",
        "VENDORS_MISSING_GEN_BUS_POSTING": "'Gen. Bus. Posting Group' IS ''",
        "VENDORS_MISSING_VAT_BUS_POSTING": "'VAT Bus. Posting Group' IS ''",
        "VENDORS_MISSING_BANK_ACCOUNT": "'Preferred Bank Account Code' IS ''",
    }
    direct_page_ids = {
        "ITEMS_NEGATIVE_INVENTORY": 53136,
        "ITEMS_WITHOUT_UNIT_COST": 53137,
        "BLOCKED_ITEMS_WITH_INVENTORY": 53138,
        "ITEMS_WITHOUT_UNIT_PRICE": 53148,
    }

    if normalized_issue_code in customer_filters:
        return _replace_bc_page_url(base_url, 53156, customer_filters[normalized_issue_code])
    if normalized_issue_code in vendor_filters:
        return _replace_bc_page_url(base_url, 53157, vendor_filters[normalized_issue_code])
    if normalized_issue_code in direct_page_ids:
        return _replace_bc_page_url(base_url, direct_page_ids[normalized_issue_code])

    return ""



def _load_recent_scans_desc(tenant_id: str, limit: int | None = None) -> list[Scan]:
    with SessionLocal() as db:
        query = (
            select(Scan)
            .where(Scan.tenant_id == tenant_id)
            .order_by(Scan.generated_at_utc.desc(), Scan.id.desc())
        )
        if limit is not None:
            query = query.limit(limit)

        scans = db.scalars(query).all()
    return list(scans)


def _load_scan_issues(scan_id: str) -> list[ScanIssueRecord]:
    with SessionLocal() as db:
        issues = db.scalars(select(ScanIssueRecord).where(ScanIssueRecord.scan_id == scan_id)).all()

    return sorted(
        issues,
        key=lambda row: (
            -_safe_float(row.estimated_impact_eur),
            _severity_rank(row.severity),
            -_safe_int(row.affected_count),
            row.code,
        ),
    )


def _has_profile_data(scan: Scan) -> bool:
    return any(
        _safe_int(value) > 0
        for value in (
            scan.total_records,
            scan.customers_count,
            scan.vendors_count,
            scan.items_count,
            scan.customer_ledger_entries_count,
            scan.vendor_ledger_entries_count,
            scan.item_ledger_entries_count,
            scan.sales_headers_count,
            scan.sales_lines_count,
            scan.purchase_headers_count,
            scan.purchase_lines_count,
            scan.gl_entries_count,
            scan.value_entries_count,
            scan.warehouse_entries_count,
        )
    )


def _has_commercial_data(scan: Scan) -> bool:
    return any(
        _safe_float(value) > 0
        for value in (
            scan.estimated_loss_eur,
            scan.potential_saving_eur,
            scan.estimated_premium_price_monthly,
        )
    )


def _is_valid_dashboard_scan(scan: Scan) -> bool:
    if _has_profile_data(scan):
        return True
    if _safe_int(scan.checks_count) > 0 and _safe_int(scan.issues_count) >= 0:
        return True
    if _has_commercial_data(scan):
        return True
    return False


def _select_active_scan(scans_desc: list[Scan], selected_scan_id: str | None) -> Scan:
    if not scans_desc:
        raise ValueError("At least one scan is required.")

    if selected_scan_id:
        for scan in scans_desc:
            if scan.scan_id == selected_scan_id:
                return scan

    for scan in scans_desc:
        if _is_valid_dashboard_scan(scan):
            return scan

    return scans_desc[0]


def _build_trend_points(
    scans_desc: list[Scan],
    active_scan_id: str,
    value_attr: str,
    max_points: int = 12,
) -> list[dict[str, Any]]:
    active_index = 0
    for index, scan in enumerate(scans_desc):
        if scan.scan_id == active_scan_id:
            active_index = index
            break

    visible_desc = scans_desc[active_index : active_index + max_points]
    visible_asc = list(reversed(visible_desc))

    return [
        {
            "scan_id": scan.scan_id,
            "label": scan.generated_at_utc.strftime("%d.%m"),
            "timestamp": scan.generated_at_utc.strftime("%d.%m.%Y %H:%M"),
            "value": round(_safe_float(getattr(scan, value_attr, 0)), 2),
            "scan_type": scan.scan_type,
            "is_selected": scan.scan_id == active_scan_id,
        }
        for scan in visible_asc
    ]


def _scan_mode_label(scan_type: str | None, fallback: str | None) -> str:
    normalized = (scan_type or fallback or "").strip().lower()
    if normalized in {"deep", "premium_deep"}:
        return "Premium DeepScan"
    if normalized == "free_deep":
        return "Free DeepScan"
    return "Free QuickScan"


MODULE_SCORE_ORDER = [
    "System",
    "Finance",
    "Sales",
    "Purchasing",
    "Inventory",
    "CRM",
    "Manufacturing",
    "Service",
    "Jobs",
    "HR",
]


def _score_variant(score: int) -> str:
    safe_score = max(0, min(100, _safe_int(score)))
    if safe_score <= 60:
        return "critical"
    if safe_score <= 75:
        return "warning"
    if safe_score <= 85:
        return "moderate"
    if safe_score <= 95:
        return "good"
    return "excellent"


def _build_module_scores_from_scan(scan: Scan) -> list[dict[str, Any]]:
    items = [
        ("System", _safe_int(getattr(scan, "system_score", 0))),
        ("Finance", _safe_int(getattr(scan, "finance_score", 0))),
        ("Sales", _safe_int(getattr(scan, "sales_score", 0))),
        ("Purchasing", _safe_int(getattr(scan, "purchasing_score", 0))),
        ("Inventory", _safe_int(getattr(scan, "inventory_score", 0))),
        ("CRM", _safe_int(getattr(scan, "crm_score", 0))),
        ("Manufacturing", _safe_int(getattr(scan, "manufacturing_score", 0))),
        ("Service", _safe_int(getattr(scan, "service_score", 0))),
        ("Jobs", _safe_int(getattr(scan, "jobs_score", 0))),
        ("HR", _safe_int(getattr(scan, "hr_score", 0))),
    ]
    return [
        {
            "name": name,
            "score": max(0, min(100, score)),
            "value": max(0, min(100, score)),
            "label": name,
            "variant": _score_variant(score),
        }
        for name, score in items
    ]


def _has_module_scores(scan: Scan) -> bool:
    return any(
        _safe_int(value) > 0
        for value in (
            getattr(scan, "system_score", 0),
            getattr(scan, "finance_score", 0),
            getattr(scan, "sales_score", 0),
            getattr(scan, "purchasing_score", 0),
            getattr(scan, "inventory_score", 0),
            getattr(scan, "crm_score", 0),
            getattr(scan, "manufacturing_score", 0),
            getattr(scan, "service_score", 0),
            getattr(scan, "jobs_score", 0),
            getattr(scan, "hr_score", 0),
        )
    )


def _build_module_counts(scan: Scan) -> dict[str, int]:
    return {
        "System": _safe_int(scan.total_records),
        "Finance": _safe_int(scan.customer_ledger_entries_count) + _safe_int(scan.vendor_ledger_entries_count) + _safe_int(scan.gl_entries_count),
        "Sales": _safe_int(scan.sales_headers_count) + _safe_int(scan.sales_lines_count),
        "Purchasing": _safe_int(scan.purchase_headers_count) + _safe_int(scan.purchase_lines_count),
        "Inventory": _safe_int(scan.items_count) + _safe_int(scan.item_ledger_entries_count) + _safe_int(scan.value_entries_count) + _safe_int(scan.warehouse_entries_count),
        "CRM": _safe_int(scan.customers_count),
        "Manufacturing": 0,
        "Service": 0,
        "Jobs": 0,
        "HR": 0,
    }


MODULE_SCORE_ORDER = [
    "System",
    "Finance",
    "Sales",
    "Purchasing",
    "Inventory",
    "CRM",
    "Manufacturing",
    "Service",
    "Jobs",
    "HR",
]

def _build_profile_cards(scan: Scan) -> list[dict[str, Any]]:
    module_counts = _build_module_counts(scan)
    return [{"label": name, "value": module_counts.get(name, 0)} for name in MODULE_SCORE_ORDER]


def _get_current_plan_price_monthly(tenant: Tenant | None, scan: Scan | None) -> float:
    if tenant is None or scan is None:
        return 0.0

    plan = _normalize_plan(getattr(tenant, "current_plan", "free"))
    if plan == "free":
        return 0.0

    total_records = _safe_int(getattr(scan, "total_records", 0))

    try:
        with SessionLocal() as db:
            pricing = get_license_pricing(db, plan)
            return round(_safe_float(calculate_monthly_price(total_records, pricing)), 2)
    except Exception:
        if plan == "premium":
            return round(_safe_float(getattr(scan, "estimated_premium_price_monthly", 0.0)), 2)
        return 0.0


def _get_premium_pricing_breakdown(scan: Scan | None) -> dict[str, Any]:
    total_records = _safe_int(getattr(scan, "total_records", 0)) if scan is not None else 0
    with SessionLocal() as db:
        pricing = get_license_pricing(db, "premium")
        return build_embed_pricing_breakdown(total_records, pricing)


def _build_fallback_payload(company: str, environment: str, scan_mode: str | None) -> dict[str, Any]:
    with SessionLocal() as db:
        pricing = get_license_pricing(db, "premium")
        default_pricing = build_embed_pricing_breakdown(0, pricing)
    fallback_monthly = _safe_float(default_pricing.get("final_price_monthly"), 0.0)

    return {
        "title": "BCSentinel Analytics",
        "subtitle": f"{company} · {environment}",
        "scan_mode_label": _scan_mode_label(None, scan_mode),
        "last_updated": datetime.now(timezone.utc).strftime("%d.%m.%Y, %H:%M UTC"),
        "selected_scan_id": None,
        "current_plan": "free",
        "visibility": {
            "is_premium": False,
            "show_findings": False,
            "show_trends": False,
            "show_upgrade_preview": True,
        },
        "hero": {
            "eyebrow": "Insight is free. Action is Premium.",
            "headline_prefix": "Your data health is",
            "headline_highlight": "critical",
            "headline_suffix": "and requires immediate attention.",
        },
        "kpis": {
            "health_score": 0,
            "total_records": 0,
            "affected_records": 0,
            "estimated_premium_price_monthly": fallback_monthly,
            "estimated_loss_eur": 0.0,
            "potential_saving_eur": 0.0,
            "roi_eur": 0.0,
            "checks_run": 0,
            "issues_count": 0,
        },
        "profile_cards": [],
        "module_scores": [],
        "recent_scans": [],
        "recent_scans_pagination": {
            "page": 1,
            "page_size": 10,
            "total_items": 0,
            "total_pages": 1,
            "has_prev": False,
            "has_next": False,
        },
        "score_trend": [],
        "loss_trend": [],
        "issue_groups": [],
        "top_findings": [],
        "premium_preview_findings": [],
        "premium_unlock": {
            "headline": "Premium unlocks record-level details and direct action.",
            "body": "Upgrade to see affected records, recommendations, and Business Central actions for your highest-impact issues.",
            "button_label": "Upgrade to Premium",
            "button_action": "checkout",
            "highlights": [
                "Affected records and issue details",
                "Action recommendations",
                "Business Central navigation",
            ],
        },
        "pricing_breakdown": default_pricing,
        "subscription": {
            "plan_label": "Free",
            "price_monthly": 0.0,
            "annual_cost": 0.0,
            "cta_label": "Upgrade to Premium",
            "cta_action": "checkout",
            "plan_note": "Insight is free. Action is Premium.",
            "pricing_breakdown": default_pricing,
            "billing_options": {
                "monthly_label": "Monthly billing",
                "monthly_note": default_pricing.get("monthly_note", ""),
                "annual_label": "Annual fixed plan",
                "annual_note": default_pricing.get("annual_note", ""),
            },
        },
    }


def _hero_copy_for_score(score: int) -> dict[str, str]:
    if score <= 60:
        return {
            "headline_prefix": "Your data health is",
            "headline_highlight": "critical",
            "headline_suffix": "and costing money.",
        }
    if score <= 75:
        return {
            "headline_prefix": "Your data health needs",
            "headline_highlight": "attention",
            "headline_suffix": "before process friction gets worse.",
        }
    if score <= 85:
        return {
            "headline_prefix": "Your data health score is",
            "headline_highlight": "moderate",
            "headline_suffix": "with meaningful room for improvement.",
        }
    if score <= 95:
        return {
            "headline_prefix": "Your data health score is",
            "headline_highlight": "good",
            "headline_suffix": "with a few improvement opportunities left.",
        }
    return {
        "headline_prefix": "Your data health score is",
        "headline_highlight": "excellent",
        "headline_suffix": "with very low operational risk.",
    }


def _build_dashboard_payload(
    company: str,
    environment: str,
    tenant: Tenant | None,
    scan_mode: str | None,
    selected_scan_id: str | None,
    recent_scans_page: int = 1,
    recent_scans_page_size: int = 10,
    bc_issue_launch_url: str | None = None,
) -> dict[str, Any]:
    if tenant is None:
        return _build_fallback_payload(company, environment, scan_mode)

    recent_scans_desc = _load_recent_scans_desc(tenant.tenant_id)
    if not recent_scans_desc:
        return _build_fallback_payload(company, environment, scan_mode)

    active_scan = _select_active_scan(recent_scans_desc, selected_scan_id)
    issues = _load_scan_issues(active_scan.scan_id)
    module_scores = _build_module_scores_from_scan(active_scan)
    with SessionLocal() as db:
        tenant_features = get_tenant_features(db, tenant)

    current_plan = _normalize_plan(getattr(tenant, "current_plan", "free"))
    is_premium = is_premium_actions_enabled(tenant_features)
    can_view_recommendations = "recommendations" in tenant_features

    pricing_breakdown = _get_premium_pricing_breakdown(active_scan)

    premium_price_monthly = round(
        _safe_float(pricing_breakdown.get("final_price_monthly"), 0.0),
        2,
    )

    current_plan_price_monthly = _get_current_plan_price_monthly(tenant, active_scan)
    if current_plan == "free":
        current_plan_price_monthly = 0.0
    elif current_plan_price_monthly <= 0:
        current_plan_price_monthly = premium_price_monthly

    normalized_commercials = normalize_stored_commercials(
        total_records=_safe_int(active_scan.total_records),
        estimated_loss_eur=_safe_float(active_scan.estimated_loss_eur),
        potential_saving_eur=_safe_float(active_scan.potential_saving_eur),
        estimated_premium_price_monthly=premium_price_monthly,
    )

    affected_records = sum(_safe_int(issue.affected_count) for issue in issues)

    issue_groups: dict[str, int] = {name: 0 for name in MODULE_SCORE_ORDER}
    for issue in issues:
        group = _normalize_issue_category(getattr(issue, "category", None), issue.code)
        issue_groups[group] = issue_groups.get(group, 0) + _safe_int(issue.affected_count)

    total_recent_scans = len(recent_scans_desc)
    page_size = max(1, recent_scans_page_size)
    total_pages = max(1, math.ceil(total_recent_scans / page_size))
    current_page = min(max(1, recent_scans_page), total_pages)

    start_index = (current_page - 1) * page_size
    end_index = start_index + page_size
    visible_recent_scans = recent_scans_desc[start_index:end_index]

    recent_scans_payload = [
        {
            "scan_id": scan.scan_id,
            "generated_at": scan.generated_at_utc.strftime("%d.%m.%Y %H:%M"),
            "scan_type": scan.scan_type,
            "data_score": _safe_int(scan.data_score),
            "issues_count": _safe_int(scan.issues_count),
            "headline": scan.summary_headline,
            "is_selected": scan.scan_id == active_scan.scan_id,
            "is_valid": _is_valid_dashboard_scan(scan),
        }
        for scan in visible_recent_scans
    ]

    top_findings = [
        {
            "code": issue.code,
            "title": issue.title,
            "severity": _normalize_severity(issue.severity),
            "count": _safe_int(issue.affected_count),
            "impact_eur": round(_safe_float(issue.estimated_impact_eur), 2),
            "group": _normalize_issue_category(getattr(issue, "category", None), issue.code),
            "recommendation_preview": _issue_recommendation(issue) if can_view_recommendations else "",
            "premium_only": bool(issue.premium_only),
            "open_in_bc_url": _build_open_in_bc_url(bc_issue_launch_url, issue.code),
        }
        for issue in issues
    ]

    premium_preview_findings = [
        {
            "title": item["title"],
            "group": item["group"],
            "count": item["count"],
            "impact_eur": item["impact_eur"],
            "recommendation_preview": item["recommendation_preview"],
        }
        for item in top_findings[:3]
    ]

    return {
        "title": "BCSentinel Analytics",
        "subtitle": f"{company} · {environment}",
        "scan_mode_label": _scan_mode_label(active_scan.scan_type, scan_mode),
        "last_updated": active_scan.generated_at_utc.strftime("%d.%m.%Y, %H:%M UTC"),
        "selected_scan_id": active_scan.scan_id,
        "current_plan": current_plan,
        "visibility": {
            "is_premium": is_premium,
            "show_findings": is_premium,
            "show_trends": is_premium,
            "show_upgrade_preview": not is_premium,
        },
        "hero": {
            "eyebrow": "Insight is free. Action is Premium.",
            **_hero_copy_for_score(_safe_int(active_scan.data_score)),
        },
        "kpis": {
            "health_score": _safe_int(active_scan.data_score),
            "total_records": _safe_int(active_scan.total_records),
            "affected_records": affected_records,
            "estimated_premium_price_monthly": float(
                normalized_commercials["estimated_premium_price_monthly"]
            ),
            "estimated_loss_eur": float(normalized_commercials["estimated_loss_eur"]),
            "potential_saving_eur": float(normalized_commercials["potential_saving_eur"]),
            "roi_eur": float(normalized_commercials["roi_eur"]),
            "checks_run": _safe_int(active_scan.checks_count),
            "issues_count": _safe_int(active_scan.issues_count),
        },
        "profile_cards": _build_profile_cards(active_scan),
        "module_scores": module_scores,
        "module_counts": _build_module_counts(active_scan),
        "recent_scans": recent_scans_payload,
        "recent_scans_pagination": {
            "page": current_page,
            "page_size": page_size,
            "total_items": total_recent_scans,
            "total_pages": total_pages,
            "has_prev": current_page > 1,
            "has_next": current_page < total_pages,
        },
        "score_trend": _build_trend_points(recent_scans_desc, active_scan.scan_id, "data_score"),
        "loss_trend": _build_trend_points(recent_scans_desc, active_scan.scan_id, "estimated_loss_eur"),
        "issue_groups": [
            {"name": name, "count": count}
            for name, count in sorted(
                issue_groups.items(),
                key=lambda item: (-item[1], MODULE_SCORE_ORDER.index(item[0]) if item[0] in MODULE_SCORE_ORDER else 999),
            )
        ],
        "top_findings": top_findings if is_premium else [],
        "premium_preview_findings": premium_preview_findings,
        "premium_unlock": {
            "headline": "Do you want to keep losing money or start fixing the root causes?",
            "body": "Premium reveals the exact affected records, explains what to fix, and prioritizes the work by business impact.",
            "button_label": "Upgrade to Premium",
            "button_action": "checkout",
            "highlights": [
                "Affected records in Business Central",
                "Clear recommendations per issue",
                "Prioritized actions by financial impact",
            ],
        },
        "pricing_breakdown": pricing_breakdown,
        "subscription": {
            "plan_label": "Premium" if is_premium else "Free",
            "price_monthly": current_plan_price_monthly if is_premium else 0.0,
            "annual_cost": round(current_plan_price_monthly * 12, 2) if is_premium else 0.0,
            "cta_label": "Manage subscription" if is_premium else "Upgrade to Premium",
            "cta_action": "portal" if is_premium else "checkout",
            "plan_note": "Current paying plan" if is_premium else "Free gives insight. Premium unlocks action.",
            "pricing_breakdown": pricing_breakdown,
            "billing_options": {
                "monthly_label": "Monthly billing",
                "monthly_note": pricing_breakdown.get("monthly_note", ""),
                "annual_label": "Annual fixed plan",
                "annual_note": pricing_breakdown.get("annual_note", ""),
            },
        },
    }


@router.get("/analytics/get-token", response_class=JSONResponse)
def get_analytics_token(
    company: str = Query(default="CRONUS DE"),
    environment: str = Query(default="BC Cloud"),
    tenant_id: str | None = Query(default=None),
    scan_mode: str | None = Query(default=None),
    bc_issue_launch_url: str | None = Query(default=None),
    tenant_auth: tuple[str, str] = Depends(require_tenant_headers),
):
    header_tenant_id, header_api_token = tenant_auth

    if tenant_id:
        enforce_tenant_match(tenant_id, header_tenant_id, "Query tenant_id")

    with SessionLocal() as db:
        tenant = load_authenticated_tenant(db, header_tenant_id, header_api_token)

    token = create_token(
        {
            "company": company,
            "environment": environment,
            "tenant_id": tenant.tenant_id,
            "scan_mode": scan_mode,
            "bc_issue_launch_url": bc_issue_launch_url,
        }
    )
    return JSONResponse(content={"token": token})


@router.get("/analytics/embed/data", response_class=JSONResponse)
def get_analytics_data(
    token: str | None = Query(default=None),
    analytics_cookie_token: str | None = Cookie(default=None, alias=ANALYTICS_EMBED_COOKIE_NAME),
    scan_id: str | None = Query(default=None),
    recent_scans_page: int = Query(default=1, ge=1),
    recent_scans_page_size: int = Query(default=10, ge=1, le=25),
):
    effective_token = token or analytics_cookie_token
    if not effective_token:
        raise HTTPException(status_code=401, detail="Missing analytics token.")

    payload = verify_token(effective_token)
    if payload is None:
        raise HTTPException(status_code=401, detail="Invalid or expired token.")

    tenant_id = str(payload.get("tenant_id") or "").strip()
    if not tenant_id:
        raise HTTPException(status_code=401, detail="Token payload is missing tenant_id.")

    with SessionLocal() as db:
        tenant = db.scalar(select(Tenant).where(Tenant.tenant_id == tenant_id))

    if tenant is None:
        raise HTTPException(status_code=404, detail="Tenant not found.")

    return JSONResponse(
        content=_build_dashboard_payload(
            company=payload.get("company", "BCSentinel"),
            environment=payload.get("environment", "BC Cloud"),
            tenant=tenant,
            scan_mode=payload.get("scan_mode"),
            selected_scan_id=scan_id,
            recent_scans_page=recent_scans_page,
            recent_scans_page_size=recent_scans_page_size,
            bc_issue_launch_url=payload.get("bc_issue_launch_url"),
        )
    )


def _load_analytics_tenant(token: str | None, analytics_cookie_token: str | None) -> Tenant:
    effective_token = token or analytics_cookie_token
    if not effective_token:
        raise HTTPException(status_code=401, detail="Missing analytics token.")

    payload = verify_token(effective_token)
    if payload is None:
        raise HTTPException(status_code=401, detail="Invalid or expired token.")

    tenant_id = str(payload.get("tenant_id") or "").strip()
    if not tenant_id:
        raise HTTPException(status_code=401, detail="Token payload is missing tenant_id.")

    with SessionLocal() as db:
        tenant = db.scalar(select(Tenant).where(Tenant.tenant_id == tenant_id))
        if tenant is None:
            raise HTTPException(status_code=404, detail="Tenant not found.")
        require_tenant_feature(db, tenant, "quick_scan")
        return tenant


@router.post("/analytics/billing/checkout", response_class=JSONResponse)
def analytics_billing_checkout(
    token: str | None = Query(default=None),
    analytics_cookie_token: str | None = Cookie(default=None, alias=ANALYTICS_EMBED_COOKIE_NAME),
):
    tenant = _load_analytics_tenant(token, analytics_cookie_token)
    if not (tenant.api_token or "").strip():
        raise HTTPException(status_code=400, detail="Tenant API token is missing.")

    session = create_checkout_session(
        CheckoutSessionRequest(
            tenant_id=tenant.tenant_id,
            plan_code="premium",
            billing_interval="monthly",
        ),
        tenant_auth=(tenant.tenant_id, tenant.api_token),
    )
    return JSONResponse(
        content={
            "action": "checkout",
            "provider": session.provider,
            "checkout_url": session.checkout_url,
        }
    )


@router.post("/analytics/billing/portal", response_class=JSONResponse)
def analytics_billing_portal(
    token: str | None = Query(default=None),
    analytics_cookie_token: str | None = Cookie(default=None, alias=ANALYTICS_EMBED_COOKIE_NAME),
):
    tenant = _load_analytics_tenant(token, analytics_cookie_token)
    if not (tenant.api_token or "").strip():
        raise HTTPException(status_code=400, detail="Tenant API token is missing.")

    portal = create_billing_portal_session(
        BillingPortalRequest(tenant_id=tenant.tenant_id),
        tenant_auth=(tenant.tenant_id, tenant.api_token),
    )
    return JSONResponse(
        content={
            "action": "portal",
            "provider": portal.provider,
            "portal_url": portal.portal_url,
        }
    )


@router.get("/analytics/embed", response_class=HTMLResponse)
def render_analytics_dashboard(
    request: Request,
    token: str | None = Query(default=None),
    analytics_cookie_token: str | None = Cookie(default=None, alias=ANALYTICS_EMBED_COOKIE_NAME),
):
    if token:
        payload = verify_token(token)
        if payload is None:
            raise HTTPException(status_code=401, detail="Invalid or expired token.")

        tenant_id = str(payload.get("tenant_id") or "").strip()
        if not tenant_id:
            raise HTTPException(status_code=401, detail="Token payload is missing tenant_id.")

        with SessionLocal() as db:
            tenant = db.scalar(select(Tenant).where(Tenant.tenant_id == tenant_id))

        if tenant is None:
            raise HTTPException(status_code=404, detail="Tenant not found.")

        response = RedirectResponse(url="/analytics/embed", status_code=303)
        response.set_cookie(
            key=ANALYTICS_EMBED_COOKIE_NAME,
            value=token,
            max_age=ANALYTICS_EMBED_COOKIE_MAX_AGE_SECONDS,
            httponly=True,
            secure=(settings.ENV.lower() == "prod"),
            samesite="lax",
            path="/analytics",
        )
        return response

    if not analytics_cookie_token:
        raise HTTPException(status_code=401, detail="Missing analytics token.")

    payload = verify_token(analytics_cookie_token)
    if payload is None:
        raise HTTPException(status_code=401, detail="Invalid or expired token.")

    tenant_id = str(payload.get("tenant_id") or "").strip()
    if not tenant_id:
        raise HTTPException(status_code=401, detail="Token payload is missing tenant_id.")

    with SessionLocal() as db:
        tenant = db.scalar(select(Tenant).where(Tenant.tenant_id == tenant_id))

    if tenant is None:
        raise HTTPException(status_code=404, detail="Tenant not found.")

    return TEMPLATES.TemplateResponse(
        name="analytics_embed.html",
        context={
            "request": request,
            "page_title": "BCSentinel Analytics",
        },
    )
