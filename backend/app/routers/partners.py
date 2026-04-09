from __future__ import annotations

import secrets
import smtplib
import threading
import time
from collections import defaultdict, deque
from email.mime.text import MIMEText
import logging

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field
from sqlalchemy import select

from app.core.settings import settings
from app.db import SessionLocal
from app.models import Partner, PartnerCommission, PartnerReferral, Subscription, Tenant
from app.security.token import create_token, verify_token
from app.security.token_hash import hash_api_token, verify_api_token
from app.security.tenant import enforce_tenant_match, load_authenticated_tenant, require_tenant_headers
from app.services.billing_service import utc_now
from app.services.partner_service import (
    attach_partner_referral_to_tenant,
    get_partner_by_code,
    normalize_partner_code,
)

router = APIRouter(tags=["partners"])
security = HTTPBasic()
partner_bearer = HTTPBearer(auto_error=False)
_RATE_LIMIT_LOCK = threading.Lock()
_RATE_LIMIT_BUCKETS: dict[str, deque[float]] = defaultdict(deque)
logger = logging.getLogger(__name__)


class PartnerCreateRequest(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    partner_code: str = Field(min_length=2, max_length=40)
    default_commission_rate: float = Field(default=0.2, ge=0.0, le=1.0)


class PartnerCreateResponse(BaseModel):
    id: int
    name: str
    partner_code: str
    status: str
    default_commission_rate: float


class AttachReferralRequest(BaseModel):
    tenant_id: str
    partner_code: str
    attribution_source: str = "manual"


class AttachReferralResponse(BaseModel):
    tenant_id: str
    partner_code: str
    partner_name: str
    attribution_source: str


class ReferralStatusResponse(BaseModel):
    tenant_id: str
    has_referral: bool
    partner_code: str | None = None
    partner_name: str | None = None
    attribution_source: str | None = None


class PartnerLoginRequest(BaseModel):
    email: str = Field(min_length=5, max_length=255)
    password: str = Field(min_length=8, max_length=200)


class PartnerLoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    partner_id: int
    partner_code: str
    name: str


class PartnerSetCredentialsRequest(BaseModel):
    partner_code: str = Field(min_length=2, max_length=40)
    email: str = Field(min_length=5, max_length=255)
    password: str = Field(min_length=8, max_length=200)


class PartnerSetCredentialsResponse(BaseModel):
    partner_id: int
    partner_code: str
    contact_email: str


class PartnerMeResponse(BaseModel):
    id: int
    name: str
    partner_code: str
    contact_email: str | None
    status: str
    default_commission_rate: float


class PartnerReferralRow(BaseModel):
    tenant_id: str
    company_name: str
    license_plan: str
    subscription_status: str
    attributed_at_utc: str


class PartnerCommissionRow(BaseModel):
    id: int
    tenant_id: str
    invoice_id: int | None
    provider_invoice_id: str
    status: str
    currency: str
    base_amount: float
    commission_rate: float
    commission_amount: float
    created_at_utc: str
    approved_at_utc: str | None
    paid_at_utc: str | None


class PartnerResetConfirmRequest(BaseModel):
    token: str = Field(min_length=20, max_length=4000)
    new_password: str = Field(min_length=8, max_length=200)


class PartnerResetRequest(BaseModel):
    email: str = Field(min_length=5, max_length=255)


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


def _format_dt(value) -> str | None:
    if value is None:
        return None
    return value.isoformat()


def _create_partner_access_token(partner: Partner) -> str:
    return create_token(
        {
            "sub": f"partner:{partner.id}",
            "partner_id": partner.id,
            "partner_code": partner.partner_code,
            "scope": "partner_portal",
        }
    )


def _require_rate_limit(request: Request, action: str, max_attempts: int, window_seconds: int) -> None:
    client = request.client.host if request.client else "unknown"
    key = f"{action}:{client}"
    now = time.time()
    window_start = now - float(window_seconds)

    with _RATE_LIMIT_LOCK:
        bucket = _RATE_LIMIT_BUCKETS[key]
        while bucket and bucket[0] < window_start:
            bucket.popleft()
        if len(bucket) >= max_attempts:
            raise HTTPException(
                status_code=429,
                detail="Too many attempts. Please retry later.",
            )
        bucket.append(now)


def _build_partner_reset_url(request: Request, token: str) -> str:
    base = (settings.PARTNER_RESET_URL_BASE or "").strip().rstrip("/")
    if not base:
        base = str(request.base_url).rstrip("/")
    return f"{base}/partner-reset-password.html?token={token}"


def _send_partner_reset_email(target_email: str, reset_url: str) -> bool:
    host = (settings.SMTP_HOST or "").strip()
    from_email = (settings.SMTP_FROM_EMAIL or "").strip()
    if not host or not from_email:
        logger.warning("SMTP not configured. Partner reset email skipped for: %s", target_email)
        return False

    subject = "Reset your BCSentinel partner password"
    html_body = f"""
    <html>
      <body style="font-family: Arial, sans-serif; color: #1f2a44;">
        <p>Hello,</p>
        <p>we received a request to reset your BCSentinel partner password.</p>
        <p><a href="{reset_url}">Reset password</a></p>
        <p>If you did not request this, you can ignore this email.</p>
        <p>Link expires automatically.</p>
      </body>
    </html>
    """
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
        return True
    except Exception:
        logger.exception("Failed to send partner reset email to %s", target_email)
        return False


def _load_partner_from_bearer(
    credentials: HTTPAuthorizationCredentials = Depends(partner_bearer),
) -> Partner:
    if credentials is None:
        raise HTTPException(status_code=401, detail="Not authenticated.")

    payload = verify_token(credentials.credentials)
    if payload is None:
        raise HTTPException(status_code=401, detail="Invalid token.")

    partner_id_raw = payload.get("partner_id")
    try:
        partner_id = int(partner_id_raw)
    except (TypeError, ValueError):
        raise HTTPException(status_code=401, detail="Invalid token payload.") from None

    with SessionLocal() as db:
        partner = db.scalar(select(Partner).where(Partner.id == partner_id))
        if partner is None:
            raise HTTPException(status_code=401, detail="Partner not found.")
        if (partner.status or "").strip().lower() != "active":
            raise HTTPException(status_code=403, detail="Partner is not active.")
        return partner


@router.post("/partners", response_model=PartnerCreateResponse)
def create_partner(payload: PartnerCreateRequest, _: str = Depends(require_admin)) -> PartnerCreateResponse:
    normalized_code = normalize_partner_code(payload.partner_code)
    if not normalized_code:
        raise HTTPException(status_code=400, detail="partner_code is required.")

    with SessionLocal() as db:
        existing = get_partner_by_code(db, normalized_code)
        if existing is not None:
            raise HTTPException(status_code=409, detail="partner_code already exists.")

        partner = Partner(
            name=payload.name.strip(),
            partner_code=normalized_code,
            status="active",
            default_commission_rate=float(payload.default_commission_rate),
            created_at_utc=utc_now(),
            updated_at_utc=utc_now(),
        )
        db.add(partner)
        db.commit()
        db.refresh(partner)

        return PartnerCreateResponse(
            id=partner.id,
            name=partner.name,
            partner_code=partner.partner_code,
            status=partner.status,
            default_commission_rate=float(partner.default_commission_rate),
        )


@router.post("/api/partners/auth/login", response_model=PartnerLoginResponse)
def partner_login(payload: PartnerLoginRequest, request: Request) -> PartnerLoginResponse:
    _require_rate_limit(request, action="partner_login", max_attempts=8, window_seconds=60)
    normalized_email = (payload.email or "").strip().lower()
    if not normalized_email:
        raise HTTPException(status_code=400, detail="email is required.")

    with SessionLocal() as db:
        partner = db.scalar(select(Partner).where(Partner.contact_email == normalized_email))
        if partner is None:
            raise HTTPException(status_code=401, detail="Invalid credentials.")
        if (partner.status or "").strip().lower() != "active":
            raise HTTPException(status_code=403, detail="Partner is not active.")
        if not verify_api_token(payload.password, partner.password_hash):
            raise HTTPException(status_code=401, detail="Invalid credentials.")

        partner.last_login_at_utc = utc_now()
        db.commit()
        db.refresh(partner)

        token = _create_partner_access_token(partner)
        return PartnerLoginResponse(
            access_token=token,
            partner_id=partner.id,
            partner_code=partner.partner_code,
            name=partner.name,
        )


@router.post("/api/partners/auth/set-credentials", response_model=PartnerSetCredentialsResponse)
def partner_set_credentials(
    payload: PartnerSetCredentialsRequest,
    _: str = Depends(require_admin),
) -> PartnerSetCredentialsResponse:
    normalized_code = normalize_partner_code(payload.partner_code)
    normalized_email = (payload.email or "").strip().lower()
    if not normalized_code:
        raise HTTPException(status_code=400, detail="partner_code is required.")
    if not normalized_email:
        raise HTTPException(status_code=400, detail="email is required.")

    with SessionLocal() as db:
        partner = get_partner_by_code(db, normalized_code)
        if partner is None:
            raise HTTPException(status_code=404, detail="Partner not found.")

        existing_mail_owner = db.scalar(
            select(Partner).where(Partner.contact_email == normalized_email, Partner.id != partner.id)
        )
        if existing_mail_owner is not None:
            raise HTTPException(status_code=409, detail="email already used by another partner.")

        partner.contact_email = normalized_email
        partner.password_hash = hash_api_token(payload.password)
        partner.updated_at_utc = utc_now()
        db.commit()
        db.refresh(partner)

        return PartnerSetCredentialsResponse(
            partner_id=partner.id,
            partner_code=partner.partner_code,
            contact_email=partner.contact_email or "",
        )


@router.post("/api/partners/auth/reset/confirm")
def partner_reset_confirm(payload: PartnerResetConfirmRequest, request: Request) -> dict:
    _require_rate_limit(request, action="partner_reset_confirm", max_attempts=6, window_seconds=300)
    token_payload = verify_token(payload.token)
    if token_payload is None:
        raise HTTPException(status_code=400, detail="Invalid or expired reset token.")

    if token_payload.get("scope") != "partner_reset":
        raise HTTPException(status_code=400, detail="Invalid reset token scope.")

    partner_id_raw = token_payload.get("partner_id")
    try:
        partner_id = int(partner_id_raw)
    except (TypeError, ValueError):
        raise HTTPException(status_code=400, detail="Invalid reset token payload.") from None

    with SessionLocal() as db:
        partner = db.scalar(select(Partner).where(Partner.id == partner_id))
        if partner is None:
            raise HTTPException(status_code=404, detail="Partner not found.")

        partner.password_hash = hash_api_token(payload.new_password)
        partner.updated_at_utc = utc_now()
        db.commit()

    return {"status": "ok"}


@router.post("/api/partners/auth/reset/request")
def partner_reset_request(payload: PartnerResetRequest, request: Request) -> dict:
    _require_rate_limit(request, action="partner_reset_request", max_attempts=4, window_seconds=300)
    normalized_email = (payload.email or "").strip().lower()
    if not normalized_email:
        return {"status": "ok"}

    with SessionLocal() as db:
        partner = db.scalar(select(Partner).where(Partner.contact_email == normalized_email))
        if partner is None:
            return {"status": "ok"}
        if (partner.status or "").strip().lower() != "active":
            return {"status": "ok"}

        token = create_token(
            {
                "sub": f"partner_reset:{partner.id}",
                "scope": "partner_reset",
                "partner_id": partner.id,
                "partner_code": partner.partner_code,
            }
        )
        reset_url = _build_partner_reset_url(request, token)
        _send_partner_reset_email(target_email=normalized_email, reset_url=reset_url)
        return {"status": "ok"}


@router.get("/api/partners/me", response_model=PartnerMeResponse)
def partner_me(partner: Partner = Depends(_load_partner_from_bearer)) -> PartnerMeResponse:
    return PartnerMeResponse(
        id=partner.id,
        name=partner.name,
        partner_code=partner.partner_code,
        contact_email=partner.contact_email,
        status=partner.status,
        default_commission_rate=float(partner.default_commission_rate or 0.0),
    )


@router.get("/api/partners/me/referrals", response_model=list[PartnerReferralRow])
def partner_my_referrals(partner: Partner = Depends(_load_partner_from_bearer)) -> list[PartnerReferralRow]:
    with SessionLocal() as db:
        referrals = db.scalars(
            select(PartnerReferral)
            .where(PartnerReferral.partner_id == partner.id)
            .order_by(PartnerReferral.attributed_at_utc.desc(), PartnerReferral.id.desc())
        ).all()
        if not referrals:
            return []

        tenant_ids = [row.tenant_id for row in referrals]
        tenants = db.scalars(select(Tenant).where(Tenant.tenant_id.in_(tenant_ids))).all()
        tenant_map = {tenant.tenant_id: tenant for tenant in tenants}

        subs = db.scalars(
            select(Subscription)
            .where(Subscription.tenant_id.in_(tenant_ids))
            .order_by(Subscription.tenant_id.asc(), Subscription.updated_at_utc.desc(), Subscription.id.desc())
        ).all()
        latest_sub_map: dict[str, Subscription] = {}
        for sub in subs:
            if sub.tenant_id not in latest_sub_map:
                latest_sub_map[sub.tenant_id] = sub

        rows: list[PartnerReferralRow] = []
        for row in referrals:
            tenant = tenant_map.get(row.tenant_id)
            latest_sub = latest_sub_map.get(row.tenant_id)
            rows.append(
                PartnerReferralRow(
                    tenant_id=row.tenant_id,
                    company_name=(tenant.environment_name if tenant else "Unknown"),
                    license_plan=(tenant.current_plan if tenant else "free"),
                    subscription_status=(latest_sub.status if latest_sub else "none"),
                    attributed_at_utc=_format_dt(row.attributed_at_utc) or "",
                )
            )
        return rows


@router.get("/api/partners/me/commissions", response_model=list[PartnerCommissionRow])
def partner_my_commissions(partner: Partner = Depends(_load_partner_from_bearer)) -> list[PartnerCommissionRow]:
    with SessionLocal() as db:
        commissions = db.scalars(
            select(PartnerCommission)
            .where(PartnerCommission.partner_id == partner.id)
            .order_by(PartnerCommission.created_at_utc.desc(), PartnerCommission.id.desc())
        ).all()
        return [
            PartnerCommissionRow(
                id=row.id,
                tenant_id=row.tenant_id,
                invoice_id=row.invoice_id,
                provider_invoice_id=row.provider_invoice_id,
                status=row.status,
                currency=row.currency,
                base_amount=float(row.base_amount or 0.0),
                commission_rate=float(row.commission_rate or 0.0),
                commission_amount=float(row.commission_amount or 0.0),
                created_at_utc=_format_dt(row.created_at_utc) or "",
                approved_at_utc=_format_dt(row.approved_at_utc),
                paid_at_utc=_format_dt(row.paid_at_utc),
            )
            for row in commissions
        ]


@router.post("/partners/referral/attach", response_model=AttachReferralResponse)
def attach_referral(
    payload: AttachReferralRequest,
    tenant_auth: tuple[str, str] = Depends(require_tenant_headers),
) -> AttachReferralResponse:
    header_tenant_id, header_api_token = tenant_auth
    enforce_tenant_match(payload.tenant_id, header_tenant_id, "Payload tenant_id")

    with SessionLocal() as db:
        load_authenticated_tenant(db, header_tenant_id, header_api_token)
        try:
            referral = attach_partner_referral_to_tenant(
                db,
                tenant_id=payload.tenant_id,
                partner_code=payload.partner_code,
                attribution_source=payload.attribution_source,
            )
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc

        partner = db.scalar(select(Partner).where(Partner.id == referral.partner_id))
        if partner is None:
            raise HTTPException(status_code=404, detail="Partner not found.")

        db.commit()

        return AttachReferralResponse(
            tenant_id=payload.tenant_id,
            partner_code=partner.partner_code,
            partner_name=partner.name,
            attribution_source=referral.attribution_source,
        )


@router.get("/partners/referral/status", response_model=ReferralStatusResponse)
def get_referral_status(
    tenant_auth: tuple[str, str] = Depends(require_tenant_headers),
) -> ReferralStatusResponse:
    header_tenant_id, header_api_token = tenant_auth

    with SessionLocal() as db:
        tenant = load_authenticated_tenant(db, header_tenant_id, header_api_token)
        referral = db.scalar(
            select(PartnerReferral).where(PartnerReferral.tenant_id == tenant.tenant_id)
        )
        if referral is None:
            return ReferralStatusResponse(
                tenant_id=tenant.tenant_id,
                has_referral=False,
            )

        partner = db.scalar(select(Partner).where(Partner.id == referral.partner_id))
        return ReferralStatusResponse(
            tenant_id=tenant.tenant_id,
            has_referral=True,
            partner_code=partner.partner_code if partner else None,
            partner_name=partner.name if partner else None,
            attribution_source=referral.attribution_source,
        )
