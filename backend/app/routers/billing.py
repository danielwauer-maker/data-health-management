from __future__ import annotations

from datetime import datetime
from uuid import uuid4

import stripe
from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy import select

from app.core.settings import settings
from app.db import SessionLocal
from app.models import Subscription, Tenant
from app.security.tenant import (
    enforce_tenant_match,
    load_authenticated_tenant,
    require_tenant_headers,
)
from app.services.billing_service import (
    ensure_webhook_event_once,
    get_latest_subscription_for_tenant,
    resolve_effective_license,
    sync_tenant_license_from_subscription,
    upsert_invoice_from_payload,
    upsert_subscription_from_payload,
    utc_now,
)
from app.services.partner_service import ensure_partner_commission_for_invoice

router = APIRouter(tags=["billing"])

# Stripe event matrix (v1):
# - checkout.session.completed      -> ignored (metadata source only, no state write)
# - customer.subscription.created   -> subscription.created
# - customer.subscription.updated   -> subscription.updated
# - customer.subscription.deleted   -> subscription.deleted
# - invoice.paid                    -> invoice.paid
# - invoice.payment_failed          -> invoice.payment_failed
# - invoice.voided                  -> invoice.voided
SUPPORTED_STRIPE_EVENTS = {
    "checkout.session.completed",
    "customer.subscription.created",
    "customer.subscription.updated",
    "customer.subscription.deleted",
    "invoice.paid",
    "invoice.payment_failed",
    "invoice.voided",
}


class CheckoutSessionRequest(BaseModel):
    tenant_id: str
    plan_code: str = "premium"
    success_url: str | None = None
    cancel_url: str | None = None


class CheckoutSessionResponse(BaseModel):
    checkout_session_id: str
    checkout_url: str
    provider: str
    tenant_id: str
    plan_code: str


class BillingSubscriptionStatusResponse(BaseModel):
    tenant_id: str
    current_plan: str
    license_status: str
    subscription_status: str | None = None
    provider: str | None = None
    provider_subscription_id: str | None = None
    current_period_end_utc: datetime | None = None
    cancel_at_period_end: bool = False
    amount_monthly: float = 0.0
    currency: str = "EUR"


class BillingWebhookPayload(BaseModel):
    provider: str = "manual"
    event_id: str
    event_type: str
    tenant_id: str
    occurred_at_utc: datetime | None = None
    subscription: dict | None = None
    invoice: dict | None = None
    data: dict = Field(default_factory=dict)


class BillingWebhookResponse(BaseModel):
    status: str
    event_id: str
    processed: bool


def _parse_dt(value) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value
    if isinstance(value, str):
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return None
    return None


def _dt_from_unix(value) -> datetime | None:
    try:
        if value is None:
            return None
        return datetime.fromtimestamp(int(value), tz=utc_now().tzinfo)
    except (TypeError, ValueError, OSError):
        return None


def _is_stripe_configured() -> bool:
    return bool(
        (settings.STRIPE_SECRET_KEY or "").strip()
        and (settings.STRIPE_PRICE_ID_PREMIUM or "").strip()
    )


def _stripe_default_success_url() -> str:
    configured = (settings.BILLING_SUCCESS_URL or "").strip()
    if configured:
        return configured
    return "https://app.bcsentinel.com/billing/success?session_id={CHECKOUT_SESSION_ID}"


def _stripe_default_cancel_url() -> str:
    configured = (settings.BILLING_CANCEL_URL or "").strip()
    if configured:
        return configured
    return "https://app.bcsentinel.com/billing/cancel"


def _find_tenant_for_invoice(db, explicit_tenant_id: str | None, provider_subscription_id: str | None) -> Tenant | None:
    if explicit_tenant_id:
        return db.scalar(select(Tenant).where(Tenant.tenant_id == explicit_tenant_id))
    if not provider_subscription_id:
        return None
    subscription = db.scalar(
        select(Subscription).where(Subscription.provider_subscription_id == provider_subscription_id)
    )
    if subscription is None:
        return None
    return db.scalar(select(Tenant).where(Tenant.tenant_id == subscription.tenant_id))


def _normalize_stripe_event_type(event_type: str) -> str:
    if event_type == "customer.subscription.created":
        return "subscription.created"
    if event_type == "customer.subscription.updated":
        return "subscription.updated"
    if event_type == "customer.subscription.deleted":
        return "subscription.deleted"
    return event_type


def _process_normalized_webhook(
    db,
    *,
    provider: str,
    event_id: str,
    event_type: str,
    tenant_id: str,
    occurred_at_utc: datetime | None,
    subscription_data: dict | None,
    invoice_data: dict | None,
    raw_payload_json: str,
) -> BillingWebhookResponse:
    webhook_event, created = ensure_webhook_event_once(
        db,
        provider=provider,
        event_id=event_id,
        event_type=event_type,
        payload_json=raw_payload_json,
    )
    if not created:
        return BillingWebhookResponse(status="duplicate", event_id=event_id, processed=False)

    tenant = db.scalar(select(Tenant).where(Tenant.tenant_id == tenant_id))
    if tenant is None:
        raise HTTPException(status_code=404, detail="Tenant not found.")

    subscription_data = subscription_data or {}
    invoice_data = invoice_data or {}

    if event_type.startswith("subscription."):
        provider_subscription_id = str(
            subscription_data.get("provider_subscription_id")
            or subscription_data.get("id")
            or f"sub_{uuid4().hex}"
        )
        subscription = upsert_subscription_from_payload(
            db,
            tenant_id=tenant.tenant_id,
            provider=provider,
            provider_subscription_id=provider_subscription_id,
            status=str(subscription_data.get("status") or "active").lower(),
            plan_code=str(subscription_data.get("plan_code") or "premium").lower(),
            currency=str(subscription_data.get("currency") or "EUR"),
            amount_monthly=float(subscription_data.get("amount_monthly") or 0.0),
            current_period_start_utc=occurred_at_utc,
            current_period_end_utc=_parse_dt(subscription_data.get("current_period_end_utc")),
            cancel_at_period_end=bool(subscription_data.get("cancel_at_period_end") or False),
            canceled_at_utc=_parse_dt(subscription_data.get("canceled_at_utc")),
        )
        sync_tenant_license_from_subscription(tenant, subscription)

    if event_type.startswith("invoice."):
        provider_invoice_id = str(
            invoice_data.get("provider_invoice_id")
            or invoice_data.get("id")
            or f"inv_{uuid4().hex}"
        )
        invoice = upsert_invoice_from_payload(
            db,
            tenant_id=tenant.tenant_id,
            provider=provider,
            provider_invoice_id=provider_invoice_id,
            provider_subscription_id=invoice_data.get("provider_subscription_id"),
            status=str(invoice_data.get("status") or "paid").lower(),
            currency=str(invoice_data.get("currency") or "EUR"),
            amount_total=float(invoice_data.get("amount_total") or 0.0),
            amount_paid=float(invoice_data.get("amount_paid") or 0.0),
            hosted_invoice_url=invoice_data.get("hosted_invoice_url"),
            paid_at_utc=_parse_dt(invoice_data.get("paid_at_utc")),
        )
        ensure_partner_commission_for_invoice(db, invoice=invoice)

    webhook_event.processed_at_utc = utc_now()
    tenant.last_seen_at_utc = utc_now()
    db.commit()

    return BillingWebhookResponse(status="ok", event_id=event_id, processed=True)


@router.post("/billing/checkout/session", response_model=CheckoutSessionResponse)
def create_checkout_session(
    payload: CheckoutSessionRequest,
    tenant_auth: tuple[str, str] = Depends(require_tenant_headers),
) -> CheckoutSessionResponse:
    header_tenant_id, header_api_token = tenant_auth
    enforce_tenant_match(payload.tenant_id, header_tenant_id, "Payload tenant_id")

    with SessionLocal() as db:
        load_authenticated_tenant(db, header_tenant_id, header_api_token)

    if _is_stripe_configured():
        stripe.api_key = settings.STRIPE_SECRET_KEY
        success_url = (payload.success_url or "").strip() or _stripe_default_success_url()
        cancel_url = (payload.cancel_url or "").strip() or _stripe_default_cancel_url()
        session = stripe.checkout.Session.create(
            mode="subscription",
            line_items=[{"price": settings.STRIPE_PRICE_ID_PREMIUM, "quantity": 1}],
            success_url=success_url,
            cancel_url=cancel_url,
            metadata={
                "tenant_id": payload.tenant_id,
                "plan_code": (payload.plan_code or "premium").lower(),
            },
            subscription_data={
                "metadata": {
                    "tenant_id": payload.tenant_id,
                    "plan_code": (payload.plan_code or "premium").lower(),
                }
            },
        )
        return CheckoutSessionResponse(
            checkout_session_id=session.id,
            checkout_url=session.url,
            provider="stripe",
            tenant_id=payload.tenant_id,
            plan_code=(payload.plan_code or "premium").lower(),
        )

    session_id = f"chk_{uuid4().hex}"
    checkout_url = (
        payload.success_url
        or f"https://billing.bcsentinel.com/checkout/{session_id}?tenant_id={payload.tenant_id}&plan={payload.plan_code}"
    )
    return CheckoutSessionResponse(
        checkout_session_id=session_id,
        checkout_url=checkout_url,
        provider="pending_integration",
        tenant_id=payload.tenant_id,
        plan_code=(payload.plan_code or "premium").lower(),
    )


@router.get("/billing/subscription/status", response_model=BillingSubscriptionStatusResponse)
def get_billing_subscription_status(
    tenant_auth: tuple[str, str] = Depends(require_tenant_headers),
) -> BillingSubscriptionStatusResponse:
    header_tenant_id, header_api_token = tenant_auth

    with SessionLocal() as db:
        tenant = load_authenticated_tenant(db, header_tenant_id, header_api_token)
        plan, license_status = resolve_effective_license(db, tenant)
        subscription = get_latest_subscription_for_tenant(db, tenant.tenant_id)

        if subscription is None:
            return BillingSubscriptionStatusResponse(
                tenant_id=tenant.tenant_id,
                current_plan=plan,
                license_status=license_status,
            )

        return BillingSubscriptionStatusResponse(
            tenant_id=tenant.tenant_id,
            current_plan=plan,
            license_status=license_status,
            subscription_status=subscription.status,
            provider=subscription.provider,
            provider_subscription_id=subscription.provider_subscription_id,
            current_period_end_utc=subscription.current_period_end_utc,
            cancel_at_period_end=bool(subscription.cancel_at_period_end),
            amount_monthly=float(subscription.amount_monthly or 0.0),
            currency=subscription.currency or "EUR",
        )


@router.post("/billing/webhook", response_model=BillingWebhookResponse)
async def process_billing_webhook(
    request: Request,
    stripe_signature: str | None = Header(default=None, alias="Stripe-Signature"),
) -> BillingWebhookResponse:
    body_bytes = await request.body()
    body_text = body_bytes.decode("utf-8", errors="replace")

    if stripe_signature:
        webhook_secret = (settings.STRIPE_WEBHOOK_SECRET or "").strip()
        if not webhook_secret:
            raise HTTPException(status_code=500, detail="Stripe webhook secret is not configured.")
        stripe.api_key = settings.STRIPE_SECRET_KEY
        try:
            event = stripe.Webhook.construct_event(body_bytes, stripe_signature, webhook_secret)
        except Exception as exc:
            raise HTTPException(status_code=400, detail=f"Invalid Stripe webhook signature: {exc}") from exc

        event_type = str(event.get("type") or "").strip().lower()
        event_id = str(event.get("id") or "").strip() or f"evt_{uuid4().hex}"
        data_object = event.get("data", {}).get("object", {}) or {}
        occurred_at_utc = _dt_from_unix(event.get("created"))

        if event_type not in SUPPORTED_STRIPE_EVENTS:
            # Acknowledge unsupported events so Stripe stops retrying.
            return BillingWebhookResponse(status="ignored", event_id=event_id, processed=False)

        subscription_data: dict | None = None
        invoice_data: dict | None = None
        tenant_id = ""

        if event_type == "checkout.session.completed":
            tenant_id = str((data_object.get("metadata", {}) or {}).get("tenant_id") or "").strip()
            if not tenant_id:
                return BillingWebhookResponse(status="ignored", event_id=event_id, processed=False)
            with SessionLocal() as db:
                return _process_normalized_webhook(
                    db,
                    provider="stripe",
                    event_id=event_id,
                    event_type=event_type,
                    tenant_id=tenant_id,
                    occurred_at_utc=occurred_at_utc,
                    subscription_data=None,
                    invoice_data=None,
                    raw_payload_json=body_text,
                )

        if event_type.startswith("customer.subscription."):
            subscription_data = {
                "id": data_object.get("id"),
                "status": data_object.get("status"),
                "plan_code": (data_object.get("metadata", {}) or {}).get("plan_code", "premium"),
                "currency": (data_object.get("currency") or "EUR").upper(),
                "amount_monthly": float(
                    ((data_object.get("items", {}) or {}).get("data", [{}])[0].get("price", {}) or {}).get(
                        "unit_amount", 0
                    )
                    or 0
                )
                / 100.0,
                "current_period_end_utc": _dt_from_unix(data_object.get("current_period_end")),
                "cancel_at_period_end": bool(data_object.get("cancel_at_period_end")),
                "canceled_at_utc": _dt_from_unix(data_object.get("canceled_at")),
            }
            tenant_id = str((data_object.get("metadata", {}) or {}).get("tenant_id") or "").strip()

        if event_type.startswith("invoice."):
            provider_subscription_id = str(data_object.get("subscription") or "").strip() or None
            invoice_data = {
                "id": data_object.get("id"),
                "provider_subscription_id": provider_subscription_id,
                "status": data_object.get("status"),
                "currency": (data_object.get("currency") or "EUR").upper(),
                "amount_total": float(data_object.get("amount_due") or 0) / 100.0,
                "amount_paid": float(data_object.get("amount_paid") or 0) / 100.0,
                "hosted_invoice_url": data_object.get("hosted_invoice_url"),
                "paid_at_utc": _dt_from_unix(((data_object.get("status_transitions") or {}).get("paid_at"))),
            }
            tenant_id = str(
                ((data_object.get("subscription_details") or {}).get("metadata") or {}).get("tenant_id")
                or ""
            ).strip()
            if not tenant_id:
                with SessionLocal() as db:
                    tenant = _find_tenant_for_invoice(db, None, provider_subscription_id)
                    if tenant is not None:
                        tenant_id = tenant.tenant_id

        if not tenant_id:
            # acknowledge irrelevant Stripe events without failing delivery retries
            return BillingWebhookResponse(status="ignored", event_id=event_id, processed=False)

        with SessionLocal() as db:
            return _process_normalized_webhook(
                db,
                provider="stripe",
                event_id=event_id,
                event_type=_normalize_stripe_event_type(event_type),
                tenant_id=tenant_id,
                occurred_at_utc=occurred_at_utc,
                subscription_data=subscription_data,
                invoice_data=invoice_data,
                raw_payload_json=body_text,
            )

    try:
        payload = BillingWebhookPayload.model_validate_json(body_text)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Invalid webhook payload: {exc}") from exc

    provider = (payload.provider or "manual").strip().lower()
    event_type = (payload.event_type or "").strip().lower()
    if not payload.event_id.strip():
        raise HTTPException(status_code=400, detail="event_id is required.")
    if not payload.tenant_id.strip():
        raise HTTPException(status_code=400, detail="tenant_id is required.")

    with SessionLocal() as db:
        return _process_normalized_webhook(
            db,
            provider=provider,
            event_id=payload.event_id.strip(),
            event_type=event_type,
            tenant_id=payload.tenant_id.strip(),
            occurred_at_utc=payload.occurred_at_utc,
            subscription_data=payload.subscription,
            invoice_data=payload.invoice,
            raw_payload_json=payload.model_dump_json(),
        )
