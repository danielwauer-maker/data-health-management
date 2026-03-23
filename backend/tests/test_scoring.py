from app.services.scoring_service import calculate_quick_scan_result


def test_perfect_data_score():
    metrics = {
        "customers_total": 100,
        "vendors_total": 100,
        "items_total": 100,
    }

    score, checks_count, issues_count, summary, issues = calculate_quick_scan_result(metrics)

    assert score == 100
    assert checks_count == 20
    assert issues_count == 0
    assert summary.rating == "good"
    assert issues == []


def test_missing_customer_postcode():
    metrics = {
        "customers_total": 100,
        "customers_missing_postcode": 20,
        "vendors_total": 100,
        "items_total": 100,
    }

    score, checks_count, issues_count, summary, issues = calculate_quick_scan_result(metrics)

    assert score < 100
    assert issues_count == 1
    assert len(issues) == 1
    assert issues[0].affected_count == 20
    assert issues[0].code == "CUSTOMERS_MISSING_POSTCODE"


def test_multiple_issues_returns_all_issues_not_only_top_five():
    metrics = {
        "customers_total": 100,
        "customers_missing_postcode": 20,
        "customers_missing_payment_terms": 10,
        "customers_missing_country_code": 5,
        "customers_missing_vat_reg_no": 8,
        "customers_missing_email": 40,
        "vendors_total": 50,
        "vendors_missing_email": 10,
        "vendors_missing_phone_no": 5,
        "items_total": 80,
        "items_missing_category": 30,
    }

    score, checks_count, issues_count, summary, issues = calculate_quick_scan_result(metrics)

    assert score < 100
    assert issues_count == 8
    assert len(issues) == 8
    assert issues[0].affected_count >= issues[-1].affected_count
