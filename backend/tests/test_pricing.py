from app.models import LicensePricingConfig
from app.models import ImpactSettingsConfig, IssueImpactConfig, LicensePricingConfig
from app.services.pricing_service import get_public_pricing_payload
 

def test_public_pricing_uses_canonical_defaults_without_db_override(db_session):
    payload = get_public_pricing_payload(db_session, "premium")

    assert payload["source"] == "canonical"
    assert payload["base_price"] == 149.0
    assert payload["annual_fixed_price"] == 1788.0
    assert payload["step_price"] == 8.0


def test_public_pricing_uses_database_override_when_valid(db_session):
    db_session.add(
        LicensePricingConfig(
            plan_code="premium",
            display_name="Premium Plus",
            base_price_monthly=199.0,
            included_records=4000,
            additional_price_per_1000_records=12.0,
            is_active=True,
        )
    )
    db_session.commit()

    payload = get_public_pricing_payload(db_session, "premium")

    assert payload["source"] == "database"
    assert payload["display_name"] == "Premium Plus"
    assert payload["base_price"] == 199.0
    assert payload["annual_fixed_price"] == 2388.0


def test_public_pricing_falls_back_when_database_override_is_invalid(db_session):
    db_session.add(
        LicensePricingConfig(
            plan_code="premium",
            display_name="",
            base_price_monthly=-99.0,
            included_records=-1,
            additional_price_per_1000_records=-5.0,
            is_active=True,
        )
    )
    db_session.commit()

    payload = get_public_pricing_payload(db_session, "premium")

    assert payload["source"] == "canonical"
    assert payload["base_price"] == 149.0
    assert payload["step_price"] == 8.0
    assert payload["included_records"] == 2000


def test_public_loss_examples_config_uses_current_hourly_rate_and_issue_factors(client, db_session):
    hourly_rate = db_session.get(ImpactSettingsConfig, "default_hourly_rate_eur")
    if hourly_rate is None:
        hourly_rate = ImpactSettingsConfig(
            key="default_hourly_rate_eur",
            value_number=62.0,
            title="Default hourly rate (EUR)",
        )
        db_session.add(hourly_rate)
    else:
        hourly_rate.value_number = 62.0

    issue = db_session.get(IssueImpactConfig, "SALES_LINES_ZERO_PRICE")
    if issue is None:
        issue = IssueImpactConfig(
            code="SALES_LINES_ZERO_PRICE",
            title="Sales lines zero price",
            category="sales",
            minutes_per_occurrence=19.0,
            probability=0.8,
            frequency_per_year=9.0,
            is_active=True,
        )
        db_session.add(issue)
    else:
        issue.minutes_per_occurrence = 19.0
        issue.probability = 0.8
        issue.frequency_per_year = 9.0
        issue.is_active = True

    db_session.commit()

    response = client.get("/public/loss-examples-config")

    assert response.status_code == 200
    payload = response.json()
    assert payload["hourly_rate_eur"] == 62.0
    assert payload["issues"]["SALES_LINES_ZERO_PRICE"] == {
        "minutes_per_occurrence": 19.0,
        "probability": 0.8,
        "frequency_per_year": 9.0,
    }
