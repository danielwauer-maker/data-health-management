from app.services.entitlement_service import is_premium_actions_enabled, resolve_features


def test_entitlement_matrix_covers_required_states():
    cases = [
        ("free", "trial", {"scan_sync", "quick_scan", "deep_scan", "billing_checkout"}, False),
        ("free", "active", {"scan_sync", "quick_scan", "deep_scan", "billing_checkout"}, False),
        (
            "premium",
            "trial",
            {
                "scan_sync",
                "quick_scan",
                "deep_scan",
                "analytics_full",
                "recommendations",
                "record_drilldown",
                "billing_checkout",
                "billing_portal",
            },
            True,
        ),
        (
            "premium",
            "active",
            {
                "scan_sync",
                "quick_scan",
                "deep_scan",
                "analytics_full",
                "recommendations",
                "record_drilldown",
                "billing_checkout",
                "billing_portal",
            },
            True,
        ),
        ("premium", "expired", {"scan_sync", "quick_scan", "billing_checkout", "billing_portal"}, False),
        ("premium", "blocked", {"scan_sync", "quick_scan", "billing_checkout", "billing_portal"}, False),
    ]

    for plan, status, expected_features, premium_enabled in cases:
        features = set(resolve_features(plan, status))
        assert expected_features.issubset(features)
        assert is_premium_actions_enabled(features) is premium_enabled

