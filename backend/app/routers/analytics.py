from __future__ import annotations

import calendar
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import HTMLResponse, JSONResponse
from sqlalchemy import select

from app.db import SessionLocal
from app.models import Scan, ScanIssueRecord, Tenant
from app.security.token import create_token, verify_token

router = APIRouter(tags=["analytics"])


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def _safe_int(value: Any, default: int = 0) -> int:
    try:
        if value is None:
            return default
        return int(value)
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
        return "Kunden"
    if code_upper.startswith("VENDORS_"):
        return "Lieferanten"
    if code_upper.startswith("ITEMS_"):
        return "Artikel"

    if code_upper.startswith("SALES_"):
        return "Verkauf"
    if code_upper.startswith("PURCHASE_"):
        return "Einkauf"
    if code_upper.startswith("LEDGER_") or code_upper.startswith("CUSTOMER_LEDGER_") or code_upper.startswith("VENDOR_LEDGER_"):
        return "Finanzen"

    return "Sonstige"


def _issue_sort_key(issue: ScanIssueRecord) -> tuple[int, int]:
    severity_rank = {
        "high": 0,
        "medium": 1,
        "low": 2,
    }.get(_normalize_severity(issue.severity), 9)

    return (severity_rank, -_safe_int(issue.affected_count))


def _resolve_tenant(tenant_id: Optional[str], environment: str) -> Optional[Tenant]:
    with SessionLocal() as db:
        if tenant_id:
            tenant = db.scalar(
                select(Tenant).where(Tenant.tenant_id == tenant_id)
            )
            if tenant is not None:
                return tenant

        tenants = db.scalars(
            select(Tenant).order_by(Tenant.created_at_utc.desc())
        ).all()

        if not tenants:
            return None

        if environment:
            for tenant in tenants:
                if tenant.environment_name == environment:
                    return tenant

        if len(tenants) == 1:
            return tenants[0]

        return tenants[0]


def _load_latest_scan_for_tenant(tenant_id: str) -> Optional[Scan]:
    with SessionLocal() as db:
        return db.scalar(
            select(Scan)
            .where(Scan.tenant_id == tenant_id)
            .order_by(Scan.generated_at_utc.desc())
            .limit(1)
        )


def _load_scan_by_id_for_tenant(tenant_id: str, scan_id: str) -> Optional[Scan]:
    with SessionLocal() as db:
        return db.scalar(
            select(Scan)
            .where(Scan.tenant_id == tenant_id, Scan.scan_id == scan_id)
            .limit(1)
        )


def _load_recent_scans_for_tenant(tenant_id: str, limit: int = 120) -> List[Scan]:
    with SessionLocal() as db:
        scans = db.scalars(
            select(Scan)
            .where(Scan.tenant_id == tenant_id)
            .order_by(Scan.generated_at_utc.desc())
            .limit(max(1, min(limit, 500)))
        ).all()

    scans.reverse()
    return scans


def _load_issues_for_scan(scan_id: str) -> List[ScanIssueRecord]:
    with SessionLocal() as db:
        issues = db.scalars(
            select(ScanIssueRecord)
            .where(ScanIssueRecord.scan_id == scan_id)
        ).all()

    return sorted(issues, key=_issue_sort_key)


def _load_scan_days_for_month(tenant_id: str, year: int, month: int) -> List[Dict[str, Any]]:
    start = datetime(year, month, 1, tzinfo=timezone.utc)
    if month == 12:
        end = datetime(year + 1, 1, 1, tzinfo=timezone.utc)
    else:
        end = datetime(year, month + 1, 1, tzinfo=timezone.utc)

    with SessionLocal() as db:
        scans = db.scalars(
            select(Scan)
            .where(
                Scan.tenant_id == tenant_id,
                Scan.generated_at_utc >= start,
                Scan.generated_at_utc < end,
            )
            .order_by(Scan.generated_at_utc.asc())
        ).all()

    grouped: Dict[str, int] = {}
    for scan in scans:
        key = scan.generated_at_utc.date().isoformat()
        grouped[key] = grouped.get(key, 0) + 1

    return [
        {
            "date": day_iso,
            "count": count,
        }
        for day_iso, count in sorted(grouped.items())
    ]


def _load_scans_for_day(tenant_id: str, day_iso: str) -> List[Dict[str, Any]]:
    try:
        day_start = datetime.fromisoformat(f"{day_iso}T00:00:00+00:00")
    except ValueError:
        return []

    day_end = day_start.replace(hour=23, minute=59, second=59)

    with SessionLocal() as db:
        scans = db.scalars(
            select(Scan)
            .where(
                Scan.tenant_id == tenant_id,
                Scan.generated_at_utc >= day_start,
                Scan.generated_at_utc <= day_end,
            )
            .order_by(Scan.generated_at_utc.desc())
        ).all()

    return [
        {
            "scan_id": scan.scan_id,
            "generated_at_utc": scan.generated_at_utc.isoformat(),
            "scan_type": getattr(scan, "scan_type", None) or "",
            "data_score": _safe_int(scan.data_score),
            "issues_count": _safe_int(scan.issues_count),
            "checks_count": _safe_int(scan.checks_count),
            "headline": getattr(scan, "summary_headline", "") or "",
        }
        for scan in scans
    ]


def _resolve_scan_mode_label(scan_mode: Optional[str]) -> str:
    mode = str(scan_mode or "").strip().lower()

    if mode == "premium_deep":
        return "Premium DeepScan"

    return "Kostenloser QuickScan"


def _resolve_scan_mode_label_from_scan(scan: Optional[Scan], fallback_scan_mode: Optional[str]) -> str:
    if scan is not None:
        scan_type = str(getattr(scan, "scan_type", "") or "").strip().lower()
        if scan_type == "deep":
            return "Premium DeepScan"
        if scan_type == "quick":
            return "Kostenloser QuickScan"

    return _resolve_scan_mode_label(fallback_scan_mode)


def _build_fallback_payload(company: str, environment: str, scan_mode: Optional[str]) -> Dict[str, Any]:
    return {
        "title": "Data Health Management Analytics",
        "subtitle": f"{company} · {environment}",
        "last_updated_utc": _utc_now_iso(),
        "kpis": {
            "health_score": 87,
            "total_issues": 42,
            "high_issues": 6,
            "medium_issues": 14,
            "low_issues": 22,
            "checks_run": 36,
        },
        "issue_groups": [
            {"name": "Kunden", "count": 11},
            {"name": "Lieferanten", "count": 7},
            {"name": "Artikel", "count": 9},
            {"name": "Sonstige", "count": 15},
        ],
        "score_trend": [
            {"label": "S1", "value": 72},
            {"label": "S2", "value": 75},
            {"label": "S3", "value": 79},
            {"label": "S4", "value": 82},
            {"label": "S5", "value": 85},
            {"label": "S6", "value": 87},
        ],
        "top_findings": [
            {
                "code": "CUSTOMERS_MISSING_EMAIL",
                "title": "Kunden ohne E-Mail",
                "severity": "medium",
                "count": 8,
                "group": "Kunden",
            },
            {
                "code": "ITEMS_MISSING_CATEGORY",
                "title": "Artikel ohne Kategorie",
                "severity": "medium",
                "count": 6,
                "group": "Artikel",
            },
            {
                "code": "CUSTOMERS_MISSING_PAYMENT_TERMS",
                "title": "Kunden ohne Zahlungsbedingung",
                "severity": "high",
                "count": 4,
                "group": "Kunden",
            },
            {
                "code": "VENDORS_MISSING_EMAIL",
                "title": "Lieferanten ohne E-Mail",
                "severity": "low",
                "count": 9,
                "group": "Lieferanten",
            },
        ],
        "latest_scan_id": None,
        "selected_scan_id": None,
        "tenant_id": None,
        "scan_mode_label": _resolve_scan_mode_label(scan_mode),
    }


def _build_dashboard_payload(
    company: str,
    environment: str,
    tenant: Optional[Tenant],
    latest_scan: Optional[Scan],
    selected_scan: Optional[Scan],
    scan_mode: Optional[str],
) -> Dict[str, Any]:
    active_scan = selected_scan or latest_scan

    if tenant is None or active_scan is None:
        return _build_fallback_payload(company=company, environment=environment, scan_mode=scan_mode)

    issues = _load_issues_for_scan(active_scan.scan_id)
    recent_scans = _load_recent_scans_for_tenant(tenant.tenant_id, limit=120)

    high_total = 0
    medium_total = 0
    low_total = 0

    for issue in issues:
        count = _safe_int(issue.affected_count)
        severity = _normalize_severity(issue.severity)

        if severity == "high":
            high_total += count
        elif severity == "medium":
            medium_total += count
        else:
            low_total += count

    group_totals: Dict[str, int] = {}
    for issue in issues:
        group_name = _issue_group_from_code(issue.code)
        group_totals[group_name] = group_totals.get(group_name, 0) + _safe_int(issue.affected_count)

    issue_groups = [
        {"name": name, "count": count}
        for name, count in sorted(group_totals.items(), key=lambda x: x[1], reverse=True)
    ]

    score_trend = [
        {
            "label": scan.generated_at_utc.strftime("%d.%m. %H:%M"),
            "value": _safe_int(scan.data_score),
        }
        for scan in recent_scans
    ]

    top_findings = [
        {
            "code": issue.code,
            "title": issue.title,
            "severity": _normalize_severity(issue.severity),
            "count": _safe_int(issue.affected_count),
            "group": _issue_group_from_code(issue.code),
        }
        for issue in sorted(issues, key=_issue_sort_key)[:10]
    ]

    return {
        "title": "Data Health Management Analytics",
        "subtitle": f"{company} · {environment}",
        "last_updated_utc": active_scan.generated_at_utc.isoformat(),
        "kpis": {
            "health_score": _safe_int(active_scan.data_score),
            "total_issues": _safe_int(active_scan.issues_count),
            "high_issues": high_total,
            "medium_issues": medium_total,
            "low_issues": low_total,
            "checks_run": _safe_int(active_scan.checks_count),
        },
        "issue_groups": issue_groups,
        "score_trend": score_trend,
        "top_findings": top_findings,
        "latest_scan_id": latest_scan.scan_id if latest_scan else active_scan.scan_id,
        "selected_scan_id": active_scan.scan_id,
        "tenant_id": tenant.tenant_id,
        "scan_mode_label": _resolve_scan_mode_label_from_scan(active_scan, scan_mode),
    }


def _issue_matches_filters(
    issue: ScanIssueRecord,
    code: Optional[str],
    severity: Optional[str],
    group: Optional[str],
) -> bool:
    if code and issue.code != code:
        return False

    if severity and _normalize_severity(issue.severity) != _normalize_severity(severity):
        return False

    if group and _issue_group_from_code(issue.code).lower() != group.strip().lower():
        return False

    return True


def _escape_html(value: str) -> str:
    return (
        str(value)
        .replace("&", "&amp;")
        .replace('"', "&quot;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace("'", "&#039;")
    )


def _escape_js(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("\n", "\\n")
        .replace("\r", "")
    )


def _render_issue_details_html(
    company: str,
    environment: str,
    token: str,
    tenant: Optional[Tenant],
    latest_scan: Optional[Scan],
    selected_scan: Optional[Scan],
    code: Optional[str],
    severity: Optional[str],
    group: Optional[str],
) -> str:
    active_scan = selected_scan or latest_scan

    if tenant is None or active_scan is None:
        return f"""
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="utf-8" />
    <title>Issue-Liste</title>
    <style>
        body {{ font-family: Segoe UI, Arial, sans-serif; background:#f3f5f8; margin:0; padding:24px; }}
        .card {{ background:#fff; border:1px solid #e5e7eb; border-radius:16px; padding:24px; }}
    </style>
</head>
<body>
    <div class="card">
        <h1>Keine Scan-Daten gefunden</h1>
        <p>Für {_escape_html(company)} · {_escape_html(environment)} konnte kein gespeicherter Scan geladen werden.</p>
        <p><a href="/analytics/embed?token={_escape_html(token)}">Zurück zum Dashboard</a></p>
    </div>
</body>
</html>
"""

    all_issues = _load_issues_for_scan(active_scan.scan_id)
    filtered_issues = [
        issue for issue in all_issues
        if _issue_matches_filters(issue=issue, code=code, severity=severity, group=group)
    ]

    rows = []
    for issue in filtered_issues:
        recommendation = issue.recommendation_preview or "-"
        rows.append(
            f"""
            <tr>
                <td>{_escape_html(issue.code)}</td>
                <td>{_escape_html(issue.title)}</td>
                <td>{_escape_html(_issue_group_from_code(issue.code))}</td>
                <td>{_escape_html(_normalize_severity(issue.severity))}</td>
                <td>{_safe_int(issue.affected_count)}</td>
                <td>{_escape_html(recommendation)}</td>
            </tr>
            """
        )

    rows_html = "".join(rows) if rows else """
        <tr>
            <td colspan="6">Keine Issues für den aktuellen Filter gefunden.</td>
        </tr>
    """

    filter_parts = []
    if code:
        filter_parts.append(f"Code: {_escape_html(code)}")
    if severity:
        filter_parts.append(f"Severity: {_escape_html(severity)}")
    if group:
        filter_parts.append(f"Bereich: {_escape_html(group)}")

    filter_label = " | ".join(filter_parts) if filter_parts else "Kein Filter"
    scan_query = f"&scan_id={_escape_html(active_scan.scan_id)}"

    return f"""
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <title>Issue-Liste</title>
    <style>
        :root {{
            --bg: #f3f5f8;
            --card: #ffffff;
            --border: #e5e7eb;
            --text: #111827;
            --muted: #6b7280;
        }}
        * {{ box-sizing: border-box; }}
        body {{
            margin: 0;
            padding: 24px;
            background: var(--bg);
            color: var(--text);
            font-family: Segoe UI, Arial, sans-serif;
        }}
        .card {{
            background: var(--card);
            border: 1px solid var(--border);
            border-radius: 18px;
            padding: 24px;
        }}
        h1 {{ margin: 0 0 8px 0; }}
        .sub {{
            color: var(--muted);
            margin-bottom: 20px;
        }}
        .filters {{
            color: var(--muted);
            margin-bottom: 20px;
            font-size: 14px;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            background: white;
        }}
        th, td {{
            text-align: left;
            padding: 12px;
            border-bottom: 1px solid #e5e7eb;
            vertical-align: top;
        }}
        th {{
            background: #f9fafb;
            font-weight: 600;
        }}
        .back-link {{
            display: inline-block;
            margin-bottom: 16px;
            color: #2563eb;
            text-decoration: none;
        }}
    </style>
</head>
<body>
    <a class="back-link" href="/analytics/embed?token={_escape_html(token)}{scan_query}">← Zurück zum Dashboard</a>
    <div class="card">
        <h1>Gefilterte Issue-Liste</h1>
        <div class="sub">{_escape_html(company)} · {_escape_html(environment)} · Scan {_escape_html(active_scan.scan_id)}</div>
        <div class="filters">{filter_label}</div>
        <table>
            <thead>
                <tr>
                    <th>Code</th>
                    <th>Titel</th>
                    <th>Bereich</th>
                    <th>Severity</th>
                    <th>Betroffene Anzahl</th>
                    <th>Empfehlung</th>
                </tr>
            </thead>
            <tbody>
                {rows_html}
            </tbody>
        </table>
    </div>
</body>
</html>
"""


@router.get("/analytics/get-token", response_class=JSONResponse)
async def get_token(
    company: str = Query(...),
    environment: str = Query(...),
    tenant_id: Optional[str] = Query(default=None),
    scan_mode: Optional[str] = Query(default=None),
) -> JSONResponse:
    token = create_token(
        {
            "company": company,
            "environment": environment,
            "tenant_id": tenant_id,
            "scan_mode": scan_mode,
        }
    )
    return JSONResponse(content={"token": token})


@router.get("/analytics/embed/data", response_class=JSONResponse)
async def analytics_embed_data(
    token: str = Query(...),
    scan_id: Optional[str] = Query(default=None),
) -> JSONResponse:
    data = verify_token(token)
    if not data:
        return JSONResponse(status_code=401, content={"error": "invalid token"})

    company = str(data.get("company") or "Unbekannt")
    environment = str(data.get("environment") or "BC Cloud")
    tenant_id = data.get("tenant_id")
    scan_mode = data.get("scan_mode")

    tenant = _resolve_tenant(tenant_id=tenant_id, environment=environment)
    latest_scan = _load_latest_scan_for_tenant(tenant.tenant_id) if tenant else None
    selected_scan = _load_scan_by_id_for_tenant(tenant.tenant_id, scan_id) if tenant and scan_id else None

    payload = _build_dashboard_payload(
        company=company,
        environment=environment,
        tenant=tenant,
        latest_scan=latest_scan,
        selected_scan=selected_scan,
        scan_mode=scan_mode,
    )
    return JSONResponse(content=payload)


@router.get("/analytics/scans/calendar", response_class=JSONResponse)
async def analytics_scans_calendar(
    token: str = Query(...),
    year: Optional[int] = Query(default=None),
    month: Optional[int] = Query(default=None),
) -> JSONResponse:
    data = verify_token(token)
    if not data:
        return JSONResponse(status_code=401, content={"error": "invalid token"})

    environment = str(data.get("environment") or "BC Cloud")
    tenant_id = data.get("tenant_id")
    tenant = _resolve_tenant(tenant_id=tenant_id, environment=environment)

    if tenant is None:
        return JSONResponse(content={"year": year, "month": month, "days": []})

    now = datetime.now(timezone.utc)
    resolved_year = year or now.year
    resolved_month = month or now.month

    if resolved_month < 1 or resolved_month > 12:
        return JSONResponse(status_code=400, content={"error": "invalid month"})

    days = _load_scan_days_for_month(tenant.tenant_id, resolved_year, resolved_month)

    prev_year = resolved_year if resolved_month > 1 else resolved_year - 1
    prev_month = resolved_month - 1 if resolved_month > 1 else 12
    next_year = resolved_year if resolved_month < 12 else resolved_year + 1
    next_month = resolved_month + 1 if resolved_month < 12 else 1

    return JSONResponse(
        content={
            "year": resolved_year,
            "month": resolved_month,
            "month_label": f"{calendar.month_name[resolved_month]} {resolved_year}",
            "days": days,
            "previous": {"year": prev_year, "month": prev_month},
            "next": {"year": next_year, "month": next_month},
        }
    )


@router.get("/analytics/scans/day", response_class=JSONResponse)
async def analytics_scans_day(
    token: str = Query(...),
    date: str = Query(...),
) -> JSONResponse:
    data = verify_token(token)
    if not data:
        return JSONResponse(status_code=401, content={"error": "invalid token"})

    environment = str(data.get("environment") or "BC Cloud")
    tenant_id = data.get("tenant_id")
    tenant = _resolve_tenant(tenant_id=tenant_id, environment=environment)

    if tenant is None:
        return JSONResponse(content={"date": date, "scans": []})

    scans = _load_scans_for_day(tenant.tenant_id, date)
    return JSONResponse(content={"date": date, "scans": scans})


@router.get("/analytics/issues", response_class=HTMLResponse)
async def analytics_issues(
    token: str = Query(...),
    scan_id: Optional[str] = Query(default=None),
    code: Optional[str] = Query(default=None),
    severity: Optional[str] = Query(default=None),
    group: Optional[str] = Query(default=None),
) -> HTMLResponse:
    data = verify_token(token)
    if not data:
        raise HTTPException(status_code=401, detail="Invalid token")

    company = str(data.get("company") or "Unbekannt")
    environment = str(data.get("environment") or "BC Cloud")
    tenant_id = data.get("tenant_id")

    tenant = _resolve_tenant(tenant_id=tenant_id, environment=environment)
    latest_scan = _load_latest_scan_for_tenant(tenant.tenant_id) if tenant else None
    selected_scan = _load_scan_by_id_for_tenant(tenant.tenant_id, scan_id) if tenant and scan_id else None

    html = _render_issue_details_html(
        company=company,
        environment=environment,
        token=token,
        tenant=tenant,
        latest_scan=latest_scan,
        selected_scan=selected_scan,
        code=code,
        severity=severity,
        group=group,
    )
    return HTMLResponse(content=html)


@router.get("/analytics/embed", response_class=HTMLResponse)
async def analytics_embed(
    token: str = Query(...),
    scan_id: Optional[str] = Query(default=None),
) -> HTMLResponse:
    data = verify_token(token)
    if not data:
        raise HTTPException(status_code=401, detail="Invalid token")

    company = str(data.get("company") or "Unbekannt")
    environment = str(data.get("environment") or "BC Cloud")

    token_js = _escape_js(token)
    company_js = _escape_js(company)
    environment_js = _escape_js(environment)
    initial_scan_id_js = _escape_js(scan_id or "")

    html = f"""
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <title>Data Health Management Analytics</title>
    <style>
        :root {{
            --bg: #f3f5f8;
            --card: #ffffff;
            --border: #e5e7eb;
            --text: #111827;
            --muted: #6b7280;
            --good: #16a34a;
            --warn: #d97706;
            --bad: #dc2626;
            --shadow: 0 8px 24px rgba(15, 23, 42, 0.06);
            --radius: 18px;
            --scan-free-text: #2f6fed;
            --scan-free-bg: #e8f0ff;
            --scan-premium-text: #d97706;
            --scan-premium-bg: #fff1e6;
            --critical-bg: rgba(239, 68, 68, 0.10);
            --fair-bg: rgba(245, 158, 11, 0.10);
            --good-bg: rgba(34, 197, 94, 0.10);
            --line-blue: #3b82f6;
            --selected: #eaf2ff;
        }}
        * {{ box-sizing: border-box; }}
        html, body {{
            margin: 0;
            padding: 0;
            background: var(--bg);
            color: var(--text);
            font-family: Segoe UI, Arial, sans-serif;
        }}
        .page {{ padding: 24px; }}
        .header {{
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            gap: 16px;
            margin-bottom: 20px;
        }}
        .title-wrap h1 {{
            margin: 0;
            font-size: 28px;
            line-height: 1.2;
        }}
        .title-wrap p {{
            margin: 8px 0 0 0;
            color: var(--muted);
            font-size: 14px;
        }}
        .badge {{
            display: inline-flex;
            align-items: center;
            border-radius: 999px;
            padding: 8px 16px;
            font-size: 13px;
            font-weight: 600;
            line-height: 1;
            white-space: nowrap;
        }}
        .badge-neutral {{
            background: var(--card);
            border: 1px solid var(--border);
            box-shadow: var(--shadow);
            color: var(--muted);
        }}
        .badge-scan-free {{
            background: var(--scan-free-bg);
            color: var(--scan-free-text);
            border: 1px solid transparent;
            box-shadow: none;
        }}
        .badge-scan-premium {{
            background: var(--scan-premium-bg);
            color: var(--scan-premium-text);
            border: 1px solid transparent;
            box-shadow: none;
        }}
        .selector-layout {{
            display: grid;
            grid-template-columns: 360px 1fr;
            gap: 20px;
            margin-bottom: 20px;
        }}
        .selector-card {{
            background: var(--card);
            border: 1px solid var(--border);
            border-radius: var(--radius);
            box-shadow: var(--shadow);
            padding: 18px;
        }}
        .selector-card h2 {{
            margin: 0 0 14px 0;
            font-size: 18px;
        }}
        .calendar-toolbar {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 12px;
        }}
        .calendar-nav {{
            border: 1px solid var(--border);
            background: #fff;
            border-radius: 10px;
            padding: 6px 10px;
            cursor: pointer;
        }}
        .calendar-month {{
            font-weight: 600;
            font-size: 14px;
        }}
        .calendar-grid {{
            display: grid;
            grid-template-columns: repeat(7, minmax(0, 1fr));
            gap: 8px;
        }}
        .weekday {{
            text-align: center;
            font-size: 12px;
            color: var(--muted);
            padding: 4px 0;
            font-weight: 600;
        }}
        .day-cell {{
            min-height: 56px;
            border: 1px solid var(--border);
            background: #fff;
            border-radius: 12px;
            padding: 8px 6px;
            position: relative;
            cursor: pointer;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: flex-start;
            transition: transform 0.12s ease, box-shadow 0.12s ease, border-color 0.12s ease;
        }}
        .day-cell:hover {{
            transform: translateY(-1px);
            box-shadow: 0 8px 20px rgba(15, 23, 42, 0.06);
        }}
        .day-cell.empty {{
            visibility: hidden;
            pointer-events: none;
        }}
        .day-cell.selected {{
            background: var(--selected);
            border-color: #93c5fd;
        }}
        .day-number {{
            font-size: 13px;
            font-weight: 600;
        }}
        .day-marker {{
            width: 8px;
            height: 8px;
            border-radius: 999px;
            background: var(--line-blue);
            margin-top: 6px;
        }}
        .day-count {{
            margin-top: 5px;
            font-size: 11px;
            color: var(--muted);
        }}
        .scan-list {{
            display: grid;
            gap: 10px;
            max-height: 420px;
            overflow: auto;
        }}
        .scan-list-empty {{
            color: var(--muted);
            font-size: 14px;
            padding-top: 4px;
        }}
        .scan-item {{
            border: 1px solid var(--border);
            border-radius: 14px;
            padding: 12px 14px;
            background: #fff;
            cursor: pointer;
            transition: transform 0.12s ease, box-shadow 0.12s ease, border-color 0.12s ease;
        }}
        .scan-item:hover {{
            transform: translateY(-1px);
            box-shadow: 0 8px 20px rgba(15, 23, 42, 0.06);
        }}
        .scan-item.selected {{
            border-color: #93c5fd;
            background: var(--selected);
        }}
        .scan-item-top {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 8px;
            margin-bottom: 6px;
        }}
        .scan-item-time {{
            font-size: 13px;
            font-weight: 600;
        }}
        .scan-item-type {{
            font-size: 12px;
            color: var(--muted);
        }}
        .scan-item-score {{
            font-size: 13px;
            font-weight: 700;
        }}
        .scan-item-headline {{
            font-size: 13px;
            color: var(--text);
            line-height: 1.35;
        }}
        .grid-kpi {{
            display: grid;
            grid-template-columns: 1.35fr repeat(5, minmax(0, 1fr));
            gap: 16px;
            margin-bottom: 20px;
        }}
        .card {{
            background: var(--card);
            border: 1px solid var(--border);
            border-radius: var(--radius);
            box-shadow: var(--shadow);
        }}
        .kpi {{
            padding: 18px;
            min-height: 120px;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
        }}
        .kpi-label {{
            color: var(--muted);
            font-size: 13px;
            margin-bottom: 10px;
        }}
        .kpi-value {{
            font-size: 34px;
            font-weight: 700;
            line-height: 1;
        }}
        .kpi-sub {{
            margin-top: 10px;
            font-size: 13px;
            color: var(--muted);
        }}
        .kpi-gauge {{
            grid-column: span 1;
            min-height: 240px;
            padding: 16px 18px 18px 18px;
        }}
        .gauge-wrap {{
            display: flex;
            flex-direction: column;
            height: 100%;
        }}
        .gauge-label {{
            color: var(--muted);
            font-size: 13px;
            margin-bottom: 6px;
        }}
        .gauge-value {{
            font-size: 42px;
            font-weight: 700;
            line-height: 1;
            margin-bottom: 10px;
        }}
        .gauge-sub {{
            color: var(--muted);
            font-size: 13px;
            margin-top: 8px;
        }}
        .gauge-host {{
            margin-top: auto;
            width: 100%;
            height: 150px;
        }}
        .layout {{
            display: grid;
            grid-template-columns: 1.2fr 1fr;
            gap: 20px;
        }}
        .panel {{ padding: 20px; }}
        .panel h2 {{
            margin: 0 0 18px 0;
            font-size: 18px;
        }}
        .bars {{
            display: grid;
            gap: 14px;
        }}
        .bar-link {{
            display: block;
            text-decoration: none;
            color: inherit;
        }}
        .bar-row {{
            display: grid;
            grid-template-columns: 140px 1fr 48px;
            align-items: center;
            gap: 12px;
        }}
        .bar-label {{
            font-size: 14px;
            color: var(--text);
        }}
        .bar-track {{
            height: 12px;
            border-radius: 999px;
            background: #edf0f3;
            overflow: hidden;
        }}
        .bar-fill {{
            height: 100%;
            border-radius: 999px;
            background: linear-gradient(90deg, #3b82f6, #60a5fa);
        }}
        .bar-value {{
            text-align: right;
            color: var(--muted);
            font-size: 13px;
        }}
        .trend-host {{
            width: 100%;
            height: 300px;
        }}
        .findings {{
            display: grid;
            gap: 12px;
        }}
        .finding-link {{
            display: block;
            text-decoration: none;
            color: inherit;
        }}
        .finding {{
            border: 1px solid var(--border);
            border-radius: 14px;
            padding: 14px 16px;
            display: grid;
            grid-template-columns: 1fr auto auto;
            gap: 12px;
            align-items: center;
            transition: box-shadow 0.15s ease, transform 0.15s ease;
        }}
        .finding:hover {{
            box-shadow: 0 8px 24px rgba(15, 23, 42, 0.08);
            transform: translateY(-1px);
        }}
        .finding-title {{
            font-size: 14px;
            font-weight: 600;
        }}
        .finding-badge {{
            font-size: 12px;
            border-radius: 999px;
            padding: 6px 10px;
            font-weight: 600;
            text-transform: uppercase;
        }}
        .severity-high {{
            color: var(--bad);
            background: rgba(220, 38, 38, 0.10);
        }}
        .severity-medium {{
            color: var(--warn);
            background: rgba(217, 119, 6, 0.10);
        }}
        .severity-low {{
            color: var(--good);
            background: rgba(22, 163, 74, 0.10);
        }}
        .finding-count {{
            font-size: 14px;
            color: var(--muted);
            min-width: 48px;
            text-align: right;
        }}
        .state {{
            color: var(--muted);
            font-size: 14px;
        }}
        @media (max-width: 1480px) {{
            .selector-layout {{ grid-template-columns: 1fr; }}
            .grid-kpi {{ grid-template-columns: repeat(3, minmax(0, 1fr)); }}
            .kpi-gauge {{ grid-column: span 3; }}
        }}
        @media (max-width: 1280px) {{
            .layout {{ grid-template-columns: 1fr; }}
        }}
        @media (max-width: 760px) {{
            .page {{ padding: 16px; }}
            .header {{ flex-direction: column; }}
            .grid-kpi {{ grid-template-columns: repeat(2, minmax(0, 1fr)); }}
            .kpi-gauge {{ grid-column: span 2; }}
            .bar-row {{ grid-template-columns: 100px 1fr 36px; }}
            .finding {{ grid-template-columns: 1fr; }}
            .finding-count {{ text-align: left; }}
            .selector-layout {{ grid-template-columns: 1fr; }}
        }}
    </style>
</head>
<body>
    <div class="page">
        <div class="header">
            <div class="title-wrap">
                <h1 id="title">Data Health Management Analytics</h1>
                <p id="subtitle">Lade Dashboard ...</p>
            </div>
            <div style="display:flex; gap:12px; flex-wrap:wrap; align-items:flex-start;">
                <div class="badge badge-neutral" id="scan-mode">Scan-Modus wird geladen ...</div>
                <div class="badge badge-neutral" id="updated-at">Aktualisierung läuft ...</div>
            </div>
        </div>

        <div class="selector-layout">
            <div class="selector-card">
                <h2>Scan-Kalender</h2>
                <div class="calendar-toolbar">
                    <button class="calendar-nav" id="calendar-prev" type="button">←</button>
                    <div class="calendar-month" id="calendar-month-label">Lade Monat ...</div>
                    <button class="calendar-nav" id="calendar-next" type="button">→</button>
                </div>
                <div class="calendar-grid" id="calendar-grid"></div>
            </div>

            <div class="selector-card">
                <h2 id="scan-day-title">Scans am Tag</h2>
                <div class="scan-list" id="scan-day-list">
                    <div class="scan-list-empty">Bitte einen Tag auswählen.</div>
                </div>
            </div>
        </div>

        <div class="grid-kpi">
            <div class="card kpi kpi-gauge">
                <div class="gauge-wrap">
                    <div class="gauge-label">Health Score</div>
                    <div class="gauge-value" id="health-score">-</div>
                    <div id="gauge-chart" class="gauge-host"></div>
                    <div class="gauge-sub">Gesamtbewertung der Datenqualität</div>
                </div>
            </div>

            <div class="card kpi"><div><div class="kpi-label">Gesamt-Issues</div><div class="kpi-value" id="total-issues">-</div></div><div class="kpi-sub">Alle aktuell erkannten Auffälligkeiten</div></div>
            <div class="card kpi"><div><div class="kpi-label">High</div><div class="kpi-value" id="high-issues">-</div></div><div class="kpi-sub">Kritische Auffälligkeiten</div></div>
            <div class="card kpi"><div><div class="kpi-label">Medium</div><div class="kpi-value" id="medium-issues">-</div></div><div class="kpi-sub">Mittlere Auffälligkeiten</div></div>
            <div class="card kpi"><div><div class="kpi-label">Low</div><div class="kpi-value" id="low-issues">-</div></div><div class="kpi-sub">Niedrige Auffälligkeiten</div></div>
            <div class="card kpi"><div><div class="kpi-label">Checks</div><div class="kpi-value" id="checks-run">-</div></div><div class="kpi-sub">Ausgeführte Prüfungen</div></div>
        </div>

        <div class="layout">
            <div class="card panel">
                <h2>Issues nach Bereich</h2>
                <div id="issue-groups" class="bars"><div class="state">Lade Daten ...</div></div>
            </div>

            <div class="card panel">
                <h2>Health-Score Trend</h2>
                <div id="score-trend" class="trend-host"><div class="state">Lade Daten ...</div></div>
            </div>

            <div class="card panel" style="grid-column: 1 / -1;">
                <h2>Top Findings</h2>
                <div id="top-findings" class="findings"><div class="state">Lade Daten ...</div></div>
            </div>
        </div>
    </div>

    <script>
        const token = '{token_js}';
        const company = '{company_js}';
        const environment = '{environment_js}';
        const initialScanId = '{initial_scan_id_js}';

        const SCORE_CRITICAL_MAX = 74;
        const SCORE_FAIR_MIN = 75;
        const SCORE_FAIR_MAX = 89;
        const SCORE_GOOD_MIN = 90;

        let selectedScanId = initialScanId || "";
        let selectedDate = "";
        let currentCalendarYear = 0;
        let currentCalendarMonth = 0;
        let calendarDayCounts = {{}};

        function escapeHtml(value) {{
            return String(value)
                .replaceAll("&", "&amp;")
                .replaceAll("<", "&lt;")
                .replaceAll(">", "&gt;")
                .replaceAll('"', "&quot;")
                .replaceAll("'", "&#039;");
        }}

        function setText(id, value) {{
            const element = document.getElementById(id);
            if (element) {{
                element.textContent = value;
            }}
        }}

        function setScanModeBadge(value) {{
            const element = document.getElementById("scan-mode");
            if (!element) return;

            const text = value || "Kostenloser QuickScan";
            element.textContent = text;
            element.className = "badge";

            if (text === "Premium DeepScan") {{
                element.classList.add("badge-scan-premium");
            }} else if (text === "Kostenloser QuickScan") {{
                element.classList.add("badge-scan-free");
            }} else {{
                element.classList.add("badge-neutral");
            }}
        }}

        function formatUtcToLocal(isoValue) {{
            if (!isoValue) return "-";
            const date = new Date(isoValue);
            if (Number.isNaN(date.getTime())) return isoValue;

            return date.toLocaleString("de-DE", {{
                dateStyle: "short",
                timeStyle: "short"
            }});
        }}

        function formatTime(isoValue) {{
            if (!isoValue) return "-";
            const date = new Date(isoValue);
            if (Number.isNaN(date.getTime())) return isoValue;
            return date.toLocaleTimeString("de-DE", {{
                hour: "2-digit",
                minute: "2-digit"
            }});
        }}

        function isoDateFromLocalDate(date) {{
            const year = date.getFullYear();
            const month = String(date.getMonth() + 1).padStart(2, "0");
            const day = String(date.getDate()).padStart(2, "0");
            return `${{year}}-${{month}}-${{day}}`;
        }}

        function scoreToAngle(value) {{
            return -120 + (value / 100) * 240;
        }}

        function buildIssuesUrl(params) {{
            const query = new URLSearchParams({{ token }});
            if (selectedScanId) {{
                query.set("scan_id", selectedScanId);
            }}
            Object.entries(params || {{}}).forEach(([key, value]) => {{
                if (value !== undefined && value !== null && String(value).trim() !== "") {{
                    query.set(key, value);
                }}
            }});
            return "/analytics/issues?" + query.toString();
        }}

        function polarToCartesian(cx, cy, radius, angleDeg) {{
            const angleRad = (angleDeg - 90) * Math.PI / 180.0;
            return {{
                x: cx + (radius * Math.cos(angleRad)),
                y: cy + (radius * Math.sin(angleRad))
            }};
        }}

        function describeArc(cx, cy, radius, startAngle, endAngle) {{
            const start = polarToCartesian(cx, cy, radius, endAngle);
            const end = polarToCartesian(cx, cy, radius, startAngle);
            const largeArcFlag = endAngle - startAngle <= 180 ? "0" : "1";
            return [
                "M", start.x, start.y,
                "A", radius, radius, 0, largeArcFlag, 0, end.x, end.y
            ].join(" ");
        }}

        function renderGauge(score) {{
            const host = document.getElementById("gauge-chart");
            if (!host) return;

            const value = Math.max(0, Math.min(100, Number(score) || 0));
            const width = 420;
            const height = 190;
            const cx = 210;
            const cy = 165;
            const rOuter = 126;
            const rInner = 92;
            const needleAngle = scoreToAngle(value);

            const criticalStart = -120;
            const criticalEnd = scoreToAngle(SCORE_CRITICAL_MAX);
            const fairStart = scoreToAngle(SCORE_FAIR_MIN);
            const fairEnd = scoreToAngle(SCORE_FAIR_MAX);
            const goodStart = scoreToAngle(SCORE_GOOD_MIN);
            const goodEnd = 120;

            const criticalColor = "#ef4444";
            const fairColor = "#f59e0b";
            const goodColor = "#22c55e";

            const needleTip = polarToCartesian(cx, cy, 94, needleAngle);
            const needleLeft = polarToCartesian(cx, cy, 12, needleAngle - 90);
            const needleRight = polarToCartesian(cx, cy, 12, needleAngle + 90);

            host.innerHTML = `
                <svg viewBox="0 0 ${{width}} ${{height}}" width="100%" height="100%" preserveAspectRatio="xMidYMid meet">
                    <defs>
                        <filter id="needleShadow" x="-50%" y="-50%" width="200%" height="200%">
                            <feDropShadow dx="0" dy="2" stdDeviation="3" flood-color="rgba(17,24,39,0.25)"/>
                        </filter>
                    </defs>

                    <path d="${{describeArc(cx, cy, rOuter, criticalStart, criticalEnd)}}" fill="none" stroke="${{criticalColor}}" stroke-width="28" stroke-linecap="round"/>
                    <path d="${{describeArc(cx, cy, rOuter, fairStart, fairEnd)}}" fill="none" stroke="${{fairColor}}" stroke-width="28" stroke-linecap="round"/>
                    <path d="${{describeArc(cx, cy, rOuter, goodStart, goodEnd)}}" fill="none" stroke="${{goodColor}}" stroke-width="28" stroke-linecap="round"/>

                    <path d="${{describeArc(cx, cy, rInner, -120, 120)}}" fill="none" stroke="#eef2f7" stroke-width="12" stroke-linecap="round"/>

                    <text x="58" y="42" font-size="13" font-weight="600" fill="#dc2626">Kritisch</text>
                    <text x="152" y="20" font-size="13" font-weight="600" fill="#d97706">Verbesserungsbedarf</text>
                    <text x="334" y="42" font-size="13" font-weight="600" fill="#16a34a">Gut</text>

                    <g filter="url(#needleShadow)">
                        <polygon
                            points="${{needleLeft.x}},${{needleLeft.y}} ${{needleRight.x}},${{needleRight.y}} ${{needleTip.x}},${{needleTip.y}}"
                            fill="#374151"
                        />
                    </g>

                    <circle cx="${{cx}}" cy="${{cy}}" r="18" fill="#4b5563"/>
                    <circle cx="${{cx}}" cy="${{cy}}" r="12" fill="#111827"/>
                </svg>
            `;
        }}

        function renderIssueGroups(groups) {{
            const container = document.getElementById("issue-groups");
            if (!container) return;

            if (!Array.isArray(groups) || groups.length === 0) {{
                container.innerHTML = '<div class="state">Keine Daten vorhanden.</div>';
                return;
            }}

            const maxValue = Math.max(...groups.map(item => item.count), 1);

            container.innerHTML = groups.map(item => {{
                const width = Math.max(6, Math.round((item.count / maxValue) * 100));
                const targetUrl = buildIssuesUrl({{ group: item.name }});

                return `
                    <a class="bar-link" href="${{targetUrl}}">
                        <div class="bar-row">
                            <div class="bar-label">${{escapeHtml(item.name)}}</div>
                            <div class="bar-track">
                                <div class="bar-fill" style="width:${{width}}%"></div>
                            </div>
                            <div class="bar-value">${{escapeHtml(item.count)}}</div>
                        </div>
                    </a>
                `;
            }}).join("");
        }}

        function renderTrend(trend) {{
            const container = document.getElementById("score-trend");
            if (!container) return;

            if (!Array.isArray(trend) || trend.length === 0) {{
                container.innerHTML = '<div class="state">Keine Trenddaten vorhanden.</div>';
                return;
            }}

            const width = 760;
            const height = 300;
            const paddingTop = 20;
            const paddingRight = 20;
            const paddingBottom = 48;
            const paddingLeft = 44;
            const chartWidth = width - paddingLeft - paddingRight;
            const chartHeight = height - paddingTop - paddingBottom;

            const values = trend.map(item => Math.max(0, Math.min(100, Number(item.value) || 0)));
            const labels = trend.map(item => String(item.label || ""));

            const xFor = index => {{
                if (values.length === 1) return paddingLeft + chartWidth / 2;
                return paddingLeft + (index * chartWidth / (values.length - 1));
            }};

            const yFor = value => paddingTop + ((100 - value) / 100) * chartHeight;

            const points = values.map((value, index) => `${{xFor(index)}},${{yFor(value)}}`).join(" ");
            const polylineFill = [
                `M ${{xFor(0)}} ${{yFor(values[0])}}`,
                values.map((value, index) => `L ${{xFor(index)}} ${{yFor(value)}}`).join(" "),
                `L ${{xFor(values.length - 1)}} ${{paddingTop + chartHeight}}`,
                `L ${{xFor(0)}} ${{paddingTop + chartHeight}} Z`
            ].join(" ");

            const stepLabels = [];
            const labelStep = values.length > 18 ? Math.ceil(values.length / 8) : 1;

            for (let i = 0; i < labels.length; i += labelStep) {{
                stepLabels.push(`
                    <text x="${{xFor(i)}}" y="${{height - 14}}" text-anchor="middle" font-size="11" fill="#6b7280">
                        ${{escapeHtml(labels[i])}}
                    </text>
                `);
            }}

            const dots = values.map((value, index) => `
                <circle cx="${{xFor(index)}}" cy="${{yFor(value)}}" r="4" fill="#3b82f6" stroke="#ffffff" stroke-width="2" />
            `).join("");

            const valueLabels = values.length <= 16
                ? values.map((value, index) => `
                    <text x="${{xFor(index)}}" y="${{yFor(value) - 10}}" text-anchor="middle" font-size="11" fill="#4b5563">
                        ${{escapeHtml(value)}}
                    </text>
                `).join("")
                : "";

            const gridLines = [0, 25, 50, 75, 90, 100].map(v => `
                <g>
                    <line x1="${{paddingLeft}}" y1="${{yFor(v)}}" x2="${{width - paddingRight}}" y2="${{yFor(v)}}" stroke="#e5e7eb" stroke-dasharray="4 4" />
                    <text x="8" y="${{yFor(v) + 4}}" font-size="11" fill="#6b7280">${{v}}</text>
                </g>
            `).join("");

            container.innerHTML = `
                <svg viewBox="0 0 ${{width}} ${{height}}" width="100%" height="100%" preserveAspectRatio="none">
                    <rect x="${{paddingLeft}}" y="${{yFor(100)}}" width="${{chartWidth}}" height="${{yFor(SCORE_GOOD_MIN) - yFor(100)}}" fill="rgba(34,197,94,0.10)" rx="10" />
                    <rect x="${{paddingLeft}}" y="${{yFor(SCORE_FAIR_MAX)}}" width="${{chartWidth}}" height="${{yFor(SCORE_FAIR_MIN) - yFor(SCORE_FAIR_MAX)}}" fill="rgba(245,158,11,0.10)" rx="10" />
                    <rect x="${{paddingLeft}}" y="${{yFor(SCORE_CRITICAL_MAX)}}" width="${{chartWidth}}" height="${{yFor(0) - yFor(SCORE_CRITICAL_MAX)}}" fill="rgba(239,68,68,0.10)" rx="10" />

                    ${{gridLines}}

                    <text x="${{width - 44}}" y="${{yFor(95)}}" font-size="11" fill="#15803d" font-weight="600">Gut</text>
                    <text x="${{width - 132}}" y="${{yFor(82)}}" font-size="11" fill="#b45309" font-weight="600">Verbesserungsbedarf</text>
                    <text x="${{width - 66}}" y="${{yFor(35)}}" font-size="11" fill="#dc2626" font-weight="600">Kritisch</text>

                    <path d="${{polylineFill}}" fill="rgba(59,130,246,0.10)"></path>
                    <polyline fill="none" stroke="#3b82f6" stroke-width="3" points="${{points}}" stroke-linecap="round" stroke-linejoin="round"></polyline>

                    ${{dots}}
                    ${{valueLabels}}
                    ${{stepLabels.join("")}}
                </svg>
            `;
        }}

        function renderFindings(findings) {{
            const container = document.getElementById("top-findings");
            if (!container) return;

            if (!Array.isArray(findings) || findings.length === 0) {{
                container.innerHTML = '<div class="state">Keine Findings vorhanden.</div>';
                return;
            }}

            container.innerHTML = findings.map(item => {{
                const severity = String(item.severity || "low").toLowerCase();
                const severityClass =
                    severity === "high" ? "severity-high" :
                    severity === "medium" ? "severity-medium" :
                    "severity-low";

                const targetUrl = buildIssuesUrl({{
                    code: item.code,
                    severity: item.severity
                }});

                return `
                    <a class="finding-link" href="${{targetUrl}}">
                        <div class="finding">
                            <div class="finding-title">${{escapeHtml(item.title)}}</div>
                            <div class="finding-badge ${{severityClass}}">${{escapeHtml(severity)}}</div>
                            <div class="finding-count">${{escapeHtml(item.count)}}</div>
                        </div>
                    </a>
                `;
            }}).join("");
        }}

        async function fetchJson(url) {{
            const response = await fetch(url, {{
                method: "GET",
                headers: {{ "Accept": "application/json" }}
            }});

            if (!response.ok) {{
                throw new Error("Request failed with status " + response.status);
            }}

            return await response.json();
        }}

        function renderCalendarGrid(year, month) {{
            const grid = document.getElementById("calendar-grid");
            if (!grid) return;

            const weekdayLabels = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"];
            const firstDay = new Date(Date.UTC(year, month - 1, 1));
            const daysInMonth = new Date(Date.UTC(year, month, 0)).getUTCDate();
            const jsWeekday = firstDay.getUTCDay();
            const mondayBasedOffset = jsWeekday === 0 ? 6 : jsWeekday - 1;

            let html = weekdayLabels.map(label => `<div class="weekday">${{label}}</div>`).join("");

            for (let i = 0; i < mondayBasedOffset; i++) {{
                html += '<div class="day-cell empty"></div>';
            }}

            for (let day = 1; day <= daysInMonth; day++) {{
                const dayIso = `${{year}}-${{String(month).padStart(2, "0")}}-${{String(day).padStart(2, "0")}}`;
                const count = calendarDayCounts[dayIso] || 0;
                const selectedClass = selectedDate === dayIso ? "selected" : "";

                html += `
                    <button type="button" class="day-cell ${{selectedClass}}" data-day="${{dayIso}}">
                        <div class="day-number">${{day}}</div>
                        ${{count > 0 ? '<div class="day-marker"></div><div class="day-count">' + count + '</div>' : ''}}
                    </button>
                `;
            }}

            grid.innerHTML = html;

            grid.querySelectorAll("[data-day]").forEach(button => {{
                button.addEventListener("click", async () => {{
                    selectedDate = button.getAttribute("data-day") || "";
                    renderCalendarGrid(currentCalendarYear, currentCalendarMonth);
                    await loadScansForSelectedDay();
                }});
            }});
        }}

        async function loadCalendar(year, month) {{
            const query = new URLSearchParams({{ token, year: String(year), month: String(month) }});
            const data = await fetchJson("/analytics/scans/calendar?" + query.toString());

            currentCalendarYear = data.year;
            currentCalendarMonth = data.month;
            calendarDayCounts = {{}};

            (data.days || []).forEach(item => {{
                calendarDayCounts[String(item.date)] = Number(item.count) || 0;
            }});

            const label = document.getElementById("calendar-month-label");
            if (label) {{
                label.textContent = data.month_label || `${{month}}/${{year}}`;
            }}

            renderCalendarGrid(currentCalendarYear, currentCalendarMonth);

            const prev = document.getElementById("calendar-prev");
            const next = document.getElementById("calendar-next");

            if (prev) {{
                prev.onclick = () => loadCalendar(data.previous.year, data.previous.month);
            }}
            if (next) {{
                next.onclick = () => loadCalendar(data.next.year, data.next.month);
            }}

            if (!selectedDate) {{
                const availableDays = Object.keys(calendarDayCounts).sort();
                if (availableDays.length > 0) {{
                    selectedDate = availableDays[availableDays.length - 1];
                    renderCalendarGrid(currentCalendarYear, currentCalendarMonth);
                }}
            }}
        }}

        async function loadScansForSelectedDay() {{
            const title = document.getElementById("scan-day-title");
            const list = document.getElementById("scan-day-list");
            if (!title || !list) return;

            if (!selectedDate) {{
                title.textContent = "Scans am Tag";
                list.innerHTML = '<div class="scan-list-empty">Bitte einen Tag auswählen.</div>';
                return;
            }}

            title.textContent = "Scans am " + selectedDate.split("-").reverse().join(".");

            const query = new URLSearchParams({{ token, date: selectedDate }});
            const data = await fetchJson("/analytics/scans/day?" + query.toString());
            const scans = data.scans || [];

            if (!Array.isArray(scans) || scans.length === 0) {{
                list.innerHTML = '<div class="scan-list-empty">Für diesen Tag liegen keine Scans vor.</div>';
                return;
            }}

            if (!selectedScanId) {{
                selectedScanId = scans[0].scan_id || "";
            }}

            const scanIds = scans.map(s => s.scan_id);
            if (selectedScanId && !scanIds.includes(selectedScanId)) {{
                selectedScanId = scans[0].scan_id || "";
            }}

            list.innerHTML = scans.map(scan => {{
                const selectedClass = scan.scan_id === selectedScanId ? "selected" : "";
                return `
                    <button type="button" class="scan-item ${{selectedClass}}" data-scan-id="${{escapeHtml(scan.scan_id)}}">
                        <div class="scan-item-top">
                            <div>
                                <div class="scan-item-time">${{escapeHtml(formatTime(scan.generated_at_utc))}}</div>
                                <div class="scan-item-type">${{escapeHtml(scan.scan_type || "")}}</div>
                            </div>
                            <div class="scan-item-score">Score ${{escapeHtml(scan.data_score)}}</div>
                        </div>
                        <div class="scan-item-headline">${{escapeHtml(scan.headline || "-")}}</div>
                    </button>
                `;
            }}).join("");

            list.querySelectorAll("[data-scan-id]").forEach(button => {{
                button.addEventListener("click", async () => {{
                    selectedScanId = button.getAttribute("data-scan-id") || "";
                    await loadDashboard();
                    await loadScansForSelectedDay();
                    updateUrl();
                }});
            }});
        }}

        function updateUrl() {{
            const url = new URL(window.location.href);
            if (selectedScanId) {{
                url.searchParams.set("scan_id", selectedScanId);
            }} else {{
                url.searchParams.delete("scan_id");
            }}
            window.history.replaceState({{}}, "", url.toString());
        }}

        async function loadDashboard() {{
            try {{
                const query = new URLSearchParams({{ token }});
                if (selectedScanId) {{
                    query.set("scan_id", selectedScanId);
                }}

                const data = await fetchJson("/analytics/embed/data?" + query.toString());
                const kpis = data.kpis || {{}};
                const healthScore = Number(kpis.health_score ?? 0);

                if (!selectedScanId && data.selected_scan_id) {{
                    selectedScanId = data.selected_scan_id;
                }}

                setText("title", data.title || "Data Health Management Analytics");
                setText("subtitle", data.subtitle || (company + " · " + environment));
                setScanModeBadge(data.scan_mode_label || "Kostenloser QuickScan");
                setText("updated-at", "Letzte Aktualisierung: " + formatUtcToLocal(data.last_updated_utc));

                setText("health-score", kpis.health_score ?? "-");
                setText("total-issues", kpis.total_issues ?? "-");
                setText("high-issues", kpis.high_issues ?? "-");
                setText("medium-issues", kpis.medium_issues ?? "-");
                setText("low-issues", kpis.low_issues ?? "-");
                setText("checks-run", kpis.checks_run ?? "-");

                renderGauge(healthScore);
                renderIssueGroups(data.issue_groups || []);
                renderTrend(data.score_trend || []);
                renderFindings(data.top_findings || []);

                if (data.last_updated_utc) {{
                    const selectedDateFromScan = new Date(data.last_updated_utc);
                    if (!Number.isNaN(selectedDateFromScan.getTime())) {{
                        selectedDate = isoDateFromLocalDate(selectedDateFromScan);
                        const year = selectedDateFromScan.getFullYear();
                        const month = selectedDateFromScan.getMonth() + 1;

                        if (year !== currentCalendarYear || month !== currentCalendarMonth) {{
                            await loadCalendar(year, month);
                        }} else {{
                            renderCalendarGrid(currentCalendarYear, currentCalendarMonth);
                        }}
                    }}
                }}

                updateUrl();
            }} catch (error) {{
                setText("subtitle", "Dashboard konnte nicht geladen werden.");
                setScanModeBadge("Scan-Modus unbekannt");
                setText("updated-at", "Fehler beim Laden");

                ["issue-groups", "score-trend", "top-findings", "gauge-chart"].forEach(id => {{
                    const element = document.getElementById(id);
                    if (element) {{
                        element.innerHTML = '<div class="state">Fehler beim Laden der Daten.</div>';
                    }}
                }});
            }}
        }}

        async function initDashboard() {{
            const now = new Date();
            await loadCalendar(now.getFullYear(), now.getMonth() + 1);
            await loadDashboard();
            await loadScansForSelectedDay();
        }}

        initDashboard();
    </script>
</body>
</html>
"""
    return HTMLResponse(content=html)
