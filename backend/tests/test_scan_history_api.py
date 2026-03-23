def test_scan_history_returns_latest_scans(client):
    register_response = client.post(
        "/tenant/register",
        json={
            "environment_name": "BC Sandbox",
            "app_version": "0.4.0",
        },
    )
    tenant_id = register_response.json()["tenant_id"]

    payload_1 = {
        "tenant_id": tenant_id,
        "metrics": {
            "customers_total": 100,
            "customers_missing_email": 20,
            "vendors_total": 50,
            "items_total": 80,
        },
    }

    payload_2 = {
        "tenant_id": tenant_id,
        "metrics": {
            "customers_total": 100,
            "customers_missing_email": 5,
            "vendors_total": 50,
            "items_total": 80,
        },
    }

    response_1 = client.post("/scan/quick", json=payload_1)
    response_2 = client.post("/scan/quick", json=payload_2)

    assert response_1.status_code == 200
    assert response_2.status_code == 200

    history_response = client.get(f"/scan/history/{tenant_id}")

    assert history_response.status_code == 200

    data = history_response.json()
    assert data["tenant_id"] == tenant_id
    assert len(data["scans"]) == 2

    latest_scan = data["scans"][0]
    older_scan = data["scans"][1]

    assert latest_scan["generated_at_utc"] >= older_scan["generated_at_utc"]
    assert "summary" in latest_scan
    assert isinstance(latest_scan["issues"], list)


def test_scan_history_returns_404_for_unknown_tenant(client):
    response = client.get("/scan/history/ten_unknown")

    assert response.status_code == 404
    assert response.json()["detail"] == "Tenant not found."