from app.db import SessionLocal
from app.models import Scan


def test_reconcile_keeps_requested_scans_and_preserves_other_tenants(
    client,
    tenant_factory,
    auth_header_factory,
    scan_factory,
):
    tenant_one = tenant_factory(plan="free", license_status="trial")
    tenant_two = tenant_factory(plan="free", license_status="trial")
    scan_factory(tenant_id=tenant_one["tenant_id"], scan_id="scan_keep")
    scan_factory(tenant_id=tenant_one["tenant_id"], scan_id="scan_delete")
    scan_factory(tenant_id=tenant_two["tenant_id"], scan_id="scan_other_tenant")

    response = client.post(
        "/scan/reconcile",
        headers=auth_header_factory(tenant_one),
        json={"tenant_id": tenant_one["tenant_id"], "scan_ids": ["scan_keep"]},
    )

    assert response.status_code == 200
    assert response.json()["deleted_scan_ids"] == ["scan_delete"]

    with SessionLocal() as db:
        remaining = {row.scan_id for row in db.query(Scan).all()}
        assert remaining == {"scan_keep", "scan_other_tenant"}


def test_reconcile_with_empty_list_deletes_only_current_tenant_scans(
    client,
    tenant_factory,
    auth_header_factory,
    scan_factory,
):
    tenant_one = tenant_factory(plan="free", license_status="trial")
    tenant_two = tenant_factory(plan="free", license_status="trial")
    scan_factory(tenant_id=tenant_one["tenant_id"], scan_id="scan_1")
    scan_factory(tenant_id=tenant_one["tenant_id"], scan_id="scan_2")
    scan_factory(tenant_id=tenant_two["tenant_id"], scan_id="scan_3")

    response = client.post(
        "/scan/reconcile",
        headers=auth_header_factory(tenant_one),
        json={"tenant_id": tenant_one["tenant_id"], "scan_ids": []},
    )

    assert response.status_code == 200
    assert set(response.json()["deleted_scan_ids"]) == {"scan_1", "scan_2"}

    with SessionLocal() as db:
        remaining = {row.scan_id for row in db.query(Scan).all()}
        assert remaining == {"scan_3"}
