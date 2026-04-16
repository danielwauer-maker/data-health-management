from __future__ import annotations

from types import SimpleNamespace

from app.db import SessionLocal
from app.models import Subscription, Tenant


def test_checkout_session_uses_configured_default_urls(
    client,
    tenant_factory,
    auth_header_factory,
    deep_scan_factory,
    settings_state,
    monkeypatch,
):
    tenant = tenant_factory(plan="free", license_status="trial")
    deep_scan_factory(tenant_id=tenant["tenant_id"], scan_id="scan_deep_1", total_records=5000)
    settings_state(
        ENV="prod",
        STRIPE_SECRET_KEY="sk_test",
        STRIPE_PRICE_ID_PREMIUM_BASE_MONTHLY="price_base_month",
        STRIPE_PRICE_ID_PREMIUM_BASE_YEARLY="price_base_year",
        STRIPE_PRICE_ID_PREMIUM_PACK_MONTHLY="price_pack_month",
        STRIPE_PRICE_ID_PREMIUM_PACK_YEARLY="price_pack_year",
        APP_BASE_URL="https://app.example.com",
        BILLING_SUCCESS_URL=None,
        BILLING_CANCEL_URL=None,
    )

    captured = {}

    def fake_create(**kwargs):
        captured.update(kwargs)
        return SimpleNamespace(id="cs_test_123", url="https://stripe.example/session")

    monkeypatch.setattr("app.routers.billing.stripe.checkout.Session.create", fake_create)

    response = client.post(
        "/billing/checkout/session",
        headers=auth_header_factory(tenant),
        json={
            "tenant_id": tenant["tenant_id"],
            "plan_code": "premium",
            "billing_interval": "monthly",
            "success_url": "https://evil.example/success",
            "cancel_url": "https://evil.example/cancel",
        },
    )

    assert response.status_code == 200
    assert response.json()["provider"] == "stripe"
    assert captured["success_url"] == "https://app.example.com/billing/success?session_id={CHECKOUT_SESSION_ID}"
    assert captured["cancel_url"] == "https://app.example.com/billing/cancel"
    assert captured["line_items"] == [
        {"price": "price_base_month", "quantity": 1},
        {"price": "price_pack_month", "quantity": 2},
    ]


def test_checkout_session_fails_without_safe_billing_url_config(
    client,
    tenant_factory,
    auth_header_factory,
    settings_state,
    monkeypatch,
):
    tenant = tenant_factory(plan="free", license_status="trial")
    settings_state(
        ENV="prod",
        STRIPE_SECRET_KEY="sk_test",
        STRIPE_PRICE_ID_PREMIUM_BASE_MONTHLY="price_base_month",
        STRIPE_PRICE_ID_PREMIUM_BASE_YEARLY="price_base_year",
        STRIPE_PRICE_ID_PREMIUM_PACK_MONTHLY="price_pack_month",
        STRIPE_PRICE_ID_PREMIUM_PACK_YEARLY="price_pack_year",
        APP_BASE_URL=None,
        BILLING_SUCCESS_URL=None,
        BILLING_CANCEL_URL=None,
    )
    response = client.post(
        "/billing/checkout/session",
        headers=auth_header_factory(tenant),
        json={"tenant_id": tenant["tenant_id"], "plan_code": "premium", "billing_interval": "monthly"},
    )

    assert response.status_code == 503
    assert "BILLING_SUCCESS_URL" in response.json()["detail"]


def test_billing_portal_uses_safe_return_url(
    client,
    tenant_factory,
    auth_header_factory,
    subscription_factory,
    settings_state,
    monkeypatch,
):
    tenant = tenant_factory(plan="premium", license_status="active")
    subscription_factory(tenant_id=tenant["tenant_id"], provider_subscription_id="sub_live")
    settings_state(
        STRIPE_SECRET_KEY="sk_test",
        STRIPE_PRICE_ID_PREMIUM="price_portal",
        APP_BASE_URL="https://app.example.com",
        BILLING_PORTAL_RETURN_URL=None,
    )

    captured = {}
    monkeypatch.setattr(
        "app.routers.billing.stripe.Subscription.retrieve",
        lambda subscription_id: SimpleNamespace(customer="cus_123"),
    )

    def fake_portal_create(**kwargs):
        captured.update(kwargs)
        return SimpleNamespace(url="https://stripe.example/portal")

    monkeypatch.setattr("app.routers.billing.stripe.billing_portal.Session.create", fake_portal_create)

    response = client.post(
        "/billing/portal",
        headers=auth_header_factory(tenant),
        json={"tenant_id": tenant["tenant_id"], "return_url": "https://evil.example/portal"},
    )

    assert response.status_code == 200
    assert response.json()["portal_url"] == "https://stripe.example/portal"
    assert captured["return_url"] == "https://app.example.com/billing"


def test_billing_portal_works_without_legacy_price_id(
    client,
    tenant_factory,
    auth_header_factory,
    subscription_factory,
    settings_state,
    monkeypatch,
):
    tenant = tenant_factory(plan="premium", license_status="active")
    subscription_factory(tenant_id=tenant["tenant_id"], provider_subscription_id="sub_portal")
    settings_state(
        ENV="prod",
        STRIPE_SECRET_KEY="sk_test",
        STRIPE_PRICE_ID_PREMIUM=None,
        APP_BASE_URL="https://app.example.com",
        BILLING_PORTAL_RETURN_URL=None,
    )

    monkeypatch.setattr(
        "app.routers.billing.stripe.Subscription.retrieve",
        lambda subscription_id: SimpleNamespace(customer="cus_portal"),
    )
    monkeypatch.setattr(
        "app.routers.billing.stripe.billing_portal.Session.create",
        lambda **kwargs: SimpleNamespace(url="https://stripe.example/portal/live"),
    )

    response = client.post(
        "/billing/portal",
        headers=auth_header_factory(tenant),
        json={"tenant_id": tenant["tenant_id"]},
    )

    assert response.status_code == 200
    assert response.json()["provider"] == "stripe"
    assert response.json()["portal_url"] == "https://stripe.example/portal/live"


def test_billing_portal_fails_when_return_url_config_is_missing(
    client,
    tenant_factory,
    auth_header_factory,
    subscription_factory,
    settings_state,
):
    tenant = tenant_factory(plan="premium", license_status="active")
    subscription_factory(tenant_id=tenant["tenant_id"], provider_subscription_id="sub_live")
    settings_state(
        ENV="prod",
        STRIPE_SECRET_KEY="sk_test",
        STRIPE_PRICE_ID_PREMIUM="price_portal",
        APP_BASE_URL=None,
        BILLING_PORTAL_RETURN_URL=None,
    )

    response = client.post(
        "/billing/portal",
        headers=auth_header_factory(tenant),
        json={"tenant_id": tenant["tenant_id"]},
    )

    assert response.status_code == 503
    assert "BILLING_PORTAL_RETURN_URL" in response.json()["detail"]


def test_monthly_checkout_does_not_require_yearly_price_ids(
    client,
    tenant_factory,
    auth_header_factory,
    settings_state,
    monkeypatch,
):
    tenant = tenant_factory(plan="free", license_status="trial")
    settings_state(
        ENV="prod",
        STRIPE_SECRET_KEY="sk_test",
        STRIPE_PRICE_ID_PREMIUM_BASE_MONTHLY="price_base_month",
        STRIPE_PRICE_ID_PREMIUM_PACK_MONTHLY="price_pack_month",
        STRIPE_PRICE_ID_PREMIUM_BASE_YEARLY=None,
        STRIPE_PRICE_ID_PREMIUM_PACK_YEARLY=None,
        BILLING_SUCCESS_URL="https://app.example.com/billing/success?session_id={CHECKOUT_SESSION_ID}",
        BILLING_CANCEL_URL="https://app.example.com/billing/cancel",
    )
    monkeypatch.setattr(
        "app.routers.billing.stripe.checkout.Session.create",
        lambda **kwargs: SimpleNamespace(id="cs_monthly", url="https://stripe.example/session"),
    )

    response = client.post(
        "/billing/checkout/session",
        headers=auth_header_factory(tenant),
        json={"tenant_id": tenant["tenant_id"], "plan_code": "premium", "billing_interval": "monthly"},
    )

    assert response.status_code == 200
    assert response.json()["checkout_session_id"] == "cs_monthly"


def test_yearly_checkout_fails_cleanly_without_yearly_price_ids(
    client,
    tenant_factory,
    auth_header_factory,
    settings_state,
):
    tenant = tenant_factory(plan="free", license_status="trial")
    settings_state(
        ENV="prod",
        STRIPE_SECRET_KEY="sk_test",
        STRIPE_PRICE_ID_PREMIUM_BASE_MONTHLY="price_base_month",
        STRIPE_PRICE_ID_PREMIUM_PACK_MONTHLY="price_pack_month",
        STRIPE_PRICE_ID_PREMIUM_BASE_YEARLY=None,
        STRIPE_PRICE_ID_PREMIUM_PACK_YEARLY=None,
        BILLING_SUCCESS_URL="https://app.example.com/billing/success?session_id={CHECKOUT_SESSION_ID}",
        BILLING_CANCEL_URL="https://app.example.com/billing/cancel",
    )

    response = client.post(
        "/billing/checkout/session",
        headers=auth_header_factory(tenant),
        json={"tenant_id": tenant["tenant_id"], "plan_code": "premium", "billing_interval": "yearly"},
    )

    assert response.status_code == 503
    assert "Yearly premium base billing is not configured." in response.json()["detail"]


def test_billing_webhook_processes_valid_signed_event_and_is_idempotent(
    client,
    tenant_factory,
    settings_state,
    monkeypatch,
):
    tenant = tenant_factory(plan="free", license_status="trial")
    settings_state(
        STRIPE_SECRET_KEY="sk_test",
        STRIPE_WEBHOOK_SECRET="whsec_test",
    )

    event = {
        "id": "evt_123",
        "type": "customer.subscription.updated",
        "created": 1710000000,
        "data": {
            "object": {
                "id": "sub_123",
                "status": "active",
                "currency": "eur",
                "cancel_at_period_end": False,
                "canceled_at": None,
                "current_period_end": 1712600000,
                "metadata": {"tenant_id": tenant["tenant_id"], "plan_code": "premium"},
                "items": {
                    "data": [
                        {
                            "price": {
                                "unit_amount": 14900,
                                "recurring": {"interval": "month", "interval_count": 1},
                            }
                        }
                    ]
                },
            }
        },
    }

    monkeypatch.setattr("app.routers.billing.stripe.Webhook.construct_event", lambda *args, **kwargs: event)

    first = client.post(
        "/billing/webhook",
        headers={"Stripe-Signature": "sig_test"},
        content=b'{"id":"evt_123"}',
    )
    second = client.post(
        "/billing/webhook",
        headers={"Stripe-Signature": "sig_test"},
        content=b'{"id":"evt_123"}',
    )

    assert first.status_code == 200
    assert first.json()["status"] == "ok"
    assert second.status_code == 200
    assert second.json()["status"] == "duplicate"

    with SessionLocal() as db:
        tenant_row = db.query(Tenant).filter(Tenant.tenant_id == tenant["tenant_id"]).one()
        subscription = db.query(Subscription).filter(Subscription.provider_subscription_id == "sub_123").one()
        assert tenant_row.current_plan == "premium"
        assert tenant_row.license_status == "active"
        assert subscription.status == "active"


def test_billing_webhook_rejects_invalid_signature(
    client,
    settings_state,
    monkeypatch,
):
    settings_state(
        STRIPE_SECRET_KEY="sk_test",
        STRIPE_WEBHOOK_SECRET="whsec_test",
    )
    monkeypatch.setattr(
        "app.routers.billing.stripe.Webhook.construct_event",
        lambda *args, **kwargs: (_ for _ in ()).throw(Exception("bad signature")),
    )

    response = client.post(
        "/billing/webhook",
        headers={"Stripe-Signature": "sig_bad"},
        content=b"{}",
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Invalid Stripe webhook signature."


def test_checkout_session_status_sync_succeeds_without_legacy_price_id(
    client,
    tenant_factory,
    auth_header_factory,
    settings_state,
    monkeypatch,
):
    tenant = tenant_factory(plan="free", license_status="trial")
    settings_state(
        ENV="prod",
        STRIPE_SECRET_KEY="sk_test",
        STRIPE_PRICE_ID_PREMIUM=None,
    )
    monkeypatch.setattr(
        "app.routers.billing.stripe.checkout.Session.retrieve",
        lambda session_id, expand=None: {
            "id": session_id,
            "metadata": {"tenant_id": tenant["tenant_id"]},
            "subscription": {
                "id": "sub_synced",
                "status": "active",
                "currency": "eur",
                "cancel_at_period_end": False,
                "canceled_at": None,
                "current_period_start": 1710000000,
                "current_period_end": 1712600000,
                "metadata": {"plan_code": "premium"},
                "items": {
                    "data": [
                        {
                            "price": {
                                "unit_amount": 14900,
                                "recurring": {"interval": "month", "interval_count": 1},
                            }
                        }
                    ]
                },
            },
        },
    )

    response = client.get(
        "/billing/checkout/session/status",
        headers=auth_header_factory(tenant),
        params={"session_id": "cs_test_sync"},
    )

    assert response.status_code == 200
    assert response.json()["status"] == "synced"
    assert response.json()["subscription_status"]["current_plan"] == "premium"


def test_checkout_session_status_returns_pending_when_subscription_missing(
    client,
    tenant_factory,
    auth_header_factory,
    settings_state,
    monkeypatch,
):
    tenant = tenant_factory(plan="free", license_status="trial")
    settings_state(
        ENV="prod",
        STRIPE_SECRET_KEY="sk_test",
        STRIPE_PRICE_ID_PREMIUM=None,
    )
    monkeypatch.setattr(
        "app.routers.billing.stripe.checkout.Session.retrieve",
        lambda session_id, expand=None: {
            "id": session_id,
            "metadata": {"tenant_id": tenant["tenant_id"]},
            "subscription": None,
        },
    )

    response = client.get(
        "/billing/checkout/session/status",
        headers=auth_header_factory(tenant),
        params={"session_id": "cs_test_pending"},
    )

    assert response.status_code == 200
    assert response.json()["status"] == "pending"


def test_checkout_session_status_requires_session_id(
    client,
    tenant_factory,
    auth_header_factory,
    settings_state,
):
    tenant = tenant_factory(plan="free", license_status="trial")
    settings_state(
        ENV="prod",
        STRIPE_SECRET_KEY="sk_test",
        STRIPE_PRICE_ID_PREMIUM=None,
    )

    response = client.get(
        "/billing/checkout/session/status",
        headers=auth_header_factory(tenant),
        params={"session_id": ""},
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "session_id is required."


def test_health_endpoints_include_request_id(client):
    response = client.get("/health", headers={"X-Request-Id": "req_123"})
    ready = client.get("/health/ready")

    assert response.status_code == 200
    assert response.headers["X-Request-Id"] == "req_123"
    assert ready.status_code == 200
    assert ready.json()["checks"]["database"] == "ok"
