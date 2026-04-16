from __future__ import annotations

from fastapi import APIRouter
from pydantic import BaseModel

from app.db import SessionLocal
from app.services.impact_service import (
    EXPLICIT_ISSUE_IMPACTS,
    ensure_default_impact_config,
    get_hourly_rate_eur,
    get_impact_definition,
)
from app.services.pricing_service import get_public_pricing_payload

router = APIRouter(tags=["public"])


class PublicPricingMarketingLocale(BaseModel):
    plan_premium_price: str
    pricing_premium_chip: str


class PublicPricingMarketing(BaseModel):
    de: PublicPricingMarketingLocale
    en: PublicPricingMarketingLocale


class PublicPricingResponse(BaseModel):
    source: str
    currency: str
    plan_code: str
    display_name: str
    base_price: float
    included_records: int
    step_records: int
    step_price: float
    annual_fixed_price: float
    monthly_note: str
    annual_note: str
    marketing: PublicPricingMarketing


class PublicLossExampleIssueResponse(BaseModel):
    minutes_per_occurrence: float
    probability: float
    frequency_per_year: float


class PublicLossExampleConfigResponse(BaseModel):
    hourly_rate_eur: float
    issues: dict[str, PublicLossExampleIssueResponse]


@router.get("/public/pricing", response_model=PublicPricingResponse)
def get_public_pricing() -> PublicPricingResponse:
    with SessionLocal() as db:
        return PublicPricingResponse.model_validate(get_public_pricing_payload(db, "premium"))


@router.get("/public/loss-examples-config", response_model=PublicLossExampleConfigResponse)
def get_public_loss_examples_config() -> PublicLossExampleConfigResponse:
    with SessionLocal() as db:
        ensure_default_impact_config(db)
        issues = {
            code: PublicLossExampleIssueResponse(
                minutes_per_occurrence=definition.minutes_per_occurrence,
                probability=definition.probability,
                frequency_per_year=definition.frequency_per_year,
            )
            for code in sorted(EXPLICIT_ISSUE_IMPACTS.keys())
            for definition in [get_impact_definition(db, code)]
        }
        return PublicLossExampleConfigResponse(
            hourly_rate_eur=round(get_hourly_rate_eur(db), 2),
            issues=issues,
        )
