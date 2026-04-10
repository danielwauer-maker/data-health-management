from __future__ import annotations


# Product rule: deep_scan is available for free and premium.
# Premium unlocks additional action/detail features.
FEATURE_MATRIX: dict[tuple[str, str], tuple[str, ...]] = {
    ("free", "trial"): ("scan_sync", "quick_scan", "deep_scan", "billing_checkout"),
    ("free", "active"): ("scan_sync", "quick_scan", "deep_scan", "billing_checkout"),
    ("free", "blocked"): ("scan_sync", "quick_scan", "billing_checkout"),
    ("free", "expired"): ("scan_sync", "quick_scan", "billing_checkout"),
    (
        "premium",
        "trial",
    ): (
        "scan_sync",
        "quick_scan",
        "deep_scan",
        "advanced_checks",
        "recommendations",
        "record_drilldown",
        "correction_worklists",
        "analytics_full",
        "billing_checkout",
        "billing_portal",
    ),
    (
        "premium",
        "active",
    ): (
        "scan_sync",
        "quick_scan",
        "deep_scan",
        "advanced_checks",
        "recommendations",
        "record_drilldown",
        "correction_worklists",
        "analytics_full",
        "billing_checkout",
        "billing_portal",
    ),
    ("premium", "blocked"): (
        "scan_sync",
        "quick_scan",
        "billing_checkout",
        "billing_portal",
    ),
    ("premium", "expired"): (
        "scan_sync",
        "quick_scan",
        "billing_checkout",
        "billing_portal",
    ),
}

FALLBACK_FEATURES: tuple[str, ...] = ("scan_sync", "quick_scan", "billing_checkout")
PREMIUM_ACTION_FEATURES: frozenset[str] = frozenset(
    {
        # analytics_full is treated as premium detail access because the full
        # analytics experience exposes premium findings/trends beyond the shared deep-scan basis.
        "recommendations",
        "record_drilldown",
        "correction_worklists",
        "analytics_full",
    }
)


def resolve_features(plan: str, license_status: str) -> list[str]:
    normalized_plan = (plan or "free").strip().lower()
    normalized_license_status = (license_status or "trial").strip().lower()
    return list(FEATURE_MATRIX.get((normalized_plan, normalized_license_status), FALLBACK_FEATURES))


def is_premium_actions_enabled(features: list[str] | tuple[str, ...] | set[str] | None) -> bool:
    normalized_features = {
        str(feature).strip().lower()
        for feature in (features or [])
        if str(feature).strip()
    }
    return bool(normalized_features.intersection(PREMIUM_ACTION_FEATURES))
