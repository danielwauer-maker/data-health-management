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


def _load_recent_scans(tenant_id: str, limit: int = 20) -> list[Scan]:
    with SessionLocal() as db:
        scans = db.scalars(
            select(Scan)
            .where(Scan.tenant_id == tenant_id)
            .order_by(Scan.generated_at_utc.desc())
            .limit(limit)
        ).all()
    return list(reversed(scans))


def _load_scan_issues(scan_id: str) -> list[ScanIssueRecord]:
    with SessionLocal() as db:
        issues = db.scalars(select(ScanIssueRecord).where(ScanIssueRecord.scan_id == scan_id)).all()
    return sorted(issues, key=lambda row: (_normalize_severity(row.severity), -(row.affected_count or 0)))


def _scan_mode_label(scan_type: str | None, fallback: str | None) -> str:
    normalized = (scan_type or fallback or "").strip().lower()
    if normalized == "deep" or normalized == "premium_deep":
        return "Premium DeepScan"
    return "Kostenloser QuickScan"


def _build_fallback_payload(company: str, environment: str, scan_mode: str | None) -> dict[str, Any]:
    return {
        "title": "BCSentinel Analytics",
        "subtitle": f"{company} · {environment}",
        "scan_mode_label": _scan_mode_label(None, scan_mode),
        "last_updated": datetime.now(timezone.utc).strftime("%d.%m.%Y, %H:%M UTC"),
        "kpis": {
            "health_score": 0,
            "total_records": 0,
            "estimated_premium_price_monthly": 0.0,
            "estimated_loss_eur": 0.0,
            "roi_eur": 0.0,
            "checks_run": 0,
            "issues_count": 0,
        },
        "profile_cards": [],
        "recent_scans": [],
        "score_trend": [],
        "issue_groups": [],
        "top_findings": [],
    }


def _build_dashboard_payload(company: str, environment: str, tenant: Tenant | None, scan_mode: str | None) -> dict[str, Any]:
    if tenant is None:
        return _build_fallback_payload(company, environment, scan_mode)

    recent_scans = _load_recent_scans(tenant.tenant_id, limit=20)
    if not recent_scans:
        return _build_fallback_payload(company, environment, scan_mode)

    active_scan = recent_scans[-1]
    issues = _load_scan_issues(active_scan.scan_id)

    issue_groups: dict[str, int] = {}
    top_findings: list[dict[str, Any]] = []
    for issue in sorted(issues, key=lambda row: (-(row.estimated_impact_eur or 0.0), -(row.affected_count or 0)))[:8]:
        issue_groups[_issue_group_from_code(issue.code)] = issue_groups.get(_issue_group_from_code(issue.code), 0) + _safe_int(issue.affected_count)
        top_findings.append(
            {
                "code": issue.code,
                "title": issue.title,
                "severity": _normalize_severity(issue.severity),
                "count": _safe_int(issue.affected_count),
                "impact_eur": round(_safe_float(issue.estimated_impact_eur), 2),
                "group": _issue_group_from_code(issue.code),
            }
        )

    for issue in issues:
        grp = _issue_group_from_code(issue.code)
        issue_groups[grp] = issue_groups.get(grp, 0) + _safe_int(issue.affected_count)

    profile_cards = [
        {"label": "Customers", "value": _safe_int(active_scan.customers_count)},
        {"label": "Vendors", "value": _safe_int(active_scan.vendors_count)},
        {"label": "Items", "value": _safe_int(active_scan.items_count)},
        {"label": "Sales Docs", "value": _safe_int(active_scan.sales_headers_count) + _safe_int(active_scan.sales_lines_count)},
        {"label": "Purchase Docs", "value": _safe_int(active_scan.purchase_headers_count) + _safe_int(active_scan.purchase_lines_count)},
        {"label": "Ledger", "value": _safe_int(active_scan.customer_ledger_entries_count) + _safe_int(active_scan.vendor_ledger_entries_count) + _safe_int(active_scan.item_ledger_entries_count) + _safe_int(active_scan.gl_entries_count)},
    ]

    return {
        "title": "BCSentinel Analytics",
        "subtitle": f"{company} · {environment}",
        "scan_mode_label": _scan_mode_label(active_scan.scan_type, scan_mode),
        "last_updated": active_scan.generated_at_utc.strftime("%d.%m.%Y, %H:%M UTC"),
        "kpis": {
            "health_score": _safe_int(active_scan.data_score),
            "total_records": _safe_int(active_scan.total_records),
            "estimated_premium_price_monthly": round(_safe_float(active_scan.estimated_premium_price_monthly), 2),
            "estimated_loss_eur": round(_safe_float(active_scan.estimated_loss_eur), 2),
            "roi_eur": round(_safe_float(active_scan.roi_eur), 2),
            "checks_run": _safe_int(active_scan.checks_count),
            "issues_count": _safe_int(active_scan.issues_count),
        },
        "profile_cards": profile_cards,
        "recent_scans": [
            {
                "scan_id": scan.scan_id,
                "generated_at": scan.generated_at_utc.strftime("%d.%m.%Y %H:%M"),
                "scan_type": scan.scan_type,
                "data_score": _safe_int(scan.data_score),
                "issues_count": _safe_int(scan.issues_count),
                "headline": scan.summary_headline,
            }
            for scan in reversed(recent_scans[-6:])
        ],
        "score_trend": [
            {"label": scan.generated_at_utc.strftime("%d.%m"), "value": _safe_int(scan.data_score)}
            for scan in recent_scans[-10:]
        ],
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
def get_analytics_data(token: str = Query(...)):
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
        )
    )


@router.get("/analytics/embed", response_class=HTMLResponse)
def render_analytics_dashboard(request: Request, token: str = Query(...)):
    payload = verify_token(token)
    if payload is None:
        raise HTTPException(status_code=401, detail="Invalid or expired token.")

    return TEMPLATES.TemplateResponse(
        name="analytics_embed.html",
        context={"request": request,
            "page_title": "BCSentinel Analytics",
            "token": token,
        },
    )
