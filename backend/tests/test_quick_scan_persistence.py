from sqlalchemy import select

from app.models import Scan, ScanIssueRecord


def test_quick_scan_persists_scan_and_issues(client, db_session):
    register_response = client.post(
        "/tenant/register",
        json={
            "environment_name": "BC Sandbox",
            "app_version": "0.4.0",
        },
    )
    tenant_id = register_response.json()["tenant_id"]

    scan_payload = {
        "tenant_id": tenant_id,
        "metrics": {
            "customers_total": 100,
            "customers_missing_postcode": 5,
            "customers_missing_email": 12,
            "vendors_total": 50,
            "vendors_missing_email": 4,
            "items_total": 80,
            "items_missing_category": 10,
        },
    }

    response = client.post("/scan/quick", json=scan_payload)

    assert response.status_code == 200

    data = response.json()
    scan_id = data["scan_id"]

    scan = db_session.scalar(
        select(Scan).where(Scan.scan_id == scan_id)
    )

    assert scan is not None
    assert scan.tenant_id == tenant_id
    assert scan.scan_type == "quick"
    assert scan.data_score == data["data_score"]
    assert scan.checks_count == data["checks_count"]
    assert scan.issues_count == data["issues_count"]

    issues = db_session.scalars(
        select(ScanIssueRecord).where(ScanIssueRecord.scan_id == scan_id)
    ).all()

    assert len(issues) == data["issues_count"]
    assert len(issues) > 0