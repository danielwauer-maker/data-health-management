from __future__ import annotations

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


RATING_CONFIG = {
    "critical": {
        "label": "Critical",
        "color": "#ef4444",
        "hero_text": "Your data health is critical",
        "bullets": [
            "Massive data problems",
            "High financial impact",
            "Immediate action required",
        ],
    },
    "warning": {
        "label": "Warning",
        "color": "#f97316",
        "hero_text": "Your data health is warning",
        "bullets": [
            "Significant quality problems",
            "Noticeable impact on processes",
        ],
    },
    "moderate": {
        "label": "Moderate",
        "color": "#eab308",
        "hero_text": "Your data health is moderate",
        "bullets": [
            "Average data quality",
            "Optimization is advisable",
        ],
    },
    "good": {
        "label": "Good",
        "color": "#3b82f6",
        "hero_text": "Your data health is good",
        "bullets": [
            "Good data quality",
            "Only minor problems exist",
        ],
    },
    "excellent": {
        "label": "Excellent",
        "color": "#22c55e",
        "hero_text": "Your data health is excellent",
        "bullets": [
            "Very high data quality",
            "Hardly any risks or losses",
        ],
    },
}


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
    if plan in {"free", "premium"}:
        return plan
    return "free"



def _plan_label(plan: str) -> str:
    return "Premium" if plan == "premium" else "Free"



def _score_rating(score: int) -> str:
    if score <= 60:
        return "critical"
    if score <= 75:
        return "warning"
    if score <= 85:
        return "moderate"
    if score <= 95:
        return "good"
    return "excellent"



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



def _build_profile_cards(scan: Scan) -> list[dict[str, Any]]:
    return [
        {"label": "Customers", "value": _safe_int(scan.customers_count)},
        {"label": "Vendors", "value": _safe_int(scan.vendors_count)},
        {"label": "Items", "value": _safe_int(scan.items_count)},
        {"label": "Sales", "value": _safe_int(scan.sales_headers_count)},
        {"label": "Purchase", "value": _safe_int(scan.purchase_headers_count)},
        {
            "label": "Ledger",
            "value": _safe_int(scan.customer_ledger_entries_count)
            + _safe_int(scan.vendor_ledger_entries_count)
            + _safe_int(scan.item_ledger_entries_count)
            + _safe_int(scan.gl_entries_count),
        },
    ]



def _build_trend_points(scans: list[Scan], selected_scan_id: str, value_field: str) -> list[dict[str, Any]]:
    usable = sorted(scans[:10], key=lambda row: row.generated_at_utc)
    points: list[dict[str, Any]] = []
    for scan in usable:
        raw = getattr(scan, value_field, 0)
        points.append(
            {
                "scan_id": scan.scan_id,
                "label": scan.generated_at_utc.strftime("%d.%m"),
                "timestamp": scan.generated_at_utc.isoformat(),
                "value": round(_safe_float(raw), 2),
                "scan_type": scan.scan_type or "",
                "is_selected": scan.scan_id == selected_scan_id,
            }
        )
    return points



def _build_dashboard_payload(
    company: str,
    environment: str,
    tenant: Tenant | None,
    scan_mode: str | None,
    selected_scan_id: str | None,
) -> dict[str, Any]:
    if tenant is None:
        raise HTTPException(status_code=404, detail="Tenant not found.")

    recent_scans_desc = _load_recent_scans_desc(tenant.tenant_id, limit=20)
    if not recent_scans_desc:
        raise HTTPException(status_code=404, detail="No scans available.")

    active_scan = next((scan for scan in recent_scans_desc if scan.scan_id == selected_scan_id), recent_scans_desc[0])
    issues = _load_scan_issues(active_scan.scan_id)

    current_plan = _normalize_plan(getattr(tenant, "current_plan", "free"))
    current_price_monthly = round(
        _safe_float(get_license_pricing(current_plan).get("base_price") or calculate_monthly_price(active_scan.total_records or 0, current_plan)),
        2,
    )
    current_loss = round(_safe_float(active_scan.estimated_loss_eur), 2)
    current_roi = round(_safe_float(active_scan.roi_eur), 2)
    health_score = _safe_int(active_scan.data_score)
    rating_key = _score_rating(health_score)
    rating = RATING_CONFIG[rating_key]

    issue_groups: dict[str, int] = {}
    for issue in issues:
        group = _issue_group_from_code(issue.code)
        issue_groups[group] = issue_groups.get(group, 0) + _safe_int(issue.affected_count)

    recent_scans_payload = [
        {
            "scan_id": scan.scan_id,
            "generated_at": scan.generated_at_utc.strftime("%d.%m.%Y %H:%M"),
            "scan_type": scan.scan_type,
            "score": _safe_int(scan.data_score),
            "issues_count": _safe_int(scan.issues_count),
            "headline": scan.summary_headline,
            "is_selected": scan.scan_id == active_scan.scan_id,
        }
        for scan in recent_scans_desc[:10]
    ]

    top_findings = [
        {
            "title": issue.title or (issue.code or "").replace("_", " ").title(),
            "severity": _normalize_severity(issue.severity),
            "count": _safe_int(issue.affected_count),
            "impact_eur": round(_safe_float(issue.estimated_impact_eur), 2),
            "group": _issue_group_from_code(issue.code),
        }
        for issue in issues
    ]

    return {
        "title": "BCSentinel Analytics",
        "subtitle": f"{company} · {environment}",
        "last_updated": active_scan.generated_at_utc.strftime("%d.%m.%Y, %H:%M UTC"),
        "selected_scan_id": active_scan.scan_id,
        "current_plan": current_plan,
        "current_plan_label": _plan_label(current_plan),
        "hero": {
            "intro": "Insight is free. Action is Premium.",
            "headline": rating["hero_text"],
            "rating_label": rating["label"],
            "rating_key": rating_key,
            "rating_color": rating["color"],
            "bullets": rating["bullets"],
        },
        "kpis": {
            "health_score": health_score,
            "total_records": _safe_int(active_scan.total_records),
            "affected_records": sum(_safe_int(issue.affected_count) for issue in issues),
            "estimated_premium_price_monthly": current_price_monthly,
            "estimated_loss_eur": current_loss,
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
