from __future__ import annotations

import os
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

TEST_DB_PATH = Path(__file__).resolve().parent / ".pytest.sqlite3"
if TEST_DB_PATH.exists():
    TEST_DB_PATH.unlink()

os.environ["ENV"] = "test"
os.environ["APP_ENV"] = "test"
os.environ["SECRET_KEY"] = "test-secret-key-with-sufficient-length-123"
os.environ["ADMIN_USERNAME"] = "admin-test"
os.environ["ADMIN_PASSWORD"] = "admin-password-for-tests-123"
os.environ["DATABASE_URL"] = f"sqlite:///{TEST_DB_PATH.as_posix()}"

from app.core.settings import settings  # noqa: E402
from app.db import Base, SessionLocal, engine  # noqa: E402
from app.models import Scan, ScanIssueRecord, Subscription, Tenant  # noqa: E402
from app.security.token_hash import hash_api_token  # noqa: E402
import app.main as app_main  # noqa: E402


@pytest.fixture(autouse=True)
def reset_database():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    yield


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setattr(app_main, "wait_for_database", lambda: None)
    monkeypatch.setattr(app_main, "ensure_schema_is_migrated", lambda: None)
    with TestClient(app_main.app) as test_client:
        yield test_client


@pytest.fixture
def db_session():
    with SessionLocal() as db:
        yield db


@pytest.fixture
def settings_state(monkeypatch):
    original_values = {
        "ENV": settings.ENV,
        "APP_BASE_URL": settings.APP_BASE_URL,
        "BILLING_SUCCESS_URL": settings.BILLING_SUCCESS_URL,
        "BILLING_CANCEL_URL": settings.BILLING_CANCEL_URL,
        "BILLING_PORTAL_RETURN_URL": settings.BILLING_PORTAL_RETURN_URL,
        "STRIPE_SECRET_KEY": settings.STRIPE_SECRET_KEY,
        "STRIPE_WEBHOOK_SECRET": settings.STRIPE_WEBHOOK_SECRET,
        "STRIPE_PRICE_ID_PREMIUM": settings.STRIPE_PRICE_ID_PREMIUM,
        "STRIPE_PRICE_ID_PREMIUM_YEARLY": settings.STRIPE_PRICE_ID_PREMIUM_YEARLY,
        "STRIPE_PRICE_ID_PREMIUM_BASE_MONTHLY": settings.STRIPE_PRICE_ID_PREMIUM_BASE_MONTHLY,
        "STRIPE_PRICE_ID_PREMIUM_BASE_YEARLY": settings.STRIPE_PRICE_ID_PREMIUM_BASE_YEARLY,
        "STRIPE_PRICE_ID_PREMIUM_PACK_MONTHLY": settings.STRIPE_PRICE_ID_PREMIUM_PACK_MONTHLY,
        "STRIPE_PRICE_ID_PREMIUM_PACK_YEARLY": settings.STRIPE_PRICE_ID_PREMIUM_PACK_YEARLY,
    }

    def apply(**overrides):
        for key, value in overrides.items():
            monkeypatch.setattr(settings, key, value)

    yield apply

    for key, value in original_values.items():
        monkeypatch.setattr(settings, key, value)


@pytest.fixture
def tenant_factory():
    def _create(*, plan: str = "free", license_status: str = "trial", tenant_id: str | None = None):
        resolved_tenant_id = tenant_id or f"ten_{uuid4().hex[:8]}"
        api_token = f"tok_{uuid4().hex}"
        now = datetime.now(timezone.utc)
        with SessionLocal() as db:
            tenant = Tenant(
                tenant_id=resolved_tenant_id,
                api_token=api_token,
                api_token_hash=hash_api_token(api_token),
                environment_name="test",
                app_version="1.0.0",
                created_at_utc=now,
                last_seen_at_utc=now,
                current_plan=plan,
                license_status=license_status,
            )
            db.add(tenant)
            db.commit()
        return {"tenant_id": resolved_tenant_id, "api_token": api_token}

    return _create


def auth_headers(tenant_info: dict[str, str]) -> dict[str, str]:
    return {
        "X-Tenant-Id": tenant_info["tenant_id"],
        "X-Api-Token": tenant_info["api_token"],
    }


@pytest.fixture
def auth_header_factory():
    return auth_headers


@pytest.fixture
def deep_scan_factory():
    def _create(*, tenant_id: str, scan_id: str, total_records: int = 0):
        now = datetime.now(timezone.utc)
        with SessionLocal() as db:
            db.add(
                Scan(
                    scan_id=scan_id,
                    tenant_id=tenant_id,
                    scan_type="deep",
                    generated_at_utc=now,
                    data_score=90,
                    checks_count=10,
                    issues_count=1,
                    premium_available=True,
                    summary_headline="ok",
                    summary_rating="good",
                    total_records=total_records,
                    estimated_loss_eur=0.0,
                    potential_saving_eur=0.0,
                    estimated_premium_price_monthly=0.0,
                    roi_eur=0.0,
                )
            )
            db.commit()

    return _create


@pytest.fixture
def subscription_factory():
    def _create(*, tenant_id: str, provider_subscription_id: str = "sub_test", status: str = "active"):
        now = datetime.now(timezone.utc)
        with SessionLocal() as db:
            db.add(
                Subscription(
                    tenant_id=tenant_id,
                    provider="stripe",
                    provider_subscription_id=provider_subscription_id,
                    status=status,
                    plan_code="premium",
                    currency="EUR",
                    amount_monthly=149.0,
                    current_period_start_utc=now,
                    current_period_end_utc=now,
                    cancel_at_period_end=False,
                    canceled_at_utc=None,
                    created_at_utc=now,
                    updated_at_utc=now,
                )
            )
            db.commit()

    return _create


@pytest.fixture
def scan_factory():
    def _create(*, tenant_id: str, scan_id: str):
        now = datetime.now(timezone.utc)
        with SessionLocal() as db:
            scan = Scan(
                scan_id=scan_id,
                tenant_id=tenant_id,
                scan_type="deep",
                generated_at_utc=now,
                data_score=80,
                checks_count=5,
                issues_count=1,
                premium_available=True,
                summary_headline="headline",
                summary_rating="rating",
                total_records=100,
                estimated_loss_eur=10.0,
                potential_saving_eur=5.0,
                estimated_premium_price_monthly=149.0,
                roi_eur=0.0,
            )
            db.add(scan)
            db.flush()
            db.add(
                ScanIssueRecord(
                    scan_id=scan_id,
                    code="ISSUE_1",
                    title="Issue",
                    severity="medium",
                    affected_count=1,
                    premium_only=False,
                    recommendation_preview="Fix it",
                    estimated_impact_eur=10.0,
                )
            )
            db.commit()

    return _create
