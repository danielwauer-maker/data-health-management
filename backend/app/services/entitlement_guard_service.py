from __future__ import annotations

from fastapi import HTTPException

from app.models import Tenant
from app.services.billing_service import resolve_effective_license
from app.services.entitlement_service import resolve_features


def get_tenant_features(db, tenant: Tenant) -> set[str]:
    plan, license_status = resolve_effective_license(db, tenant)
    return set(resolve_features(plan, license_status))


def require_tenant_feature(db, tenant: Tenant, feature: str) -> None:
    features = get_tenant_features(db, tenant)
    if feature not in features:
        raise HTTPException(status_code=403, detail=f"Feature '{feature}' is not available for this tenant.")
