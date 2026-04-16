from __future__ import annotations

import math
import logging
from datetime import datetime
from uuid import uuid4

import stripe
from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy import select

from app.core.observability import log_event
from app.core.settings import resolve_billing_url, settings
from app.db import SessionLocal
from app.models import PartnerReferral, Scan, Subscription, Tenant
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
from app.services.entitlement_guard_service import require_tenant_feature
from app.services.partner_service import ensure_partner_commission_for_invoice

router = APIRouter(tags=["billing"])
logger = logging.getLogger(__name__)

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
    "checkout.session.expired",
    "customer.subscription.created",
    "customer.subscription.updated",
    "customer.subscription.deleted",
    "invoice.paid",
    "invoice.payment_failed",
    "invoice.voided",
    "invoice.finalized",
    "invoice.updated",
    "invoice.marked_uncollectible",
}


class CheckoutSessionRequest(BaseModel):
    tenant_id: str
    plan_code: str = "premium"
    billing_interval: str = "monthly"


class CheckoutSessionResponse(BaseModel):
    checkout_session_id: str
    checkout_url: str
    provider: str
    tenant_id: str
    plan_code: str
    billing_interval: str = "monthly"


class BillingPortalRequest(BaseModel):
    tenant_id: str


class BillingPortalResponse(BaseModel):
    provider: str
    tenant_id: str
    portal_url: str


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


class CheckoutSessionSyncResponse(BaseModel):
    status: str
    checkout_session_id: str
    subscription_status: BillingSubscriptionStatusResponse


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


def _stripe_to_plain_data(value):
    if value is None:
        return None

    if isinstance(value, dict):
        return {k: _stripe_to_plain_data(v) for k, v in value.items()}

    if isinstance(value, list):
        return [_stripe_to_plain_data(v) for v in value]

    if hasattr(value, "to_dict_recursive"):
        try:
            return _stripe_to_plain_data(value.to_dict_recursive())
        except Exception:
            pass

    if hasattr(value, "to_dict"):
        try:
            return _stripe_to_plain_data(value.to_dict())
        except Exception:
            pass

    raw_data = getattr(value, "_data", None)
    if isinstance(raw_data, dict):
        return {k: _stripe_to_plain_data(v) for k, v in raw_data.items()}

    return value


def _load_latest_deep_scan(db, tenant_id: str) -> Scan | None:
    return db.scalar(
        select(Scan)
        .where(
            Scan.tenant_id == tenant_id,
            Scan.scan_type == "deep",
        )
        .order_by(Scan.generated_at_utc.desc(), Scan.id.desc())
        .limit(1)
    )


def _deep_scan_record_count(scan: Scan | None) -> int:
    if scan is None:
        return 0
    try:
        return max(int(scan.total_records or 0), 0)
    except (TypeError, ValueError):
        return 0


def _additional_record_package_count(record_count: int) -> int:
    normalized = max(int(record_count or 0), 0)
    if normalized <= 2000:
        return 0
    return int(math.ceil((normalized - 2000) / 2000))


def _extract_subscription_monthly_amount(subscription_obj: dict) -> float:
    price_data = (
        ((subscription_obj.get("items", {}) or {}).get("data", [{}])[0].get("price", {}) or {})
    )
    recurring = (price_data.get("recurring") or {}) if isinstance(price_data, dict) else {}
    recurring_interval = str(recurring.get("interval") or "month").strip().lower()
    recurring_interval_count = int(recurring.get("interval_count") or 1)
    unit_amount = float(price_data.get("unit_amount") or 0) / 100.0
    if recurring_interval == "year":
        divisor = max(1, 12 * recurring_interval_count)
        return unit_amount / divisor
    return unit_amount / max(1, recurring_interval_count)


def _is_prod_env() -> bool:
    return (settings.ENV or "").strip().lower() == "prod"


def _require_stripe_secret_key() -> str:
    secret_key = (settings.STRIPE_SECRET_KEY or "").strip()
    if not secret_key:
        raise HTTPException(status_code=503, detail="Stripe is not configured.")
    return secret_key


def _resolve_checkout_success_url() -> str:
    return resolve_billing_url("BILLING_SUCCESS_URL")


def _resolve_checkout_cancel_url() -> str:
    return resolve_billing_url("BILLING_CANCEL_URL")


def _resolve_portal_return_url() -> str:
    return resolve_billing_url("BILLING_PORTAL_RETURN_URL")


def _normalize_billing_interval(value: str | None) -> str:
    normalized = (value or "monthly").strip().lower()
    if normalized in {"monthly", "yearly"}:
        return normalized
    raise HTTPException(status_code=400, detail="billing_interval must be 'monthly' or 'yearly'.")


def _normalize_checkout_plan_code(value: str | None) -> str:
    normalized = (value or "premium").strip().lower()
    if normalized == "premium":
        return normalized
    raise HTTPException(status_code=400, detail="plan_code must be 'premium' for checkout.")


def _resolve_stripe_checkout_price_ids(billing_interval: str) -> tuple[str, str]:
    if billing_interval == "yearly":
        base_price_id = (settings.STRIPE_PRICE_ID_PREMIUM_BASE_YEARLY or "").strip()
        pack_price_id = (settings.STRIPE_PRICE_ID_PREMIUM_PACK_YEARLY or "").strip()
        if not base_price_id:
            raise HTTPException(status_code=503, detail="Yearly premium base billing is not configured.")
        return base_price_id, pack_price_id

    base_price_id = (settings.STRIPE_PRICE_ID_PREMIUM_BASE_MONTHLY or "").strip()
    pack_price_id = (settings.STRIPE_PRICE_ID_PREMIUM_PACK_MONTHLY or "").strip()
    if not base_price_id:
        raise HTTPException(status_code=503, detail="Monthly premium base billing is not configured.")
    return base_price_id, pack_price_id


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
        log_event(
            logger,
            logging.INFO,
            "billing_webhook_duplicate",
            "Duplicate billing webhook ignored.",
            provider=provider,
            event_id=event_id,
            event_type=event_type,
            tenant_id=tenant_id,
        )
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
        ensure_partner_commission_for_invoice(
            db,
            invoice=invoice,
            referral_code=str(invoice_data.get("referral_code") or "").strip().lower() or None,
        )

    webhook_event.processed_at_utc = utc_now()
    tenant.last_seen_at_utc = utc_now()
    db.commit()

    log_event(
        logger,
        logging.INFO,
        "billing_webhook_processed",
        "Billing webhook processed.",
        provider=provider,
        event_id=event_id,
        event_type=event_type,
        tenant_id=tenant_id,
    )

    return BillingWebhookResponse(status="ok", event_id=event_id, processed=True)


@router.post("/billing/checkout/session", response_model=CheckoutSessionResponse)
def create_checkout_session(
    payload: CheckoutSessionRequest,
    tenant_auth: tuple[str, str] = Depends(require_tenant_headers),
) -> CheckoutSessionResponse:
    header_tenant_id, header_api_token = tenant_auth
    enforce_tenant_match(payload.tenant_id, header_tenant_id, "Payload tenant_id")

    normalized_plan_code = _normalize_checkout_plan_code(payload.plan_code)
    with SessionLocal() as db:
        tenant = load_authenticated_tenant(db, header_tenant_id, header_api_token)
        require_tenant_feature(db, tenant, "billing_checkout")
        referral = db.scalar(select(PartnerReferral).where(PartnerReferral.tenant_id == tenant.tenant_id))
        latest_deep_scan = _load_latest_deep_scan(db, tenant.tenant_id)
        record_count = _deep_scan_record_count(latest_deep_scan)
        package_count = _additional_record_package_count(record_count)

    billing_interval = _normalize_billing_interval(payload.billing_interval)
    checkout_metadata = {
        "tenant_id": payload.tenant_id,
        "plan_code": normalized_plan_code,
        "billing_interval": billing_interval,
        "tenant_environment": str(getattr(tenant, "environment_name", "") or "").strip(),
        "record_count": str(record_count),
        "package_size": "2000",
        "package_count": str(package_count),
    }
    if referral is not None:
        checkout_metadata["referral_code"] = str(referral.referral_code or "").strip().lower()
        checkout_metadata["attribution_source"] = str(referral.attribution_source or "").strip().lower()

    try:
        success_url = _resolve_checkout_success_url()
        cancel_url = _resolve_checkout_cancel_url()
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    stripe.api_key = _require_stripe_secret_key()
    base_price_id, pack_price_id = _resolve_stripe_checkout_price_ids(billing_interval)
    line_items = [{"price": base_price_id, "quantity": 1}]
    if package_count > 0:
        if not pack_price_id:
            raise HTTPException(
                status_code=503,
                detail="Stripe record package billing is not configured for the tenant's data volume.",
            )
        line_items.append({"price": pack_price_id, "quantity": package_count})

    try:
        session = stripe.checkout.Session.create(
            mode="subscription",
            client_reference_id=payload.tenant_id,
            line_items=line_items,
            success_url=success_url,
            cancel_url=cancel_url,
            metadata=checkout_metadata,
            subscription_data={
                "metadata": checkout_metadata
            },
        )
    except Exception:
        logger.exception(
            "Stripe checkout session creation failed.",
            extra={
                "event": "billing_checkout_failed",
                "tenant_id": payload.tenant_id,
                "billing_interval": billing_interval,
            },
        )
        raise

    log_event(
        logger,
        logging.INFO,
        "billing_checkout_created",
        "Stripe checkout session created.",
        tenant_id=payload.tenant_id,
        billing_interval=billing_interval,
        package_count=package_count,
    )
    return CheckoutSessionResponse(
        checkout_session_id=session.id,
        checkout_url=session.url,
        provider="stripe",
        tenant_id=payload.tenant_id,
        plan_code=normalized_plan_code,
        billing_interval=billing_interval,
    )


@router.post("/billing/portal", response_model=BillingPortalResponse)
def create_billing_portal_session(
    payload: BillingPortalRequest,
    tenant_auth: tuple[str, str] = Depends(require_tenant_headers),
) -> BillingPortalResponse:
    header_tenant_id, header_api_token = tenant_auth
    enforce_tenant_match(payload.tenant_id, header_tenant_id, "Payload tenant_id")

    with SessionLocal() as db:
        tenant = load_authenticated_tenant(db, header_tenant_id, header_api_token)
        require_tenant_feature(db, tenant, "billing_portal")
        subscription = get_latest_subscription_for_tenant(db, tenant.tenant_id)

    if subscription is None or not (subscription.provider_subscription_id or "").strip():
        raise HTTPException(status_code=404, detail="No active subscription found for tenant.")

    try:
        return_url = _resolve_portal_return_url()
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    stripe.api_key = _require_stripe_secret_key()
    provider_subscription_id = (subscription.provider_subscription_id or "").strip()
    stripe_subscription = stripe.Subscription.retrieve(provider_subscription_id)
    customer_id = str(getattr(stripe_subscription, "customer", "") or "").strip()
    if not customer_id:
        raise HTTPException(status_code=502, detail="Stripe customer reference missing on subscription.")

    portal = stripe.billing_portal.Session.create(
        customer=customer_id,
        return_url=return_url,
    )
    log_event(
        logger,
        logging.INFO,
        "billing_portal_created",
        "Stripe billing portal session created.",
        tenant_id=payload.tenant_id,
        provider_subscription_id=provider_subscription_id,
    )
    return BillingPortalResponse(
        provider="stripe",
        tenant_id=payload.tenant_id,
        portal_url=str(getattr(portal, "url", "") or ""),
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


@router.get("/billing/checkout/session/status", response_model=CheckoutSessionSyncResponse)
def sync_checkout_session_status(
    session_id: str,
    tenant_auth: tuple[str, str] = Depends(require_tenant_headers),
) -> CheckoutSessionSyncResponse:
    header_tenant_id, header_api_token = tenant_auth
    if not (session_id or "").strip():
        raise HTTPException(status_code=400, detail="session_id is required.")

    stripe.api_key = _require_stripe_secret_key()
    checkout = _stripe_to_plain_data(stripe.checkout.Session.retrieve(
        session_id,
        expand=["subscription", "subscription.items.data.price"],
    ))

    tenant_id_from_session = str((checkout.get("metadata", {}) or {}).get("tenant_id") or "").strip()
    if tenant_id_from_session:
        enforce_tenant_match(tenant_id_from_session, header_tenant_id, "Checkout metadata tenant_id")

    subscription_obj = checkout.get("subscription")
    if not subscription_obj:
        status_payload = get_billing_subscription_status(tenant_auth)
        return CheckoutSessionSyncResponse(
            status="pending",
            checkout_session_id=session_id,
            subscription_status=status_payload,
        )

    if not isinstance(subscription_obj, dict):
        subscription_obj = _stripe_to_plain_data(stripe.Subscription.retrieve(str(subscription_obj)))

    provider_subscription_id = str(subscription_obj.get("id") or "").strip()
    if not provider_subscription_id:
        raise HTTPException(status_code=502, detail="Stripe subscription id missing in checkout session.")

    resolved_tenant_id = tenant_id_from_session or header_tenant_id

    with SessionLocal() as db:
        tenant = load_authenticated_tenant(db, header_tenant_id, header_api_token)
        enforce_tenant_match(resolved_tenant_id, tenant.tenant_id, "Resolved tenant_id")

        subscription = upsert_subscription_from_payload(
            db,
            tenant_id=tenant.tenant_id,
            provider="stripe",
            provider_subscription_id=provider_subscription_id,
            status=str(subscription_obj.get("status") or "incomplete").lower(),
            plan_code=str((subscription_obj.get("metadata", {}) or {}).get("plan_code") or "premium").lower(),
            currency=str(subscription_obj.get("currency") or "EUR").upper(),
            amount_monthly=float(_extract_subscription_monthly_amount(subscription_obj)),
            current_period_start_utc=_dt_from_unix(subscription_obj.get("current_period_start")),
            current_period_end_utc=_dt_from_unix(subscription_obj.get("current_period_end")),
            cancel_at_period_end=bool(subscription_obj.get("cancel_at_period_end") or False),
            canceled_at_utc=_dt_from_unix(subscription_obj.get("canceled_at")),
        )
        sync_tenant_license_from_subscription(tenant, subscription)
        tenant.last_seen_at_utc = utc_now()
        db.commit()

    status_payload = get_billing_subscription_status(tenant_auth)
    return CheckoutSessionSyncResponse(
        status="synced",
        checkout_session_id=session_id,
        subscription_status=status_payload,
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
            raise HTTPException(status_code=500, detail="Stripe webhook configuration is incomplete.")
        try:
            stripe_event = stripe.Webhook.construct_event(body_bytes, stripe_signature, webhook_secret)
            event = _stripe_to_plain_data(stripe_event)
        except Exception:
            logger.exception(
                "Stripe webhook signature verification failed.",
                extra={
                    "event": "billing_webhook_signature_invalid",
                    "request_id": getattr(request.state, "request_id", None),
                },
            )
            raise HTTPException(status_code=400, detail="Invalid Stripe webhook signature.") from None

        if not isinstance(event, dict):
            log_event(
                logger,
                logging.ERROR,
                "billing_webhook_invalid_payload",
                "Stripe webhook normalization failed.",
                request_id=getattr(request.state, "request_id", None),
                payload_type=type(event).__name__,
            )
            raise HTTPException(status_code=500, detail="Invalid Stripe webhook payload.")

        event_type = str(event.get("type") or "").strip().lower()
        event_id = str(event.get("id") or "").strip() or f"evt_{uuid4().hex}"
        data_object = event.get("data", {}).get("object", {}) or {}
        occurred_at_utc = _dt_from_unix(event.get("created"))

        if event_type not in SUPPORTED_STRIPE_EVENTS:
            # Acknowledge unsupported events so Stripe stops retrying.
            log_event(
                logger,
                logging.INFO,
                "billing_webhook_ignored",
                "Unsupported Stripe webhook ignored.",
                stripe_event_type=event_type,
                stripe_event_id=event_id,
            )
            return BillingWebhookResponse(status="ignored", event_id=event_id, processed=False)

        subscription_data: dict | None = None
        invoice_data: dict | None = None
        tenant_id = ""

        if event_type == "checkout.session.completed":
            tenant_id = str((data_object.get("metadata", {}) or {}).get("tenant_id") or "").strip()
            if not tenant_id:
                log_event(
                    logger,
                    logging.INFO,
                    "billing_webhook_ignored",
                    "Checkout session webhook ignored because tenant metadata is missing.",
                    stripe_event_type=event_type,
                    stripe_event_id=event_id,
                )
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

        if event_type == "checkout.session.expired":
            tenant_id = str((data_object.get("metadata", {}) or {}).get("tenant_id") or "").strip()
            if not tenant_id:
                log_event(
                    logger,
                    logging.INFO,
                    "billing_webhook_ignored",
                    "Checkout expired webhook ignored because tenant metadata is missing.",
                    stripe_event_type=event_type,
                    stripe_event_id=event_id,
                )
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
                "amount_monthly": float(_extract_subscription_monthly_amount(data_object)),
                "current_period_end_utc": _dt_from_unix(data_object.get("current_period_end")),
                "cancel_at_period_end": bool(data_object.get("cancel_at_period_end")),
                "canceled_at_utc": _dt_from_unix(data_object.get("canceled_at")),
            }
            tenant_id = str((data_object.get("metadata", {}) or {}).get("tenant_id") or "").strip()

        if event_type.startswith("invoice."):
            provider_subscription_id = str(data_object.get("subscription") or "").strip() or None
            invoice_metadata = ((data_object.get("subscription_details") or {}).get("metadata") or {})
            invoice_data = {
                "id": data_object.get("id"),
                "provider_subscription_id": provider_subscription_id,
                "status": data_object.get("status"),
                "currency": (data_object.get("currency") or "EUR").upper(),
                "amount_total": float(data_object.get("amount_due") or 0) / 100.0,
                "amount_paid": float(data_object.get("amount_paid") or 0) / 100.0,
                "hosted_invoice_url": data_object.get("hosted_invoice_url"),
                "paid_at_utc": _dt_from_unix(((data_object.get("status_transitions") or {}).get("paid_at"))),
                "referral_code": str(invoice_metadata.get("referral_code") or "").strip().lower() or None,
            }
            tenant_id = str(invoice_metadata.get("tenant_id") or "").strip()
            if not tenant_id:
                with SessionLocal() as db:
                    tenant = _find_tenant_for_invoice(db, None, provider_subscription_id)
                    if tenant is not None:
                        tenant_id = tenant.tenant_id

        if not tenant_id:
            # acknowledge irrelevant Stripe events without failing delivery retries
            log_event(
                logger,
                logging.INFO,
                "billing_webhook_ignored",
                "Stripe webhook ignored because tenant resolution failed.",
                stripe_event_type=event_type,
                stripe_event_id=event_id,
            )
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

    if _is_prod_env():
        raise HTTPException(status_code=400, detail="Stripe-Signature header is required in production.")

    try:
        payload = BillingWebhookPayload.model_validate_json(body_text)
    except Exception:
        logger.exception(
            "Manual webhook payload validation failed.",
            extra={
                "event": "billing_webhook_manual_payload_invalid",
                "request_id": getattr(request.state, "request_id", None),
            },
        )
        raise HTTPException(status_code=400, detail="Invalid webhook payload.") from None

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
