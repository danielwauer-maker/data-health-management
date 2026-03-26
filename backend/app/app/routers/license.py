from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel
from sqlalchemy import select

from app.db import SessionLocal
from app.models import Tenant

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

    features = ["quick_scan"]

    if normalized_plan in {"standard", "premium"}:
        features.append("scan_sync")

    if normalized_plan == "premium":
        features.extend(
            [
                "deep_scan",
                "advanced_checks",
            ]
        )

    return features


@router.get("/license/status", response_model=LicenseStatusResponse)
def get_license_status(
    x_tenant_id: str = Header(..., alias="X-Tenant-Id"),
    x_api_token: str = Header(..., alias="X-Api-Token"),
) -> LicenseStatusResponse:
    with SessionLocal() as db:
        tenant = db.scalar(
            select(Tenant).where(Tenant.tenant_id == x_tenant_id)
        )

        if tenant is None:
            raise HTTPException(status_code=404, detail="Tenant not found.")

        if tenant.api_token != x_api_token:
            raise HTTPException(status_code=401, detail="Invalid API token.")

        features = build_features(tenant.current_plan, tenant.license_status)

        return LicenseStatusResponse(
            tenant_id=tenant.tenant_id,
            plan=tenant.current_plan or "free",
            license_status=tenant.license_status or "trial",
            features=features,
        )
