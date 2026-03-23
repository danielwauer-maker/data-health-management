import os
import secrets
from html import escape

from fastapi import APIRouter, Depends, Form, HTTPException, status
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from sqlalchemy import func, select

from app.db import SessionLocal
from app.models import Scan, Tenant

router = APIRouter(tags=["admin"])
security = HTTPBasic()

ALLOWED_PLANS = {"free", "standard", "premium"}
ALLOWED_LICENSE_STATUSES = {"trial", "active", "expired", "blocked"}


def require_admin(credentials: HTTPBasicCredentials = Depends(security)) -> str:
    expected_username = os.getenv("ADMIN_USERNAME", "admin")
    expected_password = os.getenv("ADMIN_PASSWORD", "changeme-now")

    is_username_ok = secrets.compare_digest(credentials.username, expected_username)
    is_password_ok = secrets.compare_digest(credentials.password, expected_password)

    if not (is_username_ok and is_password_ok):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
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


def _fmt_tenant_no(value) -> str:
    if value is None:
        return "—"
    try:
        return f"{int(value):05d}"
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


def _select_option(value: str, current: str) -> str:
    selected = ' selected="selected"' if value == current else ""
    return f'<option value="{escape(value)}"{selected}>{escape(value.title())}</option>'


@router.get("/admin/tenants", response_class=HTMLResponse)
def admin_tenants(_: str = Depends(require_admin)) -> HTMLResponse:
    with SessionLocal() as db:
        tenants = db.scalars(
            select(Tenant).order_by(Tenant.tenant_no.asc(), Tenant.created_at_utc.asc(), Tenant.id.asc())
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
                <td style="padding:12px;border-bottom:1px solid #e5e7eb;font-weight:700;">{_fmt_tenant_no(tenant.tenant_no)}</td>
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
                <td style="padding:12px;border-bottom:1px solid #e5e7eb;white-space:nowrap;">
                    <a href="/admin/tenants/{escape(tenant_id)}"
                       style="display:inline-block;background:#2563eb;color:white;text-decoration:none;padding:8px 12px;border-radius:10px;font-weight:600;margin-right:8px;">
                        Open
                    </a>
                    <form method="post"
                          action="/admin/tenants/{escape(tenant_id)}/delete"
                          style="display:inline;"
                          onsubmit="return confirm('Tenant {escape(tenant_id)} wirklich löschen? Alle zugehörigen Scans und Issues werden ebenfalls entfernt.');">
                        <button type="submit"
                                style="background:#dc2626;color:white;border:none;padding:8px 12px;border-radius:10px;cursor:pointer;font-weight:600;">
                            Delete
                        </button>
                    </form>
                </td>
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
        <div style="max-width:1500px;margin:0 auto;padding:32px;">
            <h1 style="margin:0 0 8px 0;">BCSentinel Admin</h1>
            <p style="margin:0 0 24px 0;color:#475569;">Tenant overview</p>

            <div style="background:white;border:1px solid #e5e7eb;border-radius:16px;overflow:hidden;">
                <table style="width:100%;border-collapse:collapse;font-size:14px;">
                    <thead>
                        <tr style="background:#f1f5f9;text-align:left;">
                            <th style="padding:12px;">Nr.</th>
                            <th style="padding:12px;">Tenant ID</th>
                            <th style="padding:12px;">Environment</th>
                            <th style="padding:12px;">App Version</th>
                            <th style="padding:12px;">Created At</th>
                            <th style="padding:12px;">Last Seen</th>
                            <th style="padding:12px;">Plan</th>
                            <th style="padding:12px;">License Status</th>
                            <th style="padding:12px;text-align:right;">Scan Count</th>
                            <th style="padding:12px;">Last Scan</th>
                            <th style="padding:12px;">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {''.join(rows) if rows else '<tr><td colspan="11" style="padding:24px;color:#64748b;">No tenants found.</td></tr>'}
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

        last_scan_at = db.scalar(
            select(func.max(Scan.generated_at_utc)).where(Scan.tenant_id == tenant_id)
        )

        current_plan = (tenant.current_plan or "free").lower()
        current_license_status = (tenant.license_status or "trial").lower()

    html = f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="utf-8">
        <title>BCSentinel Admin – Tenant Detail</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
    </head>
    <body style="margin:0;background:#f8fafc;font-family:Arial,sans-serif;color:#0f172a;">
        <div style="max-width:1100px;margin:0 auto;padding:32px;">
            <div style="margin-bottom:24px;">
                <a href="/admin/tenants" style="color:#2563eb;text-decoration:none;font-weight:600;">← Back to tenants</a>
            </div>

            <h1 style="margin:0 0 8px 0;">BCSentinel Tenant</h1>
            <p style="margin:0 0 24px 0;color:#475569;">{escape(tenant_id)}</p>

            <div style="display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px;margin-bottom:24px;">
                <div style="background:white;border:1px solid #e5e7eb;border-radius:16px;padding:20px;">
                    <div style="font-size:13px;color:#64748b;margin-bottom:8px;">Tenant No.</div>
                    <div style="font-size:28px;font-weight:700;">{_fmt_tenant_no(tenant.tenant_no)}</div>
                </div>
                <div style="background:white;border:1px solid #e5e7eb;border-radius:16px;padding:20px;">
                    <div style="font-size:13px;color:#64748b;margin-bottom:8px;">Tenant ID</div>
                    <div style="font-size:20px;font-weight:700;">{escape(tenant.tenant_id)}</div>
                </div>
                <div style="background:white;border:1px solid #e5e7eb;border-radius:16px;padding:20px;">
                    <div style="font-size:13px;color:#64748b;margin-bottom:8px;">Created At</div>
                    <div style="font-size:18px;font-weight:700;">{_fmt_dt(tenant.created_at_utc)}</div>
                </div>
                <div style="background:white;border:1px solid #e5e7eb;border-radius:16px;padding:20px;">
                    <div style="font-size:13px;color:#64748b;margin-bottom:8px;">Last Seen</div>
                    <div style="font-size:18px;font-weight:700;">{_fmt_dt(tenant.last_seen_at_utc)}</div>
                </div>
                <div style="background:white;border:1px solid #e5e7eb;border-radius:16px;padding:20px;">
                    <div style="font-size:13px;color:#64748b;margin-bottom:8px;">Scan Count</div>
                    <div style="font-size:28px;font-weight:700;">{scan_count}</div>
                </div>
                <div style="background:white;border:1px solid #e5e7eb;border-radius:16px;padding:20px;">
                    <div style="font-size:13px;color:#64748b;margin-bottom:8px;">Last Scan</div>
                    <div style="font-size:18px;font-weight:700;">{_fmt_dt(last_scan_at)}</div>
                </div>
            </div>

            <div style="background:white;border:1px solid #e5e7eb;border-radius:16px;padding:24px;margin-bottom:24px;">
                <h2 style="margin:0 0 16px 0;font-size:20px;">License Management</h2>
                <form method="post" action="/admin/tenants/{escape(tenant_id)}/license">
                    <div style="display:grid;grid-template-columns:180px 1fr;gap:12px;align-items:center;font-size:14px;max-width:700px;">
                        <label for="plan" style="color:#475569;">Plan</label>
                        <select id="plan" name="plan" style="padding:10px;border:1px solid #cbd5e1;border-radius:10px;">
                            {_select_option("free", current_plan)}
                            {_select_option("standard", current_plan)}
                            {_select_option("premium", current_plan)}
                        </select>

                        <label for="license_status" style="color:#475569;">License Status</label>
                        <select id="license_status" name="license_status" style="padding:10px;border:1px solid #cbd5e1;border-radius:10px;">
                            {_select_option("trial", current_license_status)}
                            {_select_option("active", current_license_status)}
                            {_select_option("expired", current_license_status)}
                            {_select_option("blocked", current_license_status)}
                        </select>
                    </div>

                    <div style="margin-top:20px;">
                        <button type="submit" style="background:#2563eb;color:white;border:none;padding:10px 16px;border-radius:10px;cursor:pointer;font-weight:600;">
                            Save License
                        </button>
                    </div>
                </form>
            </div>

            <div style="background:#fff1f2;border:1px solid #fecdd3;border-radius:16px;padding:24px;">
                <h2 style="margin:0 0 12px 0;font-size:20px;color:#9f1239;">Danger Zone</h2>
                <p style="margin:0 0 16px 0;color:#881337;">
                    Deleting this tenant removes the tenant, all scans, and all scan issues permanently.
                </p>
                <form method="post"
                      action="/admin/tenants/{escape(tenant_id)}/delete"
                      onsubmit="return confirm('Tenant {escape(tenant_id)} wirklich dauerhaft löschen? Alle Scans und Findings gehen verloren.');">
                    <button type="submit"
                            style="background:#dc2626;color:white;border:none;padding:10px 16px;border-radius:10px;cursor:pointer;font-weight:600;">
                        Delete Tenant
                    </button>
                </form>
            </div>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html)


@router.post("/admin/tenants/{tenant_id}/license")
def update_tenant_license(
    tenant_id: str,
    plan: str = Form(...),
    license_status: str = Form(...),
    _: str = Depends(require_admin),
):
    normalized_plan = (plan or "").strip().lower()
    normalized_license_status = (license_status or "").strip().lower()

    if normalized_plan not in ALLOWED_PLANS:
        raise HTTPException(status_code=400, detail="Invalid plan.")

    if normalized_license_status not in ALLOWED_LICENSE_STATUSES:
        raise HTTPException(status_code=400, detail="Invalid license status.")

    with SessionLocal() as db:
        tenant = db.scalar(
            select(Tenant).where(Tenant.tenant_id == tenant_id)
        )
        if tenant is None:
            raise HTTPException(status_code=404, detail="Tenant not found.")

        tenant.current_plan = normalized_plan
        tenant.license_status = normalized_license_status
        db.commit()

    return RedirectResponse(
        url=f"/admin/tenants/{tenant_id}",
        status_code=status.HTTP_303_SEE_OTHER,
    )


@router.post("/admin/tenants/{tenant_id}/delete")
def delete_tenant(
    tenant_id: str,
    _: str = Depends(require_admin),
):
    with SessionLocal() as db:
        tenant = db.scalar(
            select(Tenant).where(Tenant.tenant_id == tenant_id)
        )
        if tenant is None:
            raise HTTPException(status_code=404, detail="Tenant not found.")

        db.delete(tenant)
        db.commit()

    return RedirectResponse(
        url="/admin/tenants",
        status_code=status.HTTP_303_SEE_OTHER,
    )
