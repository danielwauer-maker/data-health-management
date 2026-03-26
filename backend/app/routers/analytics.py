from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from fastapi import APIRouter, HTTPException, Query, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy import select

from app.db import SessionLocal
from app.models import Scan, ScanIssueRecord, Tenant
from app.security.token import create_token, verify_token
from app.services.pricing_service import calculate_monthly_price, get_license_pricing

router = APIRouter(tags=["analytics"])
TEMPLATES = Jinja2Templates(directory=str(Path(__file__).resolve().parent.parent / "templates"))


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
    if code_upper.startswith("CUSTOMERS_"):
        return "Customers"
    if code_upper.startswith("VENDORS_"):
        return "Vendors"
    if code_upper.startswith("ITEMS_"):
        return "Items"
    if code_upper.startswith("SALES_"):
        return "Sales"
    if code_upper.startswith("PURCHASE_"):
        return "Purchasing"
    if "LEDGER" in code_upper or code_upper.startswith("GL_"):
        return "Finance"
    return "Other"


def _issue_recommendation(issue: ScanIssueRecord) -> str:
    preview = (issue.recommendation_preview or "").strip()
    if preview:
        return preview

    group = _issue_group_from_code(issue.code)
    if group == "Customers":
        return "Review impacted customer master data and complete mandatory fields in Business Central."
    if group == "Vendors":
        return "Complete vendor setup and remove blocking gaps before the next purchasing cycle."
    if group == "Items":
        return "Prioritize item setup issues that affect planning, costing, or inventory transactions."
    if group == "Purchasing":
        return "Resolve purchasing document inconsistencies before they create follow-up workload."
    if group == "Finance":
        return "Investigate financial postings and open entries with missing or inconsistent setup."
    return "Review the affected records and resolve the underlying setup issue in Business Central."


def _load_tenant(tenant_id: str | None, environment: str | None) -> Tenant | None:
    with SessionLocal() as db:
        if tenant_id:
            tenant = db.scalar(select(Tenant).where(Tenant.tenant_id == tenant_id))
            if tenant is not None:
                return tenant

        tenants = db.scalars(select(Tenant).order_by(Tenant.created_at_utc.desc())).all()
        if environment:
            for tenant in tenants:
                if tenant.environment_name == environment:
                    return tenant

        return tenants[0] if tenants else None


def _load_recent_scans_desc(tenant_id: str, limit: int = 20) -> list[Scan]:
    with SessionLocal() as db:
        scans = db.scalars(
            select(Scan)
            .where(Scan.tenant_id == tenant_id)
            .order_by(Scan.generated_at_utc.desc(), Scan.id.desc())
            .limit(limit)
        ).all()
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
    return "Free QuickScan"


def _build_profile_cards(scan: Scan) -> list[dict[str, Any]]:
    return [
        {"label": "Customers", "value": _safe_int(scan.customers_count)},
        {"label": "Vendors", "value": _safe_int(scan.vendors_count)},
        {"label": "Items", "value": _safe_int(scan.items_count)},
        {
            "label": "Sales",
            "value": _safe_int(scan.sales_headers_count) + _safe_int(scan.sales_lines_count),
        },
        {
            "label": "Purchase",
            "value": _safe_int(scan.purchase_headers_count) + _safe_int(scan.purchase_lines_count),
        },
        {
            "label": "Ledger",
            "value": _safe_int(scan.customer_ledger_entries_count)
            + _safe_int(scan.vendor_ledger_entries_count)
            + _safe_int(scan.item_ledger_entries_count)
            + _safe_int(scan.gl_entries_count),
        },
    ]


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


def _build_fallback_payload(company: str, environment: str, scan_mode: str | None) -> dict[str, Any]:
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
            "estimated_premium_price_monthly": 149.0,
            "estimated_loss_eur": 0.0,
            "potential_saving_eur": 0.0,
            "roi_eur": 0.0,
            "checks_run": 0,
            "issues_count": 0,
        },
        "profile_cards": [],
        "recent_scans": [],
        "score_trend": [],
        "loss_trend": [],
        "issue_groups": [],
        "top_findings": [],
        "premium_preview_findings": [],
        "premium_unlock": {
            "headline": "Premium unlocks record-level details and direct action.",
            "body": "Upgrade to see affected records, recommendations, and Business Central actions for your highest-impact issues.",
            "button_label": "Upgrade to Premium",
            "highlights": [
                "Affected records and issue details",
                "Action recommendations",
                "Business Central navigation",
            ],
        },
        "subscription": {
            "plan_label": "Free",
            "price_monthly": 0.0,
            "annual_cost": 0.0,
            "cta_label": "Upgrade to Premium",
            "plan_note": "Insight is free. Action is Premium.",
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
) -> dict[str, Any]:
    if tenant is None:
        return _build_fallback_payload(company, environment, scan_mode)

    recent_scans_desc = _load_recent_scans_desc(tenant.tenant_id, limit=20)
    if not recent_scans_desc:
        return _build_fallback_payload(company, environment, scan_mode)

    active_scan = _select_active_scan(recent_scans_desc, selected_scan_id)
    issues = _load_scan_issues(active_scan.scan_id)
    current_plan = _normalize_plan(getattr(tenant, "current_plan", "free"))
    is_premium = current_plan == "premium"
    premium_price_monthly = round(
        max(_safe_float(active_scan.estimated_premium_price_monthly), 149.0),
        2,
    )
    current_plan_price_monthly = premium_price_monthly if not is_premium else _get_current_plan_price_monthly(tenant, active_scan) or premium_price_monthly
    potential_saving_eur = round(_safe_float(active_scan.potential_saving_eur), 2)
    current_roi = round(potential_saving_eur - (premium_price_monthly * 12), 2)
    affected_records = sum(_safe_int(issue.affected_count) for issue in issues)

    issue_groups: dict[str, int] = {}
    for issue in issues:
        group = _issue_group_from_code(issue.code)
        issue_groups[group] = issue_groups.get(group, 0) + _safe_int(issue.affected_count)

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
        for scan in recent_scans_desc[:10]
    ]

    top_findings = [
        {
            "code": issue.code,
            "title": issue.title,
            "severity": _normalize_severity(issue.severity),
            "count": _safe_int(issue.affected_count),
            "impact_eur": round(_safe_float(issue.estimated_impact_eur), 2),
            "group": _issue_group_from_code(issue.code),
            "recommendation_preview": _issue_recommendation(issue),
            "premium_only": bool(issue.premium_only),
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
            "estimated_premium_price_monthly": premium_price_monthly,
            "estimated_loss_eur": round(_safe_float(active_scan.estimated_loss_eur), 2),
            "potential_saving_eur": potential_saving_eur,
            "roi_eur": current_roi,
            "checks_run": _safe_int(active_scan.checks_count),
            "issues_count": _safe_int(active_scan.issues_count),
        },
        "profile_cards": _build_profile_cards(active_scan),
        "recent_scans": recent_scans_payload,
        "score_trend": _build_trend_points(recent_scans_desc, active_scan.scan_id, "data_score"),
        "loss_trend": _build_trend_points(recent_scans_desc, active_scan.scan_id, "estimated_loss_eur"),
        "issue_groups": [
            {"name": name, "count": count}
            for name, count in sorted(issue_groups.items(), key=lambda item: item[1], reverse=True)
        ],
        "top_findings": top_findings,
        "premium_preview_findings": premium_preview_findings,
        "premium_unlock": {
            "headline": "Do you want to keep losing money or start fixing the root causes?",
            "body": "Premium reveals the exact affected records, explains what to fix, and prioritizes the work by business impact.",
            "button_label": "Upgrade to Premium",
            "highlights": [
                "Affected records in Business Central",
                "Clear recommendations per issue",
                "Prioritized actions by financial impact",
            ],
        },
        "subscription": {
            "plan_label": "Premium" if is_premium else "Free",
            "price_monthly": current_plan_price_monthly if is_premium else 0.0,
            "annual_cost": round(current_plan_price_monthly * 12, 2) if is_premium else 0.0,
            "cta_label": "Manage subscription" if is_premium else "Upgrade to Premium",
            "plan_note": "Current paying plan" if is_premium else "Free gives insight. Premium unlocks action.",
        },
    }


@router.get("/analytics/get-token", response_class=JSONResponse)
def get_analytics_token(
    company: str = Query(default="CRONUS DE"),
    environment: str = Query(default="BC Cloud"),
    tenant_id: str | None = Query(default=None),
    scan_mode: str | None = Query(default=None),
):
    tenant = _load_tenant(tenant_id=tenant_id, environment=environment)
    token = create_token(
        {
            "company": company,
            "environment": environment,
            "tenant_id": tenant.tenant_id if tenant is not None else tenant_id,
            "scan_mode": scan_mode,
        },
        expires_minutes=20,
    )
    return JSONResponse(content={"token": token})


@router.get("/analytics/embed/data", response_class=JSONResponse)
def get_analytics_data(
    token: str = Query(...),
    scan_id: str | None = Query(default=None),
):
    payload = verify_token(token)
    if payload is None:
        raise HTTPException(status_code=401, detail="Invalid or expired token.")

    tenant = _load_tenant(payload.get("tenant_id"), payload.get("environment"))
    return JSONResponse(
        content=_build_dashboard_payload(
            company=payload.get("company", "BCSentinel"),
            environment=payload.get("environment", "BC Cloud"),
            tenant=tenant,
            scan_mode=payload.get("scan_mode"),
            selected_scan_id=scan_id,
        )
    )


@router.get("/analytics/embed", response_class=HTMLResponse)
def render_analytics_dashboard(request: Request, token: str = Query(...)):
    payload = verify_token(token)
    if payload is None:
        raise HTTPException(status_code=401, detail="Invalid or expired token.")

    return TEMPLATES.TemplateResponse(
        name="analytics_embed.html",
        context={
            "request": request,
            "page_title": "BCSentinel Analytics",
            "token": token,
        },
    )
