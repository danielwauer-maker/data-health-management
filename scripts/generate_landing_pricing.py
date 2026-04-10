#!/usr/bin/env python3
"""
Generate landingpage pricing-snapshot.js from config/pricing_canonical.json.
Run from repo root: python scripts/generate_landing_pricing.py
Also syncs pricing_premium_chip in landingpage/lang/*.json for consumers of static JSON.
"""
from __future__ import annotations

import json
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CANONICAL = REPO / "config" / "pricing_canonical.json"
OUT_PATHS = [
    REPO / "landingpage" / "pricing-snapshot.js",
    REPO / "landingpage" / "live" / "pricing-snapshot.js",
]
LANG_FILES = [
    REPO / "landingpage" / "lang" / "en.json",
    REPO / "landingpage" / "lang" / "de.json",
    REPO / "landingpage" / "live" / "lang" / "en.json",
    REPO / "landingpage" / "live" / "lang" / "de.json",
]


def main() -> int:
    data = json.loads(CANONICAL.read_text(encoding="utf-8"))
    premium = data["plans"]["premium"]
    base = int(premium["base_price_monthly"])
    marketing = data.get("marketing", {})

    de_plan = marketing.get("format_de_plan_price", "Ab € {base}").format(base=base)
    en_plan = marketing.get("format_en_plan_price", "From € {base}").format(base=base)
    de_chip = marketing.get("format_de_chip", "Ab € {base} / Monat").format(base=base)
    en_chip = marketing.get("format_en_chip", "From € {base} / month").format(base=base)

    payload = {
        "de": {"plan_premium_price": de_plan, "pricing_premium_chip": de_chip},
        "en": {"plan_premium_price": en_plan, "pricing_premium_chip": en_chip},
    }

    js_lines = [
        "/* AUTO-GENERATED — do not edit. Source: config/pricing_canonical.json */",
        "/* Regenerate: python scripts/generate_landing_pricing.py */",
        "window.__BCS_MARKETING_STRINGS__ = "
        + json.dumps(payload, ensure_ascii=False, indent=2)
        + ";",
        f"window.__BCS_CANONICAL_BASE_EUR__ = {base};",
        "",
    ]
    body = "\n".join(js_lines)

    for out in OUT_PATHS:
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(body, encoding="utf-8")
        print(f"Wrote {out.relative_to(REPO)}")

    for lang_path in LANG_FILES:
        lang_data = json.loads(lang_path.read_text(encoding="utf-8"))
        if lang_path.name == "de.json":
            lang_data["pricing_premium_chip"] = de_chip
        else:
            lang_data["pricing_premium_chip"] = en_chip
        lang_path.write_text(json.dumps(lang_data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"Synced pricing_premium_chip in {lang_path.relative_to(REPO)}")

    print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
