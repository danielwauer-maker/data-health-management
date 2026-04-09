from __future__ import annotations

from sqlalchemy import select

from app.models import Invoice, Partner, PartnerCommission, PartnerReferral
from app.services.billing_service import utc_now


def normalize_partner_code(value: str) -> str:
    return (value or "").strip().lower()


def get_partner_by_code(db, partner_code: str) -> Partner | None:
    normalized = normalize_partner_code(partner_code)
    if not normalized:
        return None
    return db.scalar(select(Partner).where(Partner.partner_code == normalized))


def attach_partner_referral_to_tenant(
    db,
    *,
    tenant_id: str,
    partner_code: str,
    attribution_source: str = "manual",
) -> PartnerReferral:
    partner = get_partner_by_code(db, partner_code)
    if partner is None:
        raise ValueError("Partner code is invalid.")
    if (partner.status or "").lower() != "active":
        raise ValueError("Partner is not active.")

    existing = db.scalar(select(PartnerReferral).where(PartnerReferral.tenant_id == tenant_id))
    if existing is not None:
        existing.partner_id = partner.id
        existing.referral_code = normalize_partner_code(partner_code)
        existing.attribution_source = (attribution_source or "manual").strip().lower()
        existing.attributed_at_utc = utc_now()
        return existing

    referral = PartnerReferral(
        partner_id=partner.id,
        tenant_id=tenant_id,
        referral_code=normalize_partner_code(partner_code),
        attribution_source=(attribution_source or "manual").strip().lower(),
        attributed_at_utc=utc_now(),
    )
    db.add(referral)
    return referral


def ensure_partner_commission_for_invoice(db, *, invoice: Invoice) -> PartnerCommission | None:
    if invoice is None:
        return None
    if (invoice.status or "").lower() != "paid":
        return None

    existing_commission = db.scalar(
        select(PartnerCommission).where(PartnerCommission.provider_invoice_id == invoice.provider_invoice_id)
    )
    if existing_commission is not None:
        return existing_commission

    referral = db.scalar(select(PartnerReferral).where(PartnerReferral.tenant_id == invoice.tenant_id))
    if referral is None:
        return None

    partner = db.scalar(select(Partner).where(Partner.id == referral.partner_id))
    if partner is None:
        return None
    if (partner.status or "").lower() != "active":
        return None

    base_amount = float(invoice.amount_paid or invoice.amount_total or 0.0)
    rate = float(partner.default_commission_rate or 0.0)
    commission_amount = round(base_amount * rate, 2)

    commission = PartnerCommission(
        partner_id=partner.id,
        tenant_id=invoice.tenant_id,
        invoice_id=invoice.id,
        provider_invoice_id=invoice.provider_invoice_id,
        status="pending",
        currency=(invoice.currency or "EUR").upper(),
        base_amount=base_amount,
        commission_rate=rate,
        commission_amount=commission_amount,
        created_at_utc=utc_now(),
    )
    db.add(commission)
    return commission
