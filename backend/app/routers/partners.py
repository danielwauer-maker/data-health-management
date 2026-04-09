from __future__ import annotations

import secrets

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from pydantic import BaseModel, Field
from sqlalchemy import select

from app.core.settings import settings
from app.db import SessionLocal
from app.models import Partner, PartnerReferral
from app.security.tenant import enforce_tenant_match, load_authenticated_tenant, require_tenant_headers
from app.services.billing_service import utc_now
from app.services.partner_service import (
    attach_partner_referral_to_tenant,
    get_partner_by_code,
    normalize_partner_code,
)

router = APIRouter(tags=["partners"])
security = HTTPBasic()


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
