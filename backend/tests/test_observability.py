from __future__ import annotations

import logging

import app.main as app_main
from fastapi.testclient import TestClient


def test_unhandled_error_logs_request_id(caplog, monkeypatch):
    def boom():
        raise RuntimeError("boom")

    monkeypatch.setattr(app_main, "wait_for_database", lambda: None)
    monkeypatch.setattr(app_main, "ensure_schema_is_migrated", lambda: None)
    app_main.app.add_api_route("/__test/error", boom, methods=["GET"])

    try:
        with TestClient(app_main.app, raise_server_exceptions=False) as client:
            with caplog.at_level(logging.ERROR):
                response = client.get("/__test/error", headers={"X-Request-Id": "req-test-123"})
    finally:
        app_main.app.router.routes.pop()

    assert response.status_code == 500

    matching = [
        record for record in caplog.records
        if record.name == "app.main" and getattr(record, "event", None) == "unhandled_exception"
    ]
    assert matching
    assert any(getattr(record, "request_id", None) == "req-test-123" for record in matching)


def test_validation_logging_redacts_payload_values(client, caplog):
    with caplog.at_level(logging.WARNING):
        response = client.post(
            "/tenant/register",
            json={"environment_name": 123, "app_version": {"secret": "should-not-appear"}},
        )

    assert response.status_code == 422

    matching = [
        record for record in caplog.records
        if record.name == "app.main" and getattr(record, "event", None) == "request_validation_error"
    ]
    assert matching

    logged_errors = matching[-1].__dict__.get("errors")
    assert isinstance(logged_errors, list)
    assert logged_errors
    assert all("input" not in error for error in logged_errors)
    assert all("ctx" not in error for error in logged_errors)
    assert "should-not-appear" not in str(logged_errors)
