import secrets
from pathlib import Path

from fastapi import APIRouter, Depends, Form, HTTPException, Request, status
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from fastapi.templating import Jinja2Templates
from sqlalchemy import func, select

from app.core.settings import settings
from app.db import SessionLocal
from app.models import IssueCostConfig, LicensePricingConfig, Scan, Tenant
from app.services.cost_service import ensure_default_issue_costs
from app.services.pricing_service import ensure_default_license_pricing

router = APIRouter(tags=["admin"])
security = HTTPBasic()
TEMPLATES = Jinja2Templates(
    directory=str(Path(__file__).resolve().parent.parent / "templates")
)

ALLOWED_PLANS = {"free", "premium"}
ALLOWED_LICENSE_STATUSES = {"trial", "active", "expired", "blocked"}


def require_admin(credentials: HTTPBasicCredentials = Depends(security)) -> str:
    expected_username = settings.ADMIN_USERNAME
    expected_password = settings.ADMIN_PASSWORD

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
    return value.strftime("%Y-%m-%d %H:%M:%S UTC")


def _load_tenant_rows(db):
    tenants = db.scalars(select(Tenant).order_by(Tenant.created_at_utc.desc())).all()
    tenant_ids = [tenant.tenant_id for tenant in tenants]
    scan_counts = {}
    last_scans = {}

    if tenant_ids:
        for tenant_id, scan_count in db.execute(
            select(Scan.tenant_id, func.count(Scan.id))
            .where(Scan.tenant_id.in_(tenant_ids))
            .group_by(Scan.tenant_id)
        ).all():
            scan_counts[tenant_id] = int(scan_count)

        for tenant_id, last_scan in db.execute(
            select(Scan.tenant_id, func.max(Scan.generated_at_utc))
            .where(Scan.tenant_id.in_(tenant_ids))
            .group_by(Scan.tenant_id)
        ).all():
            last_scans[tenant_id] = last_scan

    rows = []
    for idx, tenant in enumerate(tenants, start=1):
        rows.append(
            {
                "tenant_no": f"{idx:05d}",
                "tenant_id": tenant.tenant_id,
                "environment_name": tenant.environment_name,
                "app_version": tenant.app_version,
                "created_at": _fmt_dt(tenant.created_at_utc),
                "last_seen_at": _fmt_dt(tenant.last_seen_at_utc),
                "current_plan": tenant.current_plan,
                "license_status": tenant.license_status,
                "scan_count": scan_counts.get(tenant.tenant_id, 0),
                "last_scan": _fmt_dt(last_scans.get(tenant.tenant_id)),
            }
        )
    return rows


@router.get("/admin", response_class=HTMLResponse)
def admin_root(_: str = Depends(require_admin)):
    return RedirectResponse(url="/admin/tenants", status_code=status.HTTP_303_SEE_OTHER)


@router.get("/admin/tenants", response_class=HTMLResponse)
@router.get("/admin/tenants/", response_class=HTMLResponse)
def admin_tenants(request: Request, _: str = Depends(require_admin)):
    with SessionLocal() as db:
        ensure_default_issue_costs(db)
        ensure_default_license_pricing(db)
        return TEMPLATES.TemplateResponse(
            name="admin_tenants.html",
            context={
                "request": request,
                "page_title": "BCSentinel Admin",
                "tenants": _load_tenant_rows(db),
                "issue_costs": db.scalars(
                    select(IssueCostConfig).order_by(IssueCostConfig.code.asc())
                ).all(),
                "license_prices": db.scalars(
                    select(LicensePricingConfig).order_by(LicensePricingConfig.plan_code.asc())
                ).all(),
            },
        )


@router.get("/admin/tenants/{tenant_id}", response_class=HTMLResponse)
@router.get("/admin/tenants/{tenant_id}/", response_class=HTMLResponse)
def admin_tenant_detail(tenant_id: str, request: Request, _: str = Depends(require_admin)):
    with SessionLocal() as db:
        tenant = db.scalar(select(Tenant).where(Tenant.tenant_id == tenant_id))
        if tenant is None:
            raise HTTPException(status_code=404, detail="Tenant not found.")

        scan_count = db.scalar(
            select(func.count(Scan.id)).where(Scan.tenant_id == tenant_id)
        ) or 0
        last_scan = db.scalar(
            select(func.max(Scan.generated_at_utc)).where(Scan.tenant_id == tenant_id)
        )
        scans = db.scalars(
            select(Scan)
            .where(Scan.tenant_id == tenant_id)
            .order_by(Scan.generated_at_utc.desc())
            .limit(20)
        ).all()

        tenant_rows = _load_tenant_rows(db)
        tenant_no = next(
            (row["tenant_no"] for row in tenant_rows if row["tenant_id"] == tenant_id),
            "—",
        )

        return TEMPLATES.TemplateResponse(
            name="admin_tenant_detail.html",
            context={
                "request": request,
                "page_title": f"BCSentinel Admin · {tenant_id}",
                "tenant": tenant,
                "tenant_no": tenant_no,
                "scan_count": int(scan_count),
                "last_scan": _fmt_dt(last_scan),
                "created_at": _fmt_dt(tenant.created_at_utc),
                "last_seen_at": _fmt_dt(tenant.last_seen_at_utc),
                "scans": scans,
            },
        )


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
        tenant = db.scalar(select(Tenant).where(Tenant.tenant_id == tenant_id))
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
def delete_tenant(tenant_id: str, _: str = Depends(require_admin)):
    with SessionLocal() as db:
        tenant = db.scalar(select(Tenant).where(Tenant.tenant_id == tenant_id))
        if tenant is None:
            raise HTTPException(status_code=404, detail="Tenant not found.")

        db.delete(tenant)
        db.commit()

    return RedirectResponse(url="/admin/tenants", status_code=status.HTTP_303_SEE_OTHER)


@router.post("/admin/config/issue-costs/{code}")
def update_issue_cost(
    code: str,
    title: str = Form(...),
    cost_per_record: float = Form(...),
    is_active: str | None = Form(default=None),
    _: str = Depends(require_admin),
):
    with SessionLocal() as db:
        ensure_default_issue_costs(db)

        row = db.get(IssueCostConfig, code)
        if row is None:
            row = IssueCostConfig(code=code)
            db.add(row)

        row.title = title.strip()
        row.cost_per_record = float(cost_per_record)
        row.is_active = is_active == "on"
        db.commit()

    return RedirectResponse(url="/admin/tenants", status_code=status.HTTP_303_SEE_OTHER)


@router.post("/admin/config/license-pricing/{plan_code}")
def update_license_pricing(
    plan_code: str,
    display_name: str = Form(...),
    base_price_monthly: float = Form(...),
    included_records: int = Form(...),
    additional_price_per_1000_records: float = Form(...),
    is_active: str | None = Form(default=None),
    _: str = Depends(require_admin),
):
    with SessionLocal() as db:
        ensure_default_license_pricing(db)

        row = db.get(LicensePricingConfig, plan_code)
        if row is None:
            row = LicensePricingConfig(plan_code=plan_code)
            db.add(row)

        row.display_name = display_name.strip()
        row.base_price_monthly = float(base_price_monthly)
        row.included_records = int(included_records)
        row.additional_price_per_1000_records = float(additional_price_per_1000_records)
        row.is_active = is_active == "on"
        db.commit()

    return RedirectResponse(url="/admin/tenants", status_code=status.HTTP_303_SEE_OTHER)
