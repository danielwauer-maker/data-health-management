from __future__ import annotations

from sqlalchemy import func, select

from app.models import Invoice, Partner, PartnerCommission, PartnerReferral
from app.services.billing_service import utc_now

STANDARD_COMMISSION_RATE = 0.30
RENEWAL_COMMISSION_RATE = 0.15
PAID_INVOICE_STATUSES = {"paid"}
REVERSAL_INVOICE_STATUSES = {"void", "voided", "uncollectible", "marked_uncollectible", "refunded"}


class ReferralAttributionConflictError(ValueError):
    pass


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
    force: bool = False,
) -> PartnerReferral:
    partner = get_partner_by_code(db, partner_code)
    if partner is None:
        raise ValueError("Partner code is invalid.")
    if (partner.status or "").lower() != "active":
        raise ValueError("Partner is not active.")

    existing = db.scalar(select(PartnerReferral).where(PartnerReferral.tenant_id == tenant_id))
    if existing is not None:
        if existing.partner_id == partner.id:
            return existing
        if not force:
            raise ReferralAttributionConflictError(
                "Tenant already has a referral attribution. Changes require explicit admin override."
            )
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


def resolve_partner_commission_rate(db, partner: Partner, invoice: Invoice) -> float:
    prior_commissions_count = int(
        db.scalar(
            select(func.count(PartnerCommission.id)).where(
                PartnerCommission.partner_id == partner.id,
                PartnerCommission.tenant_id == invoice.tenant_id,
            )
        )
        or 0
    )
    if prior_commissions_count > 0:
        return RENEWAL_COMMISSION_RATE
    return float(partner.default_commission_rate or STANDARD_COMMISSION_RATE)


def reconcile_partner_commission_for_invoice(db, *, invoice: Invoice) -> PartnerCommission | None:
    if invoice is None:
        return None

    existing_commission = db.scalar(
        select(PartnerCommission).where(PartnerCommission.provider_invoice_id == invoice.provider_invoice_id)
    )
    if existing_commission is None:
        return None

    invoice_status = (invoice.status or "").lower()
    if invoice_status in PAID_INVOICE_STATUSES:
        return existing_commission

    if invoice_status in REVERSAL_INVOICE_STATUSES:
        if existing_commission.status != "paid":
            existing_commission.status = "rejected"
            existing_commission.note = f"Auto-reversed because invoice status is '{invoice_status}'."
        else:
            existing_commission.note = (
                f"Invoice status is '{invoice_status}'. Manual clawback required for already paid commission."
            )
    return existing_commission


def ensure_partner_commission_for_invoice(
    db,
    *,
    invoice: Invoice,
    referral_code: str | None = None,
) -> PartnerCommission | None:
    if invoice is None:
        return None
    invoice_status = (invoice.status or "").lower()
    if invoice_status != "paid":
        return reconcile_partner_commission_for_invoice(db, invoice=invoice)

    existing_commission = db.scalar(
        select(PartnerCommission).where(PartnerCommission.provider_invoice_id == invoice.provider_invoice_id)
    )
    if existing_commission is not None:
        return existing_commission

    partner: Partner | None = None
    normalized_referral_code = normalize_partner_code(referral_code or "")
    if normalized_referral_code:
        partner = get_partner_by_code(db, normalized_referral_code)

    if partner is None:
        referral = db.scalar(select(PartnerReferral).where(PartnerReferral.tenant_id == invoice.tenant_id))
        if referral is None:
            return None
        partner = db.scalar(select(Partner).where(Partner.id == referral.partner_id))

    if partner is None or (partner.status or "").lower() != "active":
        return None

    base_amount = float(invoice.amount_paid or invoice.amount_total or 0.0)
    rate = resolve_partner_commission_rate(db, partner, invoice)
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
