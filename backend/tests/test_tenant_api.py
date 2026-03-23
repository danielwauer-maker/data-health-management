from sqlalchemy import select

from app.models import Tenant


def test_register_tenant_creates_database_record(client, db_session):
    payload = {
        "environment_name": "BC Sandbox",
        "app_version": "0.4.0",
    }

    response = client.post("/tenant/register", json=payload)

    assert response.status_code == 200

    data = response.json()
    assert data["tenant_id"].startswith("ten_")
    assert data["api_token"].startswith("tok_")

    tenant = db_session.scalar(
        select(Tenant).where(Tenant.tenant_id == data["tenant_id"])
    )

    assert tenant is not None
    assert tenant.environment_name == "BC Sandbox"
    assert tenant.app_version == "0.4.0"