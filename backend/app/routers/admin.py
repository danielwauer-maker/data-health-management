import os
import secrets
from html import escape
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import HTMLResponse
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from sqlalchemy import func, select

from app.db import SessionLocal
from app.models import Scan, Tenant

router = APIRouter(tags=["admin"])
security = HTTPBasic()


def require_admin(credentials: HTTPBasicCredentials = Depends(security)) -> str:
    expected_username = os.getenv("ADMIN_USERNAME", "admin")
    expected_password = os.getenv("ADMIN_PASSWORD", "changeme-now")

    is_username_ok = secrets.compare_digest(credentials.username, expected_username)
    is_password_ok = secrets.compare_digest(credentials.password, expected_password)

    if not (is_username_ok and is_password_ok):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid admin credentials",
            headers={"WWW-Authenticate": "Basic"},
        )

    return credentials.username


def _fmt_dt(value) -> str:
    if value is None:
        return "—"
    try:
        return value.strftime("%Y-%m-%d %H:%M:%S UTC")
    except Exception:
        return str(value)


def _badge(text: str, kind: str) -> str:
    colors = {
        "free": "#475569",
        "standard": "#2563eb",
        "premium": "#7c3aed",
        "trial": "#d97706",
        "active": "#16a34a",
        "expired": "#dc2626",
        "blocked": "#111827",
    }
    color = colors.get((text or "").lower(), "#475569")
    return (
        f'<span style="display:inline-block;padding:4px 10px;border-radius:999px;'
        f'background:{color};color:white;font-size:12px;font-weight:600;">{escape(text or kind)}</span>'
    )


@router.get("/admin/tenants", response_class=HTMLResponse)
def admin_tenants(_: str = Depends(require_admin)) -> HTMLResponse:
    with SessionLocal() as db:
        tenants = db.scalars(
            select(Tenant).order_by(Tenant.created_at_utc.desc())
        ).all()

        tenant_ids = [tenant.tenant_id for tenant in tenants]

        scan_counts_by_tenant = {}
        last_scans_by_tenant = {}

        if tenant_ids:
            scan_count_rows = db.execute(
                select(Scan.tenant_id, func.count(Scan.id))
                .where(Scan.tenant_id.in_(tenant_ids))
                .group_by(Scan.tenant_id)
            ).all()

            for tenant_id, scan_count in scan_count_rows:
                scan_counts_by_tenant[tenant_id] = scan_count

            last_scan_rows = db.execute(
                select(Scan.tenant_id, func.max(Scan.generated_at_utc))
                .where(Scan.tenant_id.in_(tenant_ids))
                .group_by(Scan.tenant_id)
            ).all()

            for tenant_id, last_scan_at in last_scan_rows:
                last_scans_by_tenant[tenant_id] = last_scan_at

    rows = []
    for tenant in tenants:
        tenant_id = tenant.tenant_id
        rows.append(
            f"""
            <tr>
                <td style="padding:12px;border-bottom:1px solid #e5e7eb;">
                    <a href="/admin/tenants/{escape(tenant_id)}" style="color:#2563eb;text-decoration:none;font-weight:600;">
                        {escape(tenant_id)}
                    </a>
                </td>
                <td style="padding:12px;border-bottom:1px solid #e5e7eb;">{escape(tenant.environment_name or "—")}</td>
                <td style="padding:12px;border-bottom:1px solid #e5e7eb;">{escape(tenant.app_version or "—")}</td>
                <td style="padding:12px;border-bottom:1px solid #e5e7eb;">{_fmt_dt(tenant.created_at_utc)}</td>
                <td style="padding:12px;border-bottom:1px solid #e5e7eb;">{_fmt_dt(tenant.last_seen_at_utc)}</td>
                <td style="padding:12px;border-bottom:1px solid #e5e7eb;">{_badge(tenant.current_plan or "free", "plan")}</td>
                <td style="padding:12px;border-bottom:1px solid #e5e7eb;">{_badge(tenant.license_status or "trial", "status")}</td>
                <td style="padding:12px;border-bottom:1px solid #e5e7eb;text-align:right;">{scan_counts_by_tenant.get(tenant_id, 0)}</td>
                <td style="padding:12px;border-bottom:1px solid #e5e7eb;">{_fmt_dt(last_scans_by_tenant.get(tenant_id))}</td>
            </tr>
            """
        )

    html = f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="utf-8">
        <title>BCSentinel Admin – Tenants</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
    </head>
    <body style="margin:0;background:#f8fafc;font-family:Arial,sans-serif;color:#0f172a;">
        <div style="max-width:1400px;margin:0 auto;padding:32px;">
            <h1 style="margin:0 0 8px 0;">BCSentinel Admin</h1>
            <p style="margin:0 0 24px 0;color:#475569;">Tenant overview</p>

            <div style="background:white;border:1px solid #e5e7eb;border-radius:16px;overflow:hidden;">
                <table style="width:100%;border-collapse:collapse;font-size:14px;">
                    <thead>
                        <tr style="background:#f1f5f9;text-align:left;">
                            <th style="padding:12px;">Tenant ID</th>
                            <th style="padding:12px;">Environment</th>
                            <th style="padding:12px;">App Version</th>
                            <th style="padding:12px;">Created At</th>
                            <th style="padding:12px;">Last Seen</th>
                            <th style="padding:12px;">Plan</th>
                            <th style="padding:12px;">License Status</th>
                            <th style="padding:12px;text-align:right;">Scan Count</th>
                            <th style="padding:12px;">Last Scan</th>
                        </tr>
                    </thead>
                    <tbody>
                        {''.join(rows) if rows else '<tr><td colspan="9" style="padding:24px;color:#64748b;">No tenants found.</td></tr>'}
                    </tbody>
                </table>
            </div>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html)


@router.get("/admin/tenants/{tenant_id}", response_class=HTMLResponse)
def admin_tenant_detail(tenant_id: str, _: str = Depends(require_admin)) -> HTMLResponse:
    with SessionLocal() as db:
        tenant = db.scalar(
            select(Tenant).where(Tenant.tenant_id == tenant_id)
        )
        if tenant is None:
            raise HTTPException(status_code=404, detail="Tenant not found.")

        scan_count = db.scalar(
            select(func.count(Scan.id)).where(Scan.tenant_id == tenant_id)
        ) or 0

        last_scan: Optional[Scan] = db.scalar(
            select(Scan)
            .where(Scan.tenant_id == tenant_id)
            .order_by(Scan.generated_at_utc.desc())
            .limit(1)
        )

    html = f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="utf-8">
        <title>BCSentinel Admin – {escape(tenant_id)}</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
    </head>
    <body style="margin:0;background:#f8fafc;font-family:Arial,sans-serif;color:#0f172a;">
        <div style="max-width:1100px;margin:0 auto;padding:32px;">
            <p style="margin:0 0 16px 0;"><a href="/admin/tenants" style="color:#2563eb;text-decoration:none;">← Back to tenants</a></p>
            <h1 style="margin:0 0 24px 0;">Tenant Detail</h1>

            <div style="background:white;border:1px solid #e5e7eb;border-radius:16px;padding:24px;">
                <div style="display:grid;grid-template-columns:220px 1fr;gap:12px;font-size:14px;">
                    <div style="color:#475569;">Tenant ID</div><div>{escape(tenant.tenant_id)}</div>
                    <div style="color:#475569;">Environment</div><div>{escape(tenant.environment_name or "—")}</div>
                    <div style="color:#475569;">App Version</div><div>{escape(tenant.app_version or "—")}</div>
                    <div style="color:#475569;">Created At</div><div>{_fmt_dt(tenant.created_at_utc)}</div>
                    <div style="color:#475569;">Last Seen</div><div>{_fmt_dt(tenant.last_seen_at_utc)}</div>
                    <div style="color:#475569;">Plan</div><div>{_badge(tenant.current_plan or "free", "plan")}</div>
                    <div style="color:#475569;">License Status</div><div>{_badge(tenant.license_status or "trial", "status")}</div>
                    <div style="color:#475569;">Scan Count</div><div>{scan_count}</div>
                    <div style="color:#475569;">Last Scan ID</div><div>{escape(last_scan.scan_id) if last_scan else "—"}</div>
                    <div style="color:#475569;">Last Scan Type</div><div>{escape(last_scan.scan_type) if last_scan else "—"}</div>
                    <div style="color:#475569;">Last Scan At</div><div>{_fmt_dt(last_scan.generated_at_utc) if last_scan else "—"}</div>
                    <div style="color:#475569;">Last Score</div><div>{str(last_scan.data_score) if last_scan else "—"}</div>
                    <div style="color:#475569;">Last Issues</div><div>{str(last_scan.issues_count) if last_scan else "—"}</div>
                </div>
            </div>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html)
