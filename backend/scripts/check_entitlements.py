from __future__ import annotations

from app.services.entitlement_service import resolve_features


EXPECTED_MATRIX: dict[tuple[str, str], set[str]] = {
    ("free", "trial"): {"scan_sync", "quick_scan", "billing_checkout"},
    ("free", "active"): {"scan_sync", "quick_scan", "billing_checkout"},
    ("free", "blocked"): {"scan_sync", "quick_scan", "billing_checkout"},
    ("free", "expired"): {"scan_sync", "quick_scan", "billing_checkout"},
    (
        "premium",
        "trial",
    ): {
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
    },
    (
        "premium",
        "active",
    ): {
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
    },
    ("premium", "blocked"): {
        "scan_sync",
        "quick_scan",
        "billing_checkout",
        "billing_portal",
    },
    ("premium", "expired"): {
        "scan_sync",
        "quick_scan",
        "billing_checkout",
        "billing_portal",
    },
}


def main() -> int:
    failures: list[str] = []
    for key, expected in EXPECTED_MATRIX.items():
        plan, status = key
        actual = set(resolve_features(plan, status))
        if actual != expected:
            failures.append(
                f"{plan}/{status}: expected={sorted(expected)} actual={sorted(actual)}"
            )

    if failures:
        print("Entitlement matrix check FAILED:")
        for row in failures:
            print(f" - {row}")
        return 1

    print(f"Entitlement matrix check OK ({len(EXPECTED_MATRIX)} states validated).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
