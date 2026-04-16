from app.models import LicensePricingConfig
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

