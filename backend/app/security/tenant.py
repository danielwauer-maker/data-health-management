import hmac

from fastapi import Header, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Tenant
from app.security.token_hash import hash_api_token, verify_api_token


def require_tenant_headers(
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-Id"),
    x_api_token: str | None = Header(default=None, alias="X-Api-Token"),
) -> tuple[str, str]:
    if not x_tenant_id or not x_api_token:
        raise HTTPException(
            status_code=401,
            detail="Missing tenant authentication headers.",
        )
    return x_tenant_id, x_api_token


def load_authenticated_tenant(
    db: Session,
    header_tenant_id: str,
    header_api_token: str,
) -> Tenant:
    tenant = db.scalar(select(Tenant).where(Tenant.tenant_id == header_tenant_id))
    if tenant is None:
        raise HTTPException(status_code=404, detail="Tenant not found.")

    if tenant.api_token_hash:
        if not verify_api_token(header_api_token, tenant.api_token_hash):
            raise HTTPException(status_code=403, detail="Invalid API token.")
    else:
        # Legacy fallback for existing tenants created before token hashing.
        if not hmac.compare_digest(tenant.api_token or "", header_api_token):
            raise HTTPException(status_code=403, detail="Invalid API token.")

        tenant.api_token_hash = hash_api_token(header_api_token)
        db.flush()

    return tenant


def enforce_tenant_match(
    expected_tenant_id: str,
    header_tenant_id: str,
    source_name: str = "tenant_id",
) -> None:
    if expected_tenant_id != header_tenant_id:
        raise HTTPException(
            status_code=400,
            detail=f"{source_name} does not match X-Tenant-Id header.",
        )