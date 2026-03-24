codeunit 53153 "DH Cost Mgt."
{
    procedure GetIssueImpact(IssueCode: Code[50]; AffectedCount: Integer): Decimal
    var
        CostPerIssue: Decimal;
    begin
        if AffectedCount <= 0 then
            exit(0);

        CostPerIssue := GetCostPerIssue(IssueCode);
        exit(Round(CostPerIssue * AffectedCount, 0.01, '='));
    end;

    procedure GetCostPerIssue(IssueCode: Code[50]): Decimal
    var
        NormalizedCode: Text;
    begin
        NormalizedCode := UpperCase(Format(IssueCode));

        case NormalizedCode of
            'CUSTOMERS_MISSING_NAME',
            'VENDORS_MISSING_NAME':
                exit(35);
            'CUSTOMERS_MISSING_SEARCH_NAME',
            'VENDORS_MISSING_SEARCH_NAME':
                exit(10);
            'CUSTOMERS_MISSING_ADDRESS',
            'VENDORS_MISSING_ADDRESS':
                exit(15);
            'CUSTOMERS_MISSING_CITY',
            'VENDORS_MISSING_CITY',
            'CUSTOMERS_MISSING_POST_CODE',
            'VENDORS_MISSING_POST_CODE',
            'CUSTOMERS_MISSING_POSTCODE':
                exit(12);
            'CUSTOMERS_MISSING_COUNTRY',
            'VENDORS_MISSING_COUNTRY',
            'CUSTOMERS_MISSING_COUNTRY_CODE',
            'VENDORS_MISSING_COUNTRY_CODE':
                exit(10);
            'CUSTOMERS_MISSING_VAT_REG_NO':
                exit(35);
            'CUSTOMERS_MISSING_EMAIL',
            'VENDORS_MISSING_EMAIL',
            'CUSTOMERS_DUPLICATE_EMAIL',
            'VENDORS_DUPLICATE_EMAIL':
                if StrPos(NormalizedCode, 'DUPLICATE') > 0 then
                    exit(140)
                else
                    exit(8);
            'CUSTOMERS_MISSING_PHONE',
            'VENDORS_MISSING_PHONE',
            'CUSTOMERS_MISSING_PHONE_NO',
            'VENDORS_MISSING_PHONE_NO':
                exit(6);
            'CUSTOMERS_MISSING_PAYMENT_TERMS':
                exit(45);
            'VENDORS_MISSING_PAYMENT_TERMS':
                exit(40);
            'CUSTOMERS_MISSING_PAYMENT_METHOD',
            'VENDORS_MISSING_PAYMENT_METHOD':
                exit(30);
            'CUSTOMERS_MISSING_POSTING_GROUP',
            'CUSTOMERS_MISSING_CUSTOMER_POSTING_GROUP',
            'VENDORS_MISSING_POSTING_GROUP',
            'VENDORS_MISSING_VENDOR_POSTING_GROUP':
                exit(55);
            'CUSTOMERS_MISSING_GEN_BUS_POSTING',
            'CUSTOMERS_MISSING_GEN_BUS_POSTING_GROUP',
            'CUSTOMERS_MISSING_VAT_BUS_POSTING',
            'VENDORS_MISSING_GEN_BUS_POSTING',
            'VENDORS_MISSING_GEN_BUS_POSTING_GROUP',
            'VENDORS_MISSING_VAT_BUS_POSTING',
            'ITEMS_MISSING_GEN_PROD_POSTING',
            'ITEMS_MISSING_GEN_PROD_POSTING_GROUP',
            'ITEMS_MISSING_INVENTORY_POSTING',
            'ITEMS_MISSING_INVENTORY_POSTING_GROUP':
                exit(55);
            'CUSTOMERS_MISSING_CREDIT_LIMIT':
                exit(20);
            'VENDORS_MISSING_BANK_ACCOUNT':
                exit(90);
            'BLOCKED_CUSTOMERS_WITH_OPEN_SALES_DOCS',
            'BLOCKED_VENDORS_WITH_OPEN_PURCHASE_DOCS':
                exit(120);
            'BLOCKED_CUSTOMERS_WITH_OPEN_LEDGER',
            'BLOCKED_VENDORS_WITH_OPEN_LEDGER':
                exit(150);
            'CUSTOMERS_DUPLICATE_VAT',
            'VENDORS_DUPLICATE_VAT':
                exit(220);
            'CUSTOMERS_DUPLICATE_NAME_POST_CITY':
                exit(160);
            'VENDORS_DUPLICATE_NAME_POST_CITY':
                exit(140);
            'ITEMS_MISSING_DESCRIPTION':
                exit(12);
            'ITEMS_MISSING_BASE_UOM',
            'ITEMS_MISSING_BASE_UNIT':
                exit(30);
            'ITEMS_MISSING_CATEGORY':
                exit(20);
            'ITEMS_MISSING_VAT_PROD_POSTING_GROUP':
                exit(45);
            'ITEMS_WITHOUT_VENDOR_NO',
            'ITEMS_MISSING_VENDOR_NO':
                exit(18);
            'ITEMS_WITHOUT_UNIT_COST':
                exit(95);
            'ITEMS_WITHOUT_UNIT_PRICE':
                exit(110);
            'ITEMS_NEGATIVE_INVENTORY':
                exit(150);
            'BLOCKED_ITEMS_WITH_INVENTORY':
                exit(130);
            'SALES_ORDERS_MISSING_SHIPMENT_DATE':
                exit(40);
            'SALES_ORDERS_OLD_OPEN',
            'PURCHASE_ORDERS_OLD_OPEN':
                exit(70);
            'SALES_LINES_MISSING_NO',
            'PURCHASE_LINES_MISSING_NO':
                exit(80);
            'SALES_LINES_ZERO_QUANTITY',
            'PURCHASE_LINES_ZERO_QUANTITY':
                exit(60);
            'SALES_LINES_ZERO_PRICE':
                exit(140);
            'PURCHASE_LINES_ZERO_COST':
                exit(120);
            'SALES_LINES_MISSING_DIMENSIONS',
            'PURCHASE_LINES_MISSING_DIMENSIONS':
                exit(35);
            'SALES_DOCS_WITH_BLOCKED_CUSTOMERS',
            'PURCHASE_DOCS_WITH_BLOCKED_VENDORS':
                exit(120);
            'SALES_LINES_WITH_BLOCKED_ITEMS',
            'PURCHASE_LINES_WITH_BLOCKED_ITEMS':
                exit(130);
            'PURCHASE_ORDERS_MISSING_EXPECTED_DATE':
                exit(35);
            'CUSTOMER_LEDGER_OVERDUE_30',
            'VENDOR_LEDGER_OVERDUE_30':
                exit(90);
        end;

        if StrPos(NormalizedCode, 'DUPLICATE') > 0 then
            exit(150);
        if (StrPos(NormalizedCode, 'ZERO_PRICE') > 0) or (StrPos(NormalizedCode, 'WITHOUT_UNIT_PRICE') > 0) then
            exit(120);
        if (StrPos(NormalizedCode, 'ZERO_COST') > 0) or (StrPos(NormalizedCode, 'WITHOUT_UNIT_COST') > 0) then
            exit(100);
        if (StrPos(NormalizedCode, 'NEGATIVE_INVENTORY') > 0) or (StrPos(NormalizedCode, 'BLOCKED_') > 0) then
            exit(130);
        if (StrPos(NormalizedCode, 'PAYMENT') > 0) or (StrPos(NormalizedCode, 'POSTING') > 0) then
            exit(45);
        if StrPos(NormalizedCode, 'EMAIL') > 0 then
            exit(8);
        if StrPos(NormalizedCode, 'PHONE') > 0 then
            exit(6);
        if (StrPos(NormalizedCode, 'ADDRESS') > 0) or (StrPos(NormalizedCode, 'POST_CODE') > 0) or (StrPos(NormalizedCode, 'POSTCODE') > 0) then
            exit(12);

        exit(25);
    end;
}
