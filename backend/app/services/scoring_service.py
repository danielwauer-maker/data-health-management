from dataclasses import dataclass
from typing import Dict, List, Tuple

from app.schemas.scan import ScanIssue, ScanSummary
from app.services.cost_service import calculate_issue_impact_eur, calculate_scan_cost_summary, CostedIssue


@dataclass(frozen=True)
class QuickCheckDefinition:
    metric_key: str
    total_key: str
    code: str
    title: str
    recommendation_preview: str
    points_minor: int
    points_major: int
    premium_only: bool = False


QUICK_CHECKS: List[QuickCheckDefinition] = [
    QuickCheckDefinition(
        metric_key="customers_missing_postcode",
        total_key="customers_total",
        code="CUSTOMERS_MISSING_POSTCODE",
        title="Kunden ohne Postleitzahl",
        recommendation_preview="Adressdaten der betroffenen Debitoren vervollständigen.",
        points_minor=4,
        points_major=8,
    ),
    QuickCheckDefinition(
        metric_key="customers_missing_payment_terms",
        total_key="customers_total",
        code="CUSTOMERS_MISSING_PAYMENT_TERMS",
        title="Kunden ohne Zahlungsbedingung",
        recommendation_preview="Zahlungsbedingungen bei betroffenen Debitoren pflegen.",
        points_minor=6,
        points_major=12,
    ),
    QuickCheckDefinition(
        metric_key="customers_missing_country_code",
        total_key="customers_total",
        code="CUSTOMERS_MISSING_COUNTRY_CODE",
        title="Kunden ohne Länder-/Regionscode",
        recommendation_preview="Länder-/Regionscode für betroffene Debitoren pflegen.",
        points_minor=4,
        points_major=8,
    ),
    QuickCheckDefinition(
        metric_key="customers_missing_vat_reg_no",
        total_key="customers_total",
        code="CUSTOMERS_MISSING_VAT_REG_NO",
        title="Kunden ohne USt-IdNr.",
        recommendation_preview="USt-IdNr. für betroffene Debitoren prüfen und ergänzen.",
        points_minor=5,
        points_major=10,
    ),
    QuickCheckDefinition(
        metric_key="customers_missing_email",
        total_key="customers_total",
        code="CUSTOMERS_MISSING_EMAIL",
        title="Kunden ohne E-Mail",
        recommendation_preview="E-Mail-Adressen für betroffene Debitoren ergänzen.",
        points_minor=3,
        points_major=6,
    ),
    QuickCheckDefinition(
        metric_key="customers_missing_phone_no",
        total_key="customers_total",
        code="CUSTOMERS_MISSING_PHONE_NO",
        title="Kunden ohne Telefonnummer",
        recommendation_preview="Telefonnummern für betroffene Debitoren pflegen.",
        points_minor=2,
        points_major=5,
    ),
    QuickCheckDefinition(
        metric_key="customers_missing_customer_posting_group",
        total_key="customers_total",
        code="CUSTOMERS_MISSING_CUSTOMER_POSTING_GROUP",
        title="Kunden ohne Debitorenbuchungsgruppe",
        recommendation_preview="Debitorenbuchungsgruppen für betroffene Debitoren pflegen.",
        points_minor=6,
        points_major=12,
    ),
    QuickCheckDefinition(
        metric_key="customers_missing_gen_bus_posting_group",
        total_key="customers_total",
        code="CUSTOMERS_MISSING_GEN_BUS_POSTING_GROUP",
        title="Kunden ohne Geschäftsbuchungsgruppe",
        recommendation_preview="Geschäftsbuchungsgruppen für betroffene Debitoren pflegen.",
        points_minor=5,
        points_major=10,
    ),
    QuickCheckDefinition(
        metric_key="vendors_missing_payment_terms",
        total_key="vendors_total",
        code="VENDORS_MISSING_PAYMENT_TERMS",
        title="Lieferanten ohne Zahlungsbedingung",
        recommendation_preview="Zahlungsbedingungen bei betroffenen Kreditoren pflegen.",
        points_minor=5,
        points_major=10,
    ),
    QuickCheckDefinition(
        metric_key="vendors_missing_country_code",
        total_key="vendors_total",
        code="VENDORS_MISSING_COUNTRY_CODE",
        title="Lieferanten ohne Länder-/Regionscode",
        recommendation_preview="Länder-/Regionscode für betroffene Kreditoren pflegen.",
        points_minor=4,
        points_major=8,
    ),
    QuickCheckDefinition(
        metric_key="vendors_missing_email",
        total_key="vendors_total",
        code="VENDORS_MISSING_EMAIL",
        title="Lieferanten ohne E-Mail",
        recommendation_preview="E-Mail-Adressen für betroffene Kreditoren ergänzen.",
        points_minor=3,
        points_major=6,
    ),
    QuickCheckDefinition(
        metric_key="vendors_missing_phone_no",
        total_key="vendors_total",
        code="VENDORS_MISSING_PHONE_NO",
        title="Lieferanten ohne Telefonnummer",
        recommendation_preview="Telefonnummern für betroffene Kreditoren pflegen.",
        points_minor=2,
        points_major=5,
    ),
    QuickCheckDefinition(
        metric_key="vendors_missing_vendor_posting_group",
        total_key="vendors_total",
        code="VENDORS_MISSING_VENDOR_POSTING_GROUP",
        title="Lieferanten ohne Kreditorenbuchungsgruppe",
        recommendation_preview="Kreditorenbuchungsgruppen für betroffene Kreditoren pflegen.",
        points_minor=6,
        points_major=12,
    ),
    QuickCheckDefinition(
        metric_key="vendors_missing_gen_bus_posting_group",
        total_key="vendors_total",
        code="VENDORS_MISSING_GEN_BUS_POSTING_GROUP",
        title="Lieferanten ohne Geschäftsbuchungsgruppe",
        recommendation_preview="Geschäftsbuchungsgruppen für betroffene Kreditoren pflegen.",
        points_minor=5,
        points_major=10,
    ),
    QuickCheckDefinition(
        metric_key="items_missing_category",
        total_key="items_total",
        code="ITEMS_MISSING_CATEGORY",
        title="Artikel ohne Kategorie",
        recommendation_preview="Artikelkategorien für betroffene Artikel ergänzen.",
        points_minor=8,
        points_major=15,
    ),
    QuickCheckDefinition(
        metric_key="items_missing_base_unit",
        total_key="items_total",
        code="ITEMS_MISSING_BASE_UNIT",
        title="Artikel ohne Basiseinheit",
        recommendation_preview="Basiseinheit für betroffene Artikel ergänzen.",
        points_minor=6,
        points_major=12,
    ),
    QuickCheckDefinition(
        metric_key="items_missing_gen_prod_posting_group",
        total_key="items_total",
        code="ITEMS_MISSING_GEN_PROD_POSTING_GROUP",
        title="Artikel ohne Produktbuchungsgruppe",
        recommendation_preview="Produktbuchungsgruppen für betroffene Artikel pflegen.",
        points_minor=6,
        points_major=12,
    ),
    QuickCheckDefinition(
        metric_key="items_missing_inventory_posting_group",
        total_key="items_total",
        code="ITEMS_MISSING_INVENTORY_POSTING_GROUP",
        title="Artikel ohne Lagerbuchungsgruppe",
        recommendation_preview="Lagerbuchungsgruppen für betroffene Artikel pflegen.",
        points_minor=6,
        points_major=12,
    ),
    QuickCheckDefinition(
        metric_key="items_missing_vat_prod_posting_group",
        total_key="items_total",
        code="ITEMS_MISSING_VAT_PROD_POSTING_GROUP",
        title="Artikel ohne MwSt.-Produktbuchungsgruppe",
        recommendation_preview="MwSt.-Produktbuchungsgruppen für betroffene Artikel pflegen.",
        points_minor=5,
        points_major=10,
    ),
    QuickCheckDefinition(
        metric_key="items_missing_vendor_no",
        total_key="items_total",
        code="ITEMS_MISSING_VENDOR_NO",
        title="Artikel ohne Kreditorennr.",
        recommendation_preview="Standard-Kreditor für betroffene Artikel prüfen und ergänzen.",
        points_minor=2,
        points_major=5,
    ),
]


def _safe_int(value: object) -> int:
    try:
        return int(value or 0)
    except (TypeError, ValueError):
        return 0


def _safe_ratio(numerator: int, denominator: int) -> float:
    if denominator <= 0:
        return 0.0
    return numerator / denominator


def _severity_from_ratio(ratio: float) -> str:
    if ratio >= 0.15:
        return "high"
    if ratio >= 0.05:
        return "medium"
    return "low"


def _deduction_from_ratio(ratio: float, points_minor: int, points_major: int) -> int:
    if ratio >= 0.15:
        return points_major
    if ratio > 0.0:
        return points_minor
    return 0


def _build_summary(score: int) -> ScanSummary:
    if score >= 90:
        return ScanSummary(
            headline="Gute Datenqualität mit einzelnen Lücken",
            rating="good",
        )
    if score >= 75:
        return ScanSummary(
            headline="Ordentliche Datenqualität mit erkennbarem Verbesserungsbedarf",
            rating="fair",
        )
    return ScanSummary(
        headline="Erhöhter Handlungsbedarf bei der Datenqualität",
        rating="critical",
    )


def calculate_quick_scan_result(
    metrics: Dict[str, int],
) -> Tuple[int, int, int, ScanSummary, List[ScanIssue], float, float]:
    score = 100
    all_issues: List[ScanIssue] = []

    for check in QUICK_CHECKS:
        affected_count = _safe_int(metrics.get(check.metric_key, 0))
        total_count = _safe_int(metrics.get(check.total_key, 0))
        ratio = _safe_ratio(affected_count, total_count)

        score -= _deduction_from_ratio(
            ratio=ratio,
            points_minor=check.points_minor,
            points_major=check.points_major,
        )

        if affected_count > 0:
            all_issues.append(
                ScanIssue(
                    code=check.code,
                    title=check.title,
                    severity=_severity_from_ratio(ratio),
                    affected_count=affected_count,
                    premium_only=check.premium_only,
                    recommendation_preview=check.recommendation_preview,
                    estimated_impact_eur=calculate_issue_impact_eur(check.code, affected_count),
                )
            )

    score = max(score, 0)
    all_issues.sort(key=lambda issue: issue.estimated_impact_eur, reverse=True)

    checks_count = len(QUICK_CHECKS)
    issues_count = len(all_issues)
    summary = _build_summary(score)
    cost_summary = calculate_scan_cost_summary(
        CostedIssue(code=issue.code, affected_count=issue.affected_count)
        for issue in all_issues
    )

    return (
        score,
        checks_count,
        issues_count,
        summary,
        all_issues,
        cost_summary.estimated_loss_eur,
        cost_summary.potential_saving_eur,
    )
