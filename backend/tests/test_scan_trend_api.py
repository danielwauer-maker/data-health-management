def test_scan_trend_returns_delta_and_direction(client):
    register_response = client.post(
        "/tenant/register",
        json={
            "environment_name": "BC Sandbox",
            "app_version": "0.4.0",
        },
    )
    tenant_id = register_response.json()["tenant_id"]

    client.post(
        "/scan/quick",
        json={
            "tenant_id": tenant_id,
            "metrics": {
                "customers_total": 100,
                "customers_missing_email": 20,
                "vendors_total": 50,
                "items_total": 80,
            },
        },
    )

    client.post(
        "/scan/quick",
        json={
            "tenant_id": tenant_id,
            "metrics": {
                "customers_total": 100,
                "customers_missing_email": 5,
                "vendors_total": 50,
                "items_total": 80,
            },
        },
    )

    response = client.get(f"/scan/trend/{tenant_id}")

    assert response.status_code == 200

    data = response.json()
    assert data["tenant_id"] == tenant_id
    assert data["latest_score"] is not None
    assert data["previous_score"] is not None
    assert data["delta"] is not None
    assert data["trend"] in ["up", "down", "same"]


def test_scan_trend_with_single_scan_returns_same(client):
    register_response = client.post(
        "/tenant/register",
        json={
            "environment_name": "BC Sandbox",
            "app_version": "0.4.0",
        },
    )
    tenant_id = register_response.json()["tenant_id"]

    client.post(
        "/scan/quick",
        json={
            "tenant_id": tenant_id,
            "metrics": {
                "customers_total": 100,
                "vendors_total": 50,
                "items_total": 80,
            },
        },
    )

    response = client.get(f"/scan/trend/{tenant_id}")

    assert response.status_code == 200

    data = response.json()
    assert data["tenant_id"] == tenant_id
    assert data["latest_score"] is not None
    assert data["previous_score"] is None
    assert data["delta"] is None
    assert data["trend"] == "same"
