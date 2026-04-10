#!/usr/bin/env python3
"""
Verify pricing alignment without importing the full FastAPI stack:
- config/pricing_canonical.json (premium plan)
- landingpage/pricing-snapshot.js (__BCS_CANONICAL_BASE_EUR__ + marketing strings)
Optional: set PYTHONPATH=backend and run with deps to compare DEFAULT_LICENSE_PRICING import.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def main() -> int:
    canonical_path = REPO / "config" / "pricing_canonical.json"
    raw = json.loads(canonical_path.read_text(encoding="utf-8"))
    p = raw["plans"]["premium"]
    base = int(p["base_price_monthly"])

    snapshot_path = REPO / "landingpage" / "pricing-snapshot.js"
    if not snapshot_path.is_file():
        print("FAIL: landingpage/pricing-snapshot.js missing — run: python scripts/generate_landing_pricing.py")
        return 1
    snap_text = snapshot_path.read_text(encoding="utf-8")
    m = re.search(r"__BCS_CANONICAL_BASE_EUR__\s*=\s*(\d+)", snap_text)
    if not m or int(m.group(1)) != base:
        print("FAIL: pricing-snapshot.js base EUR does not match config/pricing_canonical.json")
        return 1

    marketing = raw.get("marketing", {})
    de_chip = marketing.get("format_de_chip", "Ab € {base} / Monat").format(base=base)
    if de_chip not in snap_text:
        print("FAIL: expected DE chip string not found in pricing-snapshot.js")
        return 1

    failures: list[str] = []
    try:
        sys.path.insert(0, str(REPO / "backend"))
        from app.services.pricing_service import (  # type: ignore  # noqa: E402
            CANONICAL_PRICING_JSON_PATH,
            DEFAULT_LICENSE_PRICING,
        )

        d = DEFAULT_LICENSE_PRICING["premium"]
        if float(d["base_price_monthly"]) != float(p["base_price_monthly"]):
            failures.append("DEFAULT_LICENSE_PRICING.premium.base != canonical")
        if int(d["included_records"]) != int(p["included_records"]):
            failures.append("included_records mismatch")
        if float(d["additional_price_per_1000_records"]) != float(p["additional_price_per_1000_records"]):
            failures.append("step price mismatch")
        if not CANONICAL_PRICING_JSON_PATH.is_file():
            failures.append("CANONICAL_PRICING_JSON_PATH missing at import")
    except ModuleNotFoundError as exc:
        print(f"Optional backend import skipped ({exc.name}). File-level checks passed.")
        print("pricing consistency OK (canonical + snapshot).")
        return 0

    if failures:
        print("Backend DEFAULT_LICENSE_PRICING check FAILED:")
        for row in failures:
            print(f"  - {row}")
        return 1

    print("pricing consistency OK: canonical JSON, landing snapshot, and DEFAULT_LICENSE_PRICING align.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
