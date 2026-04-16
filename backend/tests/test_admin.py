from __future__ import annotations

import base64

from app.db import SessionLocal
from app.models import ImpactSettingsConfig
from app.services.impact_service import calculate_issue_impact


def _admin_auth_header() -> dict[str, str]:
    token = base64.b64encode(b"admin-test:admin-password-for-tests-123").decode("ascii")
    return {"Authorization": f"Basic {token}"}


def test_admin_issue_cost_page_lists_estimated_loss_issue_inputs(client):
    response = client.get("/admin/config/issue-costs", headers=_admin_auth_header())

    assert response.status_code == 200
    assert "INTERNAL_HOURLY_RATE_EUR" in response.text
    assert "CUSTOMERS_MISSING_CITY" in response.text
    assert "minutes_per_occurrence" in response.text
    assert "frequency_per_year" in response.text


def test_admin_issue_cost_updates_change_estimated_loss_inputs(client):
    with SessionLocal() as db:
        before = calculate_issue_impact(db, "CUSTOMERS_MISSING_ADDRESS", 2)

    update_response = client.post(
        "/admin/config/issue-costs/CUSTOMERS_MISSING_ADDRESS",
        headers=_admin_auth_header(),
        data={
            "title": "Customers missing address",
            "minutes_per_occurrence": "12",
            "probability": "1.0",
            "frequency_per_year": "10",
            "is_active": "on",
        },
        follow_redirects=False,
    )

    hourly_response = client.post(
        "/admin/config/issue-costs/hourly-rate",
        headers=_admin_auth_header(),
        data={"hourly_rate_eur": "60"},
        follow_redirects=False,
    )

    assert update_response.status_code == 303
    assert hourly_response.status_code == 303

    with SessionLocal() as db:
        after = calculate_issue_impact(db, "CUSTOMERS_MISSING_ADDRESS", 2)
        hourly_rate = db.get(ImpactSettingsConfig, "default_hourly_rate_eur")

    assert hourly_rate is not None
    assert float(hourly_rate.value_number) == 60.0
    assert after == 240.0
    assert after != before
