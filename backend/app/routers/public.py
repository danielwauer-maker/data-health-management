from __future__ import annotations

from fastapi import APIRouter
from pydantic import BaseModel

from app.db import SessionLocal
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


@router.get("/public/pricing", response_model=PublicPricingResponse)
def get_public_pricing() -> PublicPricingResponse:
    with SessionLocal() as db:
        return PublicPricingResponse.model_validate(get_public_pricing_payload(db, "premium"))
