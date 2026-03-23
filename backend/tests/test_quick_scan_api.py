def test_quick_scan_endpoint(client):
    register_response = client.post(
        "/tenant/register",
        json={
            "environment_name": "BC Sandbox",
            "app_version": "0.4.0",
        },
    )

    assert register_response.status_code == 200
    tenant_id = register_response.json()["tenant_id"]

    payload = {
        "tenant_id": tenant_id,
        "metrics": {
            "customers_total": 100,
            "customers_missing_email": 10,
            "vendors_total": 50,
            "items_total": 80,
        },
    }

    response = client.post("/scan/quick", json=payload)

    assert response.status_code == 200

    data = response.json()

    assert "scan_id" in data
    assert data["scan_type"] == "quick"
    assert "data_score" in data
    assert "checks_count" in data
    assert "issues_count" in data
    assert "summary" in data
    assert isinstance(data["issues"], list)
