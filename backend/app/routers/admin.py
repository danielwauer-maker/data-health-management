import secrets
import smtplib
from io import StringIO
from pathlib import Path
from urllib.parse import quote_plus
import csv
from email.mime.text import MIMEText

from fastapi import APIRouter, Depends, Form, HTTPException, Request, status
from fastapi.responses import HTMLResponse, RedirectResponse, Response
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from fastapi.templating import Jinja2Templates
from sqlalchemy import func, or_, select

from app.core.settings import settings
from app.db import SessionLocal
from app.models import (
    AdminAuditEvent,
    BillingWebhookEvent,
    Invoice,
    IssueCostConfig,
    LicensePricingConfig,
    Partner,
    PartnerApplication,
    PartnerCommission,
    PartnerReferral,
    Scan,
    Subscription,
    Tenant,
)
from app.services.cost_service import ensure_default_issue_costs
from app.services.pricing_service import ensure_default_license_pricing
from app.services.billing_service import utc_now
from app.services.admin_audit_service import log_admin_event
from app.services.email_template_service import (
    DEFAULT_ADMIN_EMAIL_TEMPLATES,
    list_email_templates_for_admin,
    render_email_template,
    render_email_template_preview,
    update_email_template,
)
from app.services.partner_service import normalize_partner_code
from app.security.token_hash import hash_api_token
from app.security.token import create_token

router = APIRouter(tags=["admin"])
security = HTTPBasic()
TEMPLATES = Jinja2Templates(
    directory=str(Path(__file__).resolve().parent.parent / "templates")
)

ALLOWED_PLANS = {"free", "premium"}
ALLOWED_LICENSE_STATUSES = {"trial", "active", "expired", "blocked"}
ALLOWED_COMMISSION_STATUSES = {"pending", "approved", "paid", "rejected"}
ALLOWED_PARTNER_STATUSES = {"active", "inactive"}
ALLOWED_PARTNER_APPLICATION_STATUSES = {"new", "reviewed", "accepted", "rejected"}
ADMIN_SECTION_META = {
    "tenants": {
        "label": "Tenants",
        "href": "/admin/tenants",
        "subtitle": "aktive BC Cloud Umgebungen",
    },
    "issue_costs": {
        "label": "Issue Cost",
        "href": "/admin/config/issue-costs",
        "subtitle": "EUR pro betroffenem Datensatz",
    },
    "license_pricing": {
        "label": "License Pricing",
        "href": "/admin/config/license-pricing",
        "subtitle": "Planpreise und Freemium-Konfiguration",
    },
    "partners": {
        "label": "Partners",
        "href": "/admin/partners",
        "subtitle": "Partnerstammdaten und Zugangsdaten",
    },
    "partner_commissions": {
        "label": "Recent Partner Commissions",
        "href": "/admin/partners/commissions",
        "subtitle": "letzte 50 Provisionen",
    },
    "partner_applications": {
        "label": "Partner Applications",
        "href": "/admin/partners/applications",
        "subtitle": "oeffentliche Registrierungen mit Review-Workflow",
    },
    "payouts": {
        "label": "Payout Overview",
        "href": "/admin/commissions/payouts",
        "subtitle": "aggregiert je Partner und Waehrung",
    },
    "audit": {
        "label": "Admin Audit",
        "href": "/admin/audit",
        "subtitle": "letzte Admin-Aktionen",
    },
    "email_templates": {
        "label": "Mail Templates",
        "href": "/admin/config/email-templates",
        "subtitle": "Partner-Mails direkt im Admin anpassen",
    },
}
ADMIN_NAV_ORDER = [
    "tenants",
    "issue_costs",
    "license_pricing",
    "partners",
    "partner_commissions",
    "partner_applications",
    "payouts",
    "audit",
    "email_templates",
]


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


def _fmt_money(value) -> str:
    try:
        return f"{float(value or 0.0):.2f}"
    except (TypeError, ValueError):
        return "0.00"


def _normalize_email(value: str | None) -> str | None:
    normalized = (value or "").strip().lower()
    return normalized or None


def _partner_reset_url(request: Request, token: str) -> str:
    base = (settings.PARTNER_RESET_URL_BASE or "").strip()
    if base:
        base = base.rstrip("/")
    else:
        base = str(request.base_url).rstrip("/")
    return f"{base}/partner-reset-password.html?token={token}"


def _send_partner_access_invite_email(
    target_email: str,
    contact_name: str,
    reset_url: str,
) -> tuple[bool, str | None]:
    host = (settings.SMTP_HOST or "").strip()
    from_email = (settings.SMTP_FROM_EMAIL or "").strip()
    if not host or not from_email:
        return False, "SMTP not configured."

    display_name = (contact_name or "").strip() or "Partner"
    with SessionLocal() as db:
        subject, html_body = render_email_template(
            db,
            "partner_access_invite",
            {
                "contact_name": display_name,
                "reset_url": reset_url,
            },
        )
    return _send_html_email(target_email=target_email, subject=subject, html_body=html_body)


def _send_html_email(
    *,
    target_email: str,
    subject: str,
    html_body: str,
) -> tuple[bool, str | None]:
    host = (settings.SMTP_HOST or "").strip()
    from_email = (settings.SMTP_FROM_EMAIL or "").strip()
    if not host or not from_email:
        return False, "SMTP not configured."

    msg = MIMEText(html_body, "html", "utf-8")
    msg["Subject"] = subject
    msg["From"] = (
        f"{settings.SMTP_FROM_NAME} <{from_email}>"
        if settings.SMTP_FROM_NAME
        else from_email
    )
    msg["To"] = target_email

    try:
        with smtplib.SMTP(host, settings.SMTP_PORT, timeout=15) as smtp:
            if settings.SMTP_USE_TLS:
                smtp.starttls()
            username = (settings.SMTP_USERNAME or "").strip()
            password = settings.SMTP_PASSWORD or ""
            if username:
                smtp.login(username, password)
            smtp.sendmail(from_email, [target_email], msg.as_string())
        return True, None
    except Exception as exc:
        return False, str(exc)


def _build_email_template_test_context(request: Request) -> dict[str, str]:
    return {
        "contact_name": "Max Mustermann",
        "reset_url": _partner_reset_url(request, "test-token"),
    }


def _derive_partner_code_seed(company_name: str, contact_name: str) -> str:
    raw = f"{company_name} {contact_name}".strip().lower()
    cleaned = "".join(ch if ch.isalnum() else "-" for ch in raw)
    compact = "-".join(part for part in cleaned.split("-") if part)
    return normalize_partner_code(compact[:30] or "partner") or "partner"


def _unique_partner_code(db, seed: str) -> str:
    base = normalize_partner_code(seed) or "partner"
    if db.scalar(select(Partner).where(Partner.partner_code == base)) is None:
        return base
    idx = 2
    while idx < 1000:
        candidate = normalize_partner_code(f"{base[:32]}-{idx}") or f"partner-{idx}"
        if db.scalar(select(Partner).where(Partner.partner_code == candidate)) is None:
            return candidate
        idx += 1
    raise HTTPException(status_code=500, detail="Could not allocate unique partner_code.")


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
    latest_subscriptions = (
        db.scalars(select(Subscription).order_by(Subscription.tenant_id.asc(), Subscription.updated_at_utc.desc()))
        .all()
    )
    latest_subscription_map: dict[str, Subscription] = {}
    for sub in latest_subscriptions:
        if sub.tenant_id not in latest_subscription_map:
            latest_subscription_map[sub.tenant_id] = sub

    for idx, tenant in enumerate(tenants, start=1):
        latest_subscription = latest_subscription_map.get(tenant.tenant_id)
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
                "billing_provider": latest_subscription.provider if latest_subscription else "—",
                "billing_status": latest_subscription.status if latest_subscription else "—",
            }
        )
    return rows


def _load_partner_payout_rows(db):
    approved = db.execute(
        select(
            Partner.id,
            Partner.name,
            Partner.partner_code,
            PartnerCommission.currency,
            func.count(PartnerCommission.id),
            func.coalesce(func.sum(PartnerCommission.commission_amount), 0.0),
        )
        .join(PartnerCommission, PartnerCommission.partner_id == Partner.id)
        .where(PartnerCommission.status == "approved")
        .group_by(
            Partner.id,
            Partner.name,
            Partner.partner_code,
            PartnerCommission.currency,
        )
        .order_by(Partner.name.asc(), PartnerCommission.currency.asc())
    ).all()

    rows = []
    for partner_id, name, partner_code, currency, items_count, total_amount in approved:
        rows.append(
            {
                "partner_id": int(partner_id),
                "partner_name": name,
                "partner_code": partner_code,
                "currency": (currency or "EUR").upper(),
                "items_count": int(items_count or 0),
                "approved_total": float(total_amount or 0.0),
            }
        )
    return rows


def _build_admin_nav(active_section: str) -> list[dict[str, str | bool]]:
    nav = []
    for key in ADMIN_NAV_ORDER:
        item = ADMIN_SECTION_META[key]
        nav.append(
            {
                "key": key,
                "label": item["label"],
                "href": item["href"],
                "active": key == active_section,
            }
        )
    return nav


def _load_partner_application_context(db, request: Request) -> dict:
    app_status_filter = (request.query_params.get("app_status") or "").strip().lower()
    mail_status_filter = (request.query_params.get("mail_status") or "").strip().lower()
    app_search = (request.query_params.get("app_search") or "").strip()

    app_query = select(PartnerApplication)
    if app_status_filter:
        app_query = app_query.where(PartnerApplication.status == app_status_filter)
    if mail_status_filter:
        app_query = app_query.where(PartnerApplication.mail_status == mail_status_filter)
    if app_search:
        needle = f"%{app_search}%"
        app_query = app_query.where(
            or_(
                PartnerApplication.company_name.ilike(needle),
                PartnerApplication.contact_name.ilike(needle),
                PartnerApplication.contact_email.ilike(needle),
            )
        )

    return {
        "partner_applications": db.scalars(
            app_query.order_by(PartnerApplication.created_at_utc.desc(), PartnerApplication.id.desc()).limit(300)
        ).all(),
        "partner_application_stats": {
            "new_count": int(
                db.scalar(
                    select(func.count(PartnerApplication.id)).where(PartnerApplication.status == "new")
                )
                or 0
            ),
            "accepted_count": int(
                db.scalar(
                    select(func.count(PartnerApplication.id)).where(PartnerApplication.status == "accepted")
                )
                or 0
            ),
            "mail_failed_count": int(
                db.scalar(
                    select(func.count(PartnerApplication.id)).where(PartnerApplication.mail_status == "failed")
                )
                or 0
            ),
            "total_count": int(db.scalar(select(func.count(PartnerApplication.id))) or 0),
        },
        "app_status_filter": app_status_filter,
        "mail_status_filter": mail_status_filter,
        "app_search": app_search,
    }


def _render_admin_page(
    request: Request,
    active_section: str,
):
    section_meta = ADMIN_SECTION_META[active_section]
    context = {
        "request": request,
        "page_title": f"BCSentinel Admin · {section_meta['label']}",
        "active_section": active_section,
        "section_title": section_meta["label"],
        "section_subtitle": section_meta["subtitle"],
        "admin_nav": _build_admin_nav(active_section),
        "fmt_dt": _fmt_dt,
        "fmt_money": _fmt_money,
        "email_template_flash": {
            "status": (request.query_params.get("email_template_status") or "").strip().lower(),
            "message": (request.query_params.get("email_template_message") or "").strip(),
        },
    }

    with SessionLocal() as db:
        ensure_default_issue_costs(db)
        ensure_default_license_pricing(db)

        if active_section == "tenants":
            context["tenants"] = _load_tenant_rows(db)
        elif active_section == "issue_costs":
            context["issue_costs"] = db.scalars(
                select(IssueCostConfig).order_by(IssueCostConfig.code.asc())
            ).all()
        elif active_section == "license_pricing":
            context["license_prices"] = db.scalars(
                select(LicensePricingConfig).order_by(LicensePricingConfig.plan_code.asc())
            ).all()
        elif active_section == "partners":
            context["partners"] = db.scalars(
                select(Partner).order_by(Partner.created_at_utc.desc(), Partner.id.desc())
            ).all()
        elif active_section == "partner_commissions":
            context["recent_commissions"] = db.scalars(
                select(PartnerCommission)
                .order_by(PartnerCommission.created_at_utc.desc(), PartnerCommission.id.desc())
                .limit(50)
            ).all()
        elif active_section == "partner_applications":
            context.update(_load_partner_application_context(db, request))
        elif active_section == "payouts":
            context["payout_rows"] = _load_partner_payout_rows(db)
        elif active_section == "audit":
            context["audit_events"] = db.scalars(
                select(AdminAuditEvent)
                .order_by(AdminAuditEvent.created_at_utc.desc(), AdminAuditEvent.id.desc())
                .limit(20)
            ).all()
        elif active_section == "email_templates":
            context["email_templates"] = list_email_templates_for_admin(db)

        return TEMPLATES.TemplateResponse(
            name="admin_tenants.html",
            context=context,
        )


@router.get("/admin", response_class=HTMLResponse)
def admin_root(_: str = Depends(require_admin)):
    return RedirectResponse(url="/admin/tenants", status_code=status.HTTP_303_SEE_OTHER)


@router.get("/admin/tenants", response_class=HTMLResponse)
@router.get("/admin/tenants/", response_class=HTMLResponse)
def admin_tenants(request: Request, _: str = Depends(require_admin)):
    return _render_admin_page(request, active_section="tenants")


@router.get("/admin/config/issue-costs", response_class=HTMLResponse)
@router.get("/admin/config/issue-costs/", response_class=HTMLResponse)
def admin_issue_costs(request: Request, _: str = Depends(require_admin)):
    return _render_admin_page(request, active_section="issue_costs")


@router.get("/admin/config/license-pricing", response_class=HTMLResponse)
@router.get("/admin/config/license-pricing/", response_class=HTMLResponse)
def admin_license_pricing(request: Request, _: str = Depends(require_admin)):
    return _render_admin_page(request, active_section="license_pricing")


@router.get("/admin/partners", response_class=HTMLResponse)
@router.get("/admin/partners/", response_class=HTMLResponse)
def admin_partners(request: Request, _: str = Depends(require_admin)):
    return _render_admin_page(request, active_section="partners")


@router.get("/admin/partners/commissions", response_class=HTMLResponse)
@router.get("/admin/partners/commissions/", response_class=HTMLResponse)
def admin_partner_commissions(request: Request, _: str = Depends(require_admin)):
    return _render_admin_page(request, active_section="partner_commissions")


@router.get("/admin/partners/applications", response_class=HTMLResponse)
@router.get("/admin/partners/applications/", response_class=HTMLResponse)
def admin_partner_applications(request: Request, _: str = Depends(require_admin)):
    return _render_admin_page(request, active_section="partner_applications")


@router.get("/admin/commissions/payouts", response_class=HTMLResponse)
@router.get("/admin/commissions/payouts/", response_class=HTMLResponse)
def admin_partner_payouts(request: Request, _: str = Depends(require_admin)):
    return _render_admin_page(request, active_section="payouts")


@router.get("/admin/audit", response_class=HTMLResponse)
@router.get("/admin/audit/", response_class=HTMLResponse)
def admin_audit(request: Request, _: str = Depends(require_admin)):
    return _render_admin_page(request, active_section="audit")


@router.get("/admin/config/email-templates", response_class=HTMLResponse)
@router.get("/admin/config/email-templates/", response_class=HTMLResponse)
def admin_email_templates(request: Request, _: str = Depends(require_admin)):
    return _render_admin_page(request, active_section="email_templates")


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
        latest_subscription = db.scalar(
            select(Subscription)
            .where(Subscription.tenant_id == tenant_id)
            .order_by(Subscription.updated_at_utc.desc(), Subscription.id.desc())
            .limit(1)
        )
        invoices = db.scalars(
            select(Invoice)
            .where(Invoice.tenant_id == tenant_id)
            .order_by(Invoice.created_at_utc.desc(), Invoice.id.desc())
            .limit(10)
        ).all()
        webhook_events = db.scalars(
            select(BillingWebhookEvent)
            .order_by(BillingWebhookEvent.received_at_utc.desc(), BillingWebhookEvent.id.desc())
            .limit(20)
        ).all()
        partner_referral = db.scalar(
            select(PartnerReferral)
            .where(PartnerReferral.tenant_id == tenant_id)
            .limit(1)
        )
        partner = None
        if partner_referral is not None:
            partner = db.scalar(select(Partner).where(Partner.id == partner_referral.partner_id))
        partner_commissions = db.scalars(
            select(PartnerCommission)
            .where(PartnerCommission.tenant_id == tenant_id)
            .order_by(PartnerCommission.created_at_utc.desc(), PartnerCommission.id.desc())
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
                "active_section": "tenants",
                "section_title": "Tenant Detail",
                "section_subtitle": f"{tenant.environment_name} · {tenant.app_version}",
                "admin_nav": _build_admin_nav("tenants"),
                "tenant": tenant,
                "tenant_no": tenant_no,
                "scan_count": int(scan_count),
                "last_scan": _fmt_dt(last_scan),
                "created_at": _fmt_dt(tenant.created_at_utc),
                "last_seen_at": _fmt_dt(tenant.last_seen_at_utc),
                "scans": scans,
                "latest_subscription": latest_subscription,
                "invoices": invoices,
                "webhook_events": webhook_events,
                "partner_referral": partner_referral,
                "partner": partner,
                "partner_commissions": partner_commissions,
                "commission_statuses": sorted(ALLOWED_COMMISSION_STATUSES),
                "fmt_dt": _fmt_dt,
                "fmt_money": _fmt_money,
            },
        )


@router.post("/admin/tenants/{tenant_id}/license")
def update_tenant_license(
    tenant_id: str,
    plan: str = Form(...),
    license_status: str = Form(...),
    admin_username: str = Depends(require_admin),
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

        before_plan = tenant.current_plan
        before_license_status = tenant.license_status
        tenant.current_plan = normalized_plan
        tenant.license_status = normalized_license_status
        log_admin_event(
            db,
            admin_username=admin_username,
            action="tenant.license.update",
            target_type="tenant",
            target_id=tenant.tenant_id,
            details={
                "before_plan": before_plan,
                "after_plan": normalized_plan,
                "before_license_status": before_license_status,
                "after_license_status": normalized_license_status,
            },
        )
        db.commit()

    return RedirectResponse(
        url=f"/admin/tenants/{tenant_id}",
        status_code=status.HTTP_303_SEE_OTHER,
    )


@router.post("/admin/tenants/{tenant_id}/delete")
def delete_tenant(tenant_id: str, admin_username: str = Depends(require_admin)):
    with SessionLocal() as db:
        tenant = db.scalar(select(Tenant).where(Tenant.tenant_id == tenant_id))
        if tenant is None:
            raise HTTPException(status_code=404, detail="Tenant not found.")

        log_admin_event(
            db,
            admin_username=admin_username,
            action="tenant.delete",
            target_type="tenant",
            target_id=tenant.tenant_id,
            details={"environment_name": tenant.environment_name},
        )
        db.delete(tenant)
        db.commit()

    return RedirectResponse(url="/admin/tenants", status_code=status.HTTP_303_SEE_OTHER)


@router.post("/admin/config/issue-costs/{code}")
def update_issue_cost(
    code: str,
    title: str = Form(...),
    cost_per_record: float = Form(...),
    is_active: str | None = Form(default=None),
    admin_username: str = Depends(require_admin),
):
    with SessionLocal() as db:
        ensure_default_issue_costs(db)

        row = db.get(IssueCostConfig, code)
        if row is None:
            row = IssueCostConfig(code=code)
            db.add(row)

        before = {
            "title": row.title,
            "cost_per_record": float(row.cost_per_record or 0.0),
            "is_active": bool(row.is_active),
        }
        row.title = title.strip()
        row.cost_per_record = float(cost_per_record)
        row.is_active = is_active == "on"
        log_admin_event(
            db,
            admin_username=admin_username,
            action="config.issue_cost.update",
            target_type="issue_cost_config",
            target_id=code,
            details={
                "before": before,
                "after": {
                    "title": row.title,
                    "cost_per_record": float(row.cost_per_record),
                    "is_active": bool(row.is_active),
                },
            },
        )
        db.commit()

    return RedirectResponse(url="/admin/config/issue-costs", status_code=status.HTTP_303_SEE_OTHER)


@router.post("/admin/config/license-pricing/{plan_code}")
def update_license_pricing(
    plan_code: str,
    display_name: str = Form(...),
    base_price_monthly: float = Form(...),
    included_records: int = Form(...),
    additional_price_per_1000_records: float = Form(...),
    is_active: str | None = Form(default=None),
    admin_username: str = Depends(require_admin),
):
    with SessionLocal() as db:
        ensure_default_license_pricing(db)

        row = db.get(LicensePricingConfig, plan_code)
        if row is None:
            row = LicensePricingConfig(plan_code=plan_code)
            db.add(row)

        before = {
            "display_name": row.display_name,
            "base_price_monthly": float(row.base_price_monthly or 0.0),
            "included_records": int(row.included_records or 0),
            "additional_price_per_1000_records": float(row.additional_price_per_1000_records or 0.0),
            "is_active": bool(row.is_active),
        }
        row.display_name = display_name.strip()
        row.base_price_monthly = float(base_price_monthly)
        row.included_records = int(included_records)
        row.additional_price_per_1000_records = float(additional_price_per_1000_records)
        row.is_active = is_active == "on"
        log_admin_event(
            db,
            admin_username=admin_username,
            action="config.license_pricing.update",
            target_type="license_pricing_config",
            target_id=plan_code,
            details={
                "before": before,
                "after": {
                    "display_name": row.display_name,
                    "base_price_monthly": float(row.base_price_monthly),
                    "included_records": int(row.included_records),
                    "additional_price_per_1000_records": float(row.additional_price_per_1000_records),
                    "is_active": bool(row.is_active),
                },
            },
        )
        db.commit()

    return RedirectResponse(url="/admin/config/license-pricing", status_code=status.HTTP_303_SEE_OTHER)


@router.post("/admin/config/email-templates/{template_key}")
def update_admin_email_template(
    template_key: str,
    subject_template: str = Form(...),
    html_template: str = Form(...),
    admin_username: str = Depends(require_admin),
):
    normalized_key = (template_key or "").strip()
    if normalized_key not in DEFAULT_ADMIN_EMAIL_TEMPLATES:
        raise HTTPException(status_code=404, detail="Email template not found.")
    if not (subject_template or "").strip():
        raise HTTPException(status_code=400, detail="subject_template is required.")
    if not (html_template or "").strip():
        raise HTTPException(status_code=400, detail="html_template is required.")

    with SessionLocal() as db:
        row = update_email_template(
            db,
            key=normalized_key,
            subject_template=subject_template,
            html_template=html_template,
        )
        log_admin_event(
            db,
            admin_username=admin_username,
            action="config.email_template.update",
            target_type="email_template",
            target_id=row.key,
            details={"updated_at_utc": row.updated_at_utc.isoformat()},
        )
        db.commit()

    return RedirectResponse(url="/admin/config/email-templates", status_code=status.HTTP_303_SEE_OTHER)


@router.post("/admin/config/email-templates/{template_key}/test-send")
def test_admin_email_template(
    template_key: str,
    request: Request,
    test_recipient: str = Form(...),
    subject_template: str = Form(...),
    html_template: str = Form(...),
    admin_username: str = Depends(require_admin),
):
    normalized_key = (template_key or "").strip()
    if normalized_key not in DEFAULT_ADMIN_EMAIL_TEMPLATES:
        raise HTTPException(status_code=404, detail="Email template not found.")

    target_email = _normalize_email(test_recipient)
    if target_email is None:
        return RedirectResponse(
            url="/admin/config/email-templates?email_template_status=error&email_template_message="
            + quote_plus("Bitte eine gueltige Test-E-Mail angeben."),
            status_code=status.HTTP_303_SEE_OTHER,
        )

    subject, html_body = render_email_template_preview(
        subject_template=subject_template,
        html_template=html_template,
        context=_build_email_template_test_context(request),
    )
    ok, error = _send_html_email(
        target_email=target_email,
        subject=subject,
        html_body=html_body,
    )

    with SessionLocal() as db:
        log_admin_event(
            db,
            admin_username=admin_username,
            action="config.email_template.test_send",
            target_type="email_template",
            target_id=normalized_key,
            details={
                "recipient": target_email,
                "sent": ok,
                "error": error,
            },
        )
        db.commit()

    if ok:
        message = f"Testmail fuer {normalized_key} an {target_email} versendet."
        status_value = "success"
    else:
        message = error or "Testmail konnte nicht versendet werden."
        status_value = "error"

    return RedirectResponse(
        url="/admin/config/email-templates?email_template_status="
        + quote_plus(status_value)
        + "&email_template_message="
        + quote_plus(message),
        status_code=status.HTTP_303_SEE_OTHER,
    )


@router.post("/admin/commissions/{commission_id}/status")
def update_commission_status(
    commission_id: int,
    status_value: str = Form(...),
    note: str = Form(default=""),
    admin_username: str = Depends(require_admin),
):
    normalized_status = (status_value or "").strip().lower()
    if normalized_status not in ALLOWED_COMMISSION_STATUSES:
        raise HTTPException(status_code=400, detail="Invalid commission status.")

    with SessionLocal() as db:
        commission = db.scalar(
            select(PartnerCommission).where(PartnerCommission.id == commission_id)
        )
        if commission is None:
            raise HTTPException(status_code=404, detail="Commission not found.")

        previous_status = commission.status
        commission.status = normalized_status
        commission.note = (note or "").strip() or None
        if normalized_status == "approved" and commission.approved_at_utc is None:
            commission.approved_at_utc = utc_now()
        if normalized_status == "paid" and commission.paid_at_utc is None:
            commission.paid_at_utc = utc_now()
        log_admin_event(
            db,
            admin_username=admin_username,
            action="commission.status.update",
            target_type="partner_commission",
            target_id=str(commission.id),
            details={
                "tenant_id": commission.tenant_id,
                "provider_invoice_id": commission.provider_invoice_id,
                "before_status": previous_status,
                "after_status": normalized_status,
            },
        )
        db.commit()

        redirect_tenant_id = (commission.tenant_id or "").strip()

    if redirect_tenant_id:
        return RedirectResponse(
            url=f"/admin/tenants/{redirect_tenant_id}",
            status_code=status.HTTP_303_SEE_OTHER,
        )
    return RedirectResponse(url="/admin/partners/commissions", status_code=status.HTTP_303_SEE_OTHER)


@router.post("/admin/partners/create")
def create_partner(
    name: str = Form(...),
    partner_code: str = Form(...),
    contact_email: str = Form(...),
    new_password: str = Form(...),
    default_commission_rate: float = Form(default=0.3),
    status_value: str = Form(default="active"),
    admin_username: str = Depends(require_admin),
):
    normalized_name = (name or "").strip()
    normalized_code = normalize_partner_code(partner_code)
    normalized_email = _normalize_email(contact_email)
    raw_password = (new_password or "").strip()
    normalized_status = (status_value or "").strip().lower()
    normalized_rate = float(default_commission_rate)

    if not normalized_name:
        raise HTTPException(status_code=400, detail="name is required.")
    if not normalized_code:
        raise HTTPException(status_code=400, detail="partner_code is required.")
    if normalized_status not in ALLOWED_PARTNER_STATUSES:
        raise HTTPException(status_code=400, detail="Invalid partner status.")
    if normalized_rate < 0.0 or normalized_rate > 1.0:
        raise HTTPException(status_code=400, detail="default_commission_rate must be between 0 and 1.")
    if normalized_email is None:
        raise HTTPException(status_code=400, detail="contact_email is required.")
    if len(raw_password) < 8:
        raise HTTPException(status_code=400, detail="new_password must be at least 8 characters.")

    with SessionLocal() as db:
        existing = db.scalar(select(Partner).where(Partner.partner_code == normalized_code))
        if existing is not None:
            raise HTTPException(status_code=409, detail="partner_code already exists.")
        existing_email_owner = db.scalar(select(Partner).where(Partner.contact_email == normalized_email))
        if existing_email_owner is not None:
            raise HTTPException(status_code=409, detail="contact_email already exists.")

        row = Partner(
            name=normalized_name,
            partner_code=normalized_code,
            contact_email=normalized_email,
            password_hash=hash_api_token(raw_password),
            status=normalized_status,
            default_commission_rate=normalized_rate,
            created_at_utc=utc_now(),
            updated_at_utc=utc_now(),
        )
        db.add(row)
        log_admin_event(
            db,
            admin_username=admin_username,
            action="partner.create",
            target_type="partner",
            target_id=normalized_code,
            details={
                "name": normalized_name,
                "status": normalized_status,
                "default_commission_rate": normalized_rate,
                "contact_email": normalized_email,
            },
        )
        db.commit()

    return RedirectResponse(url="/admin/partners", status_code=status.HTTP_303_SEE_OTHER)


@router.post("/admin/partners/{partner_id}/update")
def update_partner(
    partner_id: int,
    name: str = Form(...),
    partner_code: str = Form(...),
    contact_email: str = Form(default=""),
    default_commission_rate: float = Form(...),
    status_value: str = Form(...),
    admin_username: str = Depends(require_admin),
):
    normalized_name = (name or "").strip()
    normalized_code = normalize_partner_code(partner_code)
    normalized_email = _normalize_email(contact_email)
    normalized_status = (status_value or "").strip().lower()
    normalized_rate = float(default_commission_rate)

    if not normalized_name:
        raise HTTPException(status_code=400, detail="name is required.")
    if not normalized_code:
        raise HTTPException(status_code=400, detail="partner_code is required.")
    if normalized_status not in ALLOWED_PARTNER_STATUSES:
        raise HTTPException(status_code=400, detail="Invalid partner status.")
    if normalized_rate < 0.0 or normalized_rate > 1.0:
        raise HTTPException(status_code=400, detail="default_commission_rate must be between 0 and 1.")

    with SessionLocal() as db:
        row = db.scalar(select(Partner).where(Partner.id == partner_id))
        if row is None:
            raise HTTPException(status_code=404, detail="Partner not found.")

        existing_code_owner = db.scalar(
            select(Partner).where(Partner.partner_code == normalized_code, Partner.id != partner_id)
        )
        if existing_code_owner is not None:
            raise HTTPException(status_code=409, detail="partner_code already exists.")
        if normalized_email:
            existing_email_owner = db.scalar(
                select(Partner).where(Partner.contact_email == normalized_email, Partner.id != partner_id)
            )
            if existing_email_owner is not None:
                raise HTTPException(status_code=409, detail="contact_email already exists.")

        before = {
            "name": row.name,
            "partner_code": row.partner_code,
            "contact_email": row.contact_email,
            "status": row.status,
            "default_commission_rate": float(row.default_commission_rate or 0.0),
        }
        row.name = normalized_name
        row.partner_code = normalized_code
        row.contact_email = normalized_email
        row.status = normalized_status
        row.default_commission_rate = normalized_rate
        row.updated_at_utc = utc_now()
        log_admin_event(
            db,
            admin_username=admin_username,
            action="partner.update",
            target_type="partner",
            target_id=str(row.id),
            details={
                "before": before,
                "after": {
                    "name": row.name,
                    "partner_code": row.partner_code,
                    "contact_email": row.contact_email,
                    "status": row.status,
                    "default_commission_rate": float(row.default_commission_rate),
                },
            },
        )
        db.commit()

    return RedirectResponse(url="/admin/partners", status_code=status.HTTP_303_SEE_OTHER)


@router.post("/admin/partners/{partner_id}/credentials")
def set_partner_credentials(
    partner_id: int,
    contact_email: str = Form(...),
    new_password: str = Form(...),
    admin_username: str = Depends(require_admin),
):
    normalized_email = _normalize_email(contact_email)
    raw_password = (new_password or "").strip()
    if normalized_email is None:
        raise HTTPException(status_code=400, detail="contact_email is required.")
    if len(raw_password) < 8:
        raise HTTPException(status_code=400, detail="new_password must be at least 8 characters.")

    with SessionLocal() as db:
        partner = db.scalar(select(Partner).where(Partner.id == partner_id))
        if partner is None:
            raise HTTPException(status_code=404, detail="Partner not found.")

        existing_email_owner = db.scalar(
            select(Partner).where(Partner.contact_email == normalized_email, Partner.id != partner_id)
        )
        if existing_email_owner is not None:
            raise HTTPException(status_code=409, detail="contact_email already exists.")

        before_email = partner.contact_email
        partner.contact_email = normalized_email
        partner.password_hash = hash_api_token(raw_password)
        partner.updated_at_utc = utc_now()
        log_admin_event(
            db,
            admin_username=admin_username,
            action="partner.credentials.reset",
            target_type="partner",
            target_id=str(partner.id),
            details={
                "partner_code": partner.partner_code,
                "before_contact_email": before_email,
                "after_contact_email": normalized_email,
                "password_reset": True,
            },
        )
        db.commit()

    return RedirectResponse(url="/admin/partners", status_code=status.HTTP_303_SEE_OTHER)


@router.post("/admin/partners/{partner_id}/reset-link", response_class=HTMLResponse)
def generate_partner_reset_link(
    partner_id: int,
    request: Request,
    admin_username: str = Depends(require_admin),
):
    with SessionLocal() as db:
        partner = db.scalar(select(Partner).where(Partner.id == partner_id))
        if partner is None:
            raise HTTPException(status_code=404, detail="Partner not found.")

        token = create_token(
            {
                "sub": f"partner_reset:{partner.id}",
                "scope": "partner_reset",
                "partner_id": partner.id,
                "partner_code": partner.partner_code,
            }
        )
        reset_url = _partner_reset_url(request, token)
        log_admin_event(
            db,
            admin_username=admin_username,
            action="partner.credentials.reset_link.generate",
            target_type="partner",
            target_id=str(partner.id),
            details={
                "partner_code": partner.partner_code,
                "contact_email": partner.contact_email,
            },
        )
        db.commit()

    html = f"""
    <!doctype html>
    <html><head><meta charset="utf-8"><title>Partner Reset Link</title></head>
    <body style="font-family: Inter, Arial, sans-serif; margin: 24px;">
      <h2>Partner Reset Link</h2>
      <p>Partner: <strong>{partner.partner_code}</strong></p>
      <p>Use this link to reset password:</p>
      <p id="resetUrlWrap"><a id="resetUrl" href="{reset_url}" target="_blank" rel="noopener noreferrer">{reset_url}</a></p>
      <p>
        <button id="copyBtn" type="button" style="min-height: 34px; padding: 0 12px; border-radius: 8px; border: 1px solid #c7d2e7; background: #f5f8ff; cursor: pointer;">Copy Link</button>
        <span id="copyState" style="margin-left: 8px; color:#2f5f2f;"></span>
      </p>
      <p style="color:#666;">Token validity follows TOKEN_EXPIRE_MINUTES from backend settings.</p>
      <p><a href="/admin/partners">Back to Admin</a></p>
      <script>
        const copyBtn = document.getElementById("copyBtn");
        const copyState = document.getElementById("copyState");
        const resetUrl = document.getElementById("resetUrl").href;
        copyBtn.addEventListener("click", async () => {{
          try {{
            await navigator.clipboard.writeText(resetUrl);
            copyState.textContent = "Copied.";
          }} catch (_) {{
            copyState.textContent = "Copy failed. Please copy manually.";
          }}
        }});
      </script>
    </body></html>
    """
    return HTMLResponse(content=html)


@router.post("/admin/partners/{partner_id}/delete")
def delete_partner(
    partner_id: int,
    admin_username: str = Depends(require_admin),
):
    with SessionLocal() as db:
        partner = db.scalar(select(Partner).where(Partner.id == partner_id))
        if partner is None:
            raise HTTPException(status_code=404, detail="Partner not found.")

        referral_count = db.scalar(
            select(func.count(PartnerReferral.id)).where(PartnerReferral.partner_id == partner_id)
        ) or 0
        commission_count = db.scalar(
            select(func.count(PartnerCommission.id)).where(PartnerCommission.partner_id == partner_id)
        ) or 0
        if referral_count > 0 or commission_count > 0:
            raise HTTPException(
                status_code=400,
                detail=(
                    "Partner has linked referrals or commissions and cannot be deleted. "
                    "Please keep partner inactive for audit/history."
                ),
            )

        log_admin_event(
            db,
            admin_username=admin_username,
            action="partner.delete",
            target_type="partner",
            target_id=str(partner.id),
            details={
                "partner_code": partner.partner_code,
                "name": partner.name,
                "contact_email": partner.contact_email,
            },
        )
        db.delete(partner)
        db.commit()

    return RedirectResponse(url="/admin/partners", status_code=status.HTTP_303_SEE_OTHER)


@router.post("/admin/partners/applications/{application_id}/status")
def update_partner_application_status(
    application_id: int,
    request: Request,
    status_value: str = Form(...),
    default_commission_rate: float = Form(default=0.30),
    admin_username: str = Depends(require_admin),
):
    normalized_status = (status_value or "").strip().lower()
    if normalized_status not in ALLOWED_PARTNER_APPLICATION_STATUSES:
        raise HTTPException(status_code=400, detail="Invalid application status.")

    with SessionLocal() as db:
        application = db.scalar(select(PartnerApplication).where(PartnerApplication.id == application_id))
        if application is None:
            raise HTTPException(status_code=404, detail="Partner application not found.")

        before_status = application.status
        application.status = normalized_status
        application.reviewed_at_utc = utc_now() if normalized_status in {"reviewed", "accepted", "rejected"} else None

        created_or_updated_partner_id: int | None = None
        invite_sent = False
        invite_error: str | None = None
        if normalized_status == "accepted":
            normalized_email = _normalize_email(application.contact_email)
            if normalized_email is None:
                raise HTTPException(status_code=400, detail="Application contact_email is invalid.")

            partner = db.scalar(select(Partner).where(Partner.contact_email == normalized_email))
            if partner is None:
                seed = _derive_partner_code_seed(application.company_name, application.contact_name)
                partner = Partner(
                    name=(application.company_name or "").strip() or (application.contact_name or "").strip() or "Partner",
                    partner_code=_unique_partner_code(db, seed),
                    contact_email=normalized_email,
                    status="active",
                    default_commission_rate=float(default_commission_rate),
                    created_at_utc=utc_now(),
                    updated_at_utc=utc_now(),
                )
                db.add(partner)
                db.flush()
            else:
                partner.name = (application.company_name or "").strip() or partner.name
                partner.status = "active"
                partner.default_commission_rate = float(default_commission_rate)
                partner.updated_at_utc = utc_now()

            created_or_updated_partner_id = int(partner.id)
            token = create_token(
                {
                    "sub": f"partner_reset:{partner.id}",
                    "scope": "partner_reset",
                    "partner_id": partner.id,
                    "partner_code": partner.partner_code,
                }
            )
            reset_url = _partner_reset_url(request, token)
            invite_sent, invite_error = _send_partner_access_invite_email(
                target_email=partner.contact_email or "",
                contact_name=application.contact_name,
                reset_url=reset_url,
            )
            application.mail_status = "sent" if invite_sent else "failed"
            application.last_mail_error = None if invite_sent else (invite_error or "invite mail delivery failed")
            application.last_mail_sent_at_utc = utc_now() if invite_sent else None

        log_admin_event(
            db,
            admin_username=admin_username,
            action="partner.application.status.update",
            target_type="partner_application",
            target_id=str(application.id),
            details={
                "before_status": before_status,
                "after_status": normalized_status,
                "partner_id": created_or_updated_partner_id,
                "invite_sent": invite_sent,
                "invite_error": invite_error,
            },
        )
        db.commit()

    return RedirectResponse(url="/admin/partners/applications", status_code=status.HTTP_303_SEE_OTHER)


@router.get("/admin/partners/applications.csv")
def export_partner_applications_csv(_: str = Depends(require_admin)):
    with SessionLocal() as db:
        rows = db.scalars(
            select(PartnerApplication).order_by(PartnerApplication.created_at_utc.desc(), PartnerApplication.id.desc())
        ).all()

    output = StringIO()
    writer = csv.writer(output)
    writer.writerow(
        [
            "id",
            "created_at_utc",
            "company_name",
            "contact_name",
            "contact_email",
            "phone",
            "website",
            "country",
            "status",
            "mail_status",
            "last_mail_error",
            "source_page",
        ]
    )
    for row in rows:
        writer.writerow(
            [
                row.id,
                row.created_at_utc.isoformat() if row.created_at_utc else "",
                row.company_name,
                row.contact_name,
                row.contact_email,
                row.phone or "",
                row.website or "",
                row.country or "",
                row.status,
                row.mail_status,
                row.last_mail_error or "",
                row.source_page or "",
            ]
        )

    csv_data = output.getvalue()
    return Response(
        content=csv_data,
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": 'attachment; filename="partner-applications.csv"'},
    )


@router.post("/admin/tenants/{tenant_id}/referral")
def upsert_tenant_referral(
    tenant_id: str,
    partner_code: str = Form(default=""),
    attribution_source: str = Form(default="admin"),
    admin_username: str = Depends(require_admin),
):
    normalized_partner_code = normalize_partner_code(partner_code)
    normalized_source = (attribution_source or "admin").strip().lower() or "admin"

    with SessionLocal() as db:
        tenant = db.scalar(select(Tenant).where(Tenant.tenant_id == tenant_id))
        if tenant is None:
            raise HTTPException(status_code=404, detail="Tenant not found.")

        referral = db.scalar(
            select(PartnerReferral).where(PartnerReferral.tenant_id == tenant_id).limit(1)
        )

        if not normalized_partner_code:
            if referral is not None:
                previous_partner_id = referral.partner_id
                db.delete(referral)
                log_admin_event(
                    db,
                    admin_username=admin_username,
                    action="tenant.referral.remove",
                    target_type="tenant",
                    target_id=tenant_id,
                    details={"previous_partner_id": previous_partner_id},
                )
                db.commit()
            return RedirectResponse(
                url=f"/admin/tenants/{tenant_id}",
                status_code=status.HTTP_303_SEE_OTHER,
            )

        partner = db.scalar(select(Partner).where(Partner.partner_code == normalized_partner_code))
        if partner is None:
            raise HTTPException(status_code=400, detail="Invalid partner_code.")
        if (partner.status or "").strip().lower() != "active":
            raise HTTPException(status_code=400, detail="Partner is not active.")

        if referral is None:
            referral = PartnerReferral(
                partner_id=partner.id,
                tenant_id=tenant_id,
                referral_code=normalized_partner_code,
                attribution_source=normalized_source,
                attributed_at_utc=utc_now(),
            )
            db.add(referral)
            log_admin_event(
                db,
                admin_username=admin_username,
                action="tenant.referral.create",
                target_type="tenant",
                target_id=tenant_id,
                details={"partner_id": partner.id, "partner_code": normalized_partner_code},
            )
        else:
            before_partner_id = referral.partner_id
            referral.partner_id = partner.id
            referral.referral_code = normalized_partner_code
            referral.attribution_source = normalized_source
            referral.attributed_at_utc = utc_now()
            log_admin_event(
                db,
                admin_username=admin_username,
                action="tenant.referral.update",
                target_type="tenant",
                target_id=tenant_id,
                details={
                    "before_partner_id": before_partner_id,
                    "after_partner_id": partner.id,
                    "partner_code": normalized_partner_code,
                },
            )

        db.commit()

    return RedirectResponse(
        url=f"/admin/tenants/{tenant_id}",
        status_code=status.HTTP_303_SEE_OTHER,
    )


@router.get("/admin/commissions/payouts.csv")
def export_partner_payouts_csv(_: str = Depends(require_admin)):
    with SessionLocal() as db:
        rows = _load_partner_payout_rows(db)

    output = StringIO()
    writer = csv.writer(output)
    writer.writerow(
        [
            "partner_id",
            "partner_name",
            "partner_code",
            "currency",
            "approved_items_count",
            "approved_total",
        ]
    )
    for row in rows:
        writer.writerow(
            [
                row["partner_id"],
                row["partner_name"],
                row["partner_code"],
                row["currency"],
                row["items_count"],
                f'{row["approved_total"]:.2f}',
            ]
        )

    csv_data = output.getvalue()
    return Response(
        content=csv_data,
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": 'attachment; filename="partner-payouts.csv"'},
    )


@router.post("/admin/commissions/payouts/close")
def close_partner_payout(
    partner_id: int = Form(...),
    currency: str = Form(...),
    admin_username: str = Depends(require_admin),
):
    normalized_currency = (currency or "").strip().upper()
    if not normalized_currency:
        raise HTTPException(status_code=400, detail="currency is required.")

    with SessionLocal() as db:
        partner = db.scalar(select(Partner).where(Partner.id == partner_id))
        if partner is None:
            raise HTTPException(status_code=404, detail="Partner not found.")

        rows = db.scalars(
            select(PartnerCommission).where(
                PartnerCommission.partner_id == partner_id,
                PartnerCommission.currency == normalized_currency,
                PartnerCommission.status == "approved",
            )
        ).all()
        closed_at = utc_now()
        for row in rows:
            row.status = "paid"
            if row.approved_at_utc is None:
                row.approved_at_utc = closed_at
            row.paid_at_utc = closed_at
        log_admin_event(
            db,
            admin_username=admin_username,
            action="partner.payout.close",
            target_type="partner",
            target_id=str(partner_id),
            details={
                "currency": normalized_currency,
                "closed_items_count": len(rows),
            },
        )
        db.commit()

    return RedirectResponse(url="/admin/commissions/payouts", status_code=status.HTTP_303_SEE_OTHER)
