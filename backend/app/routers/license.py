from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from app.db import SessionLocal
from app.security.tenant import load_authenticated_tenant, require_tenant_headers

router = APIRouter(tags=["license"])


class LicenseStatusResponse(BaseModel):
    tenant_id: str
    plan: str
    license_status: str
    features: list[str]


def build_features(plan: str, license_status: str) -> list[str]:
    normalized_plan = (plan or "free").lower()
    normalized_license_status = (license_status or "trial").lower()

    if normalized_license_status in {"expired", "blocked"}:
        return []

    features = ["scan_sync", "deep_scan"]

    if normalized_plan == "premium":
        features.extend(
            [
                "advanced_checks",
                "recommendations",
                "record_drilldown",
            ]
        )

    return features


@router.get("/license/status", response_model=LicenseStatusResponse)
def get_license_status(
    tenant_auth: tuple[str, str] = Depends(require_tenant_headers),
) -> LicenseStatusResponse:
    header_tenant_id, header_api_token = tenant_auth

    with SessionLocal() as db:
        tenant = load_authenticated_tenant(db, header_tenant_id, header_api_token)

        normalized_plan = (tenant.current_plan or "free").lower()
        if normalized_plan not in {"free", "premium"}:
            normalized_plan = "free"

        features = build_features(normalized_plan, tenant.license_status)

        return LicenseStatusResponse(
            tenant_id=tenant.tenant_id,
            plan=normalized_plan,
            license_status=tenant.license_status or "trial",
            features=features,
        )
