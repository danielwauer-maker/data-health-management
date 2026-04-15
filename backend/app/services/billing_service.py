from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import desc, select
from sqlalchemy.exc import IntegrityError

from app.models import BillingWebhookEvent, Invoice, Subscription, Tenant

ACTIVE_SUBSCRIPTION_STATUSES = {"trialing", "active"}


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def get_latest_subscription_for_tenant(db, tenant_id: str) -> Subscription | None:
    return db.scalar(
        select(Subscription)
        .where(Subscription.tenant_id == tenant_id)
        .order_by(desc(Subscription.updated_at_utc), desc(Subscription.id))
        .limit(1)
    )


def sync_tenant_license_from_subscription(tenant: Tenant, subscription: Subscription | None) -> None:
    if subscription is None:
        return

    status = (subscription.status or "").strip().lower()
    if status in ACTIVE_SUBSCRIPTION_STATUSES:
        tenant.current_plan = "premium"
        tenant.license_status = "active"
        return

    if status in {"canceled", "cancelled", "incomplete_expired", "expired"}:
        tenant.current_plan = "free"
        tenant.license_status = "expired"
        return

    if status in {"past_due", "unpaid"}:
        tenant.current_plan = "premium"
        tenant.license_status = "blocked"
        return


def resolve_effective_license(db, tenant: Tenant) -> tuple[str, str]:
    plan = (tenant.current_plan or "free").strip().lower()
    status = (tenant.license_status or "trial").strip().lower()

    if plan not in {"free", "premium"}:
        plan = "free"
    if status not in {"trial", "active", "expired", "blocked"}:
        status = "trial"
    return plan, status


def ensure_webhook_event_once(db, *, provider: str, event_id: str, event_type: str, payload_json: str) -> tuple[BillingWebhookEvent, bool]:
    existing = db.scalar(
        select(BillingWebhookEvent).where(
            BillingWebhookEvent.provider == provider,
            BillingWebhookEvent.event_id == event_id,
        )
    )
    if existing is not None:
        return existing, False

    created = BillingWebhookEvent(
        provider=provider,
        event_id=event_id,
        event_type=event_type,
        payload_json=payload_json,
        received_at_utc=utc_now(),
        processed_at_utc=None,
    )
    db.add(created)
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        existing_after_race = db.scalar(
            select(BillingWebhookEvent).where(
                BillingWebhookEvent.provider == provider,
                BillingWebhookEvent.event_id == event_id,
            )
        )
        if existing_after_race is not None:
            return existing_after_race, False
        raise
    return created, True


def upsert_subscription_from_payload(
    db,
    *,
    tenant_id: str,
    provider: str,
    provider_subscription_id: str,
    status: str,
    plan_code: str = "premium",
    currency: str = "EUR",
    amount_monthly: float = 0.0,
    current_period_start_utc: datetime | None = None,
    current_period_end_utc: datetime | None = None,
    cancel_at_period_end: bool = False,
    canceled_at_utc: datetime | None = None,
) -> Subscription:
    subscription = db.scalar(
        select(Subscription).where(Subscription.provider_subscription_id == provider_subscription_id)
    )
    now = utc_now()
    if subscription is None:
        subscription = Subscription(
            tenant_id=tenant_id,
            provider=provider,
            provider_subscription_id=provider_subscription_id,
            status=status,
            plan_code=plan_code,
            currency=currency,
            amount_monthly=float(amount_monthly or 0.0),
            current_period_start_utc=current_period_start_utc,
            current_period_end_utc=current_period_end_utc,
            cancel_at_period_end=bool(cancel_at_period_end),
            canceled_at_utc=canceled_at_utc,
            created_at_utc=now,
            updated_at_utc=now,
        )
        db.add(subscription)
        db.flush()
        return subscription

    subscription.tenant_id = tenant_id
    subscription.provider = provider
    subscription.status = status
    subscription.plan_code = plan_code
    subscription.currency = currency
    subscription.amount_monthly = float(amount_monthly or 0.0)
    subscription.current_period_start_utc = current_period_start_utc
    subscription.current_period_end_utc = current_period_end_utc
    subscription.cancel_at_period_end = bool(cancel_at_period_end)
    subscription.canceled_at_utc = canceled_at_utc
    subscription.updated_at_utc = now
    return subscription


def upsert_invoice_from_payload(
    db,
    *,
    tenant_id: str,
    provider: str,
    provider_invoice_id: str,
    provider_subscription_id: str | None,
    status: str,
    currency: str = "EUR",
    amount_total: float = 0.0,
    amount_paid: float = 0.0,
    hosted_invoice_url: str | None = None,
    paid_at_utc: datetime | None = None,
) -> Invoice:
    invoice = db.scalar(select(Invoice).where(Invoice.provider_invoice_id == provider_invoice_id))
    now = utc_now()
    if invoice is None:
        invoice = Invoice(
            tenant_id=tenant_id,
            provider=provider,
            provider_invoice_id=provider_invoice_id,
            provider_subscription_id=provider_subscription_id,
            status=status,
            currency=currency,
            amount_total=float(amount_total or 0.0),
            amount_paid=float(amount_paid or 0.0),
            hosted_invoice_url=hosted_invoice_url,
            paid_at_utc=paid_at_utc,
            created_at_utc=now,
        )
        db.add(invoice)
        db.flush()
        return invoice

    invoice.tenant_id = tenant_id
    invoice.provider = provider
    invoice.provider_subscription_id = provider_subscription_id
    invoice.status = status
    invoice.currency = currency
    invoice.amount_total = float(amount_total or 0.0)
    invoice.amount_paid = float(amount_paid or 0.0)
    invoice.hosted_invoice_url = hosted_invoice_url
    invoice.paid_at_utc = paid_at_utc
    return invoice
