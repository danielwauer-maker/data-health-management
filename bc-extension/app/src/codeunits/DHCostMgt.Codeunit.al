codeunit 53153 "DH Cost Mgt."
{
    procedure GetIssueImpact(IssueCode: Code[50]; AffectedCount: Integer): Decimal
    var
        MinutesPerOccurrence: Decimal;
        Probability: Decimal;
        FrequencyPerYear: Decimal;
        HourlyRate: Decimal;
        ImpactPerRecord: Decimal;
    begin
        if AffectedCount <= 0 then
            exit(0);

        HourlyRate := GetDefaultHourlyRate();
        LoadImpactDefinition(IssueCode, MinutesPerOccurrence, Probability, FrequencyPerYear);

        ImpactPerRecord := (MinutesPerOccurrence / 60) * Probability * FrequencyPerYear * HourlyRate;
        exit(Round(ImpactPerRecord * AffectedCount, 0.01, '='));
    end;

    procedure GetDefaultHourlyRate(): Decimal
    begin
        exit(50);
    end;

    procedure GetPotentialSavingFactor(): Decimal
    begin
        exit(0.7);
    end;

    procedure CalculatePotentialSaving(EstimatedLoss: Decimal): Decimal
    begin
        if EstimatedLoss <= 0 then
            exit(0);

        exit(Round(EstimatedLoss * GetPotentialSavingFactor(), 0.01, '='));
    end;

    local procedure LoadImpactDefinition(IssueCode: Code[50]; var MinutesPerOccurrence: Decimal; var Probability: Decimal; var FrequencyPerYear: Decimal)
    var
        NormalizedCode: Text;
    begin
        NormalizedCode := UpperCase(Format(IssueCode));

        case NormalizedCode of
            'BLOCKED_CUSTOMERS_WITH_OPEN_LEDGER',
            'BLOCKED_VENDORS_WITH_OPEN_LEDGER':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 22, 0.60, 12);
            'BLOCKED_CUSTOMERS_WITH_OPEN_SALES_DOCS',
            'BLOCKED_VENDORS_WITH_OPEN_PURCHASE_DOCS':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 18, 0.50, 12);
            'BLOCKED_ITEMS_WITH_INVENTORY',
            'PURCHASE_LINES_WITH_BLOCKED_ITEMS',
            'SALES_LINES_WITH_BLOCKED_ITEMS':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 14, 0.50, 12);
            'CUSTOMERS_DUPLICATE_EMAIL',
            'VENDORS_DUPLICATE_EMAIL':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 18, 0.25, 12);
            'CUSTOMERS_DUPLICATE_NAME_POST_CITY',
            'VENDORS_DUPLICATE_NAME_POST_CITY',
            'CUSTOMERS_DUPLICATE_NAME_POST_CODE_CITY',
            'VENDORS_DUPLICATE_NAME_POST_CODE_CITY':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 25, 0.25, 12);
            'CUSTOMERS_DUPLICATE_VAT',
            'VENDORS_DUPLICATE_VAT':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 30, 0.35, 12);
            'CUSTOMERS_MISSING_ADDRESS',
            'VENDORS_MISSING_ADDRESS':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 6, 0.35, 8);
            'CUSTOMERS_MISSING_CITY',
            'VENDORS_MISSING_CITY':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 4, 0.25, 8);
            'CUSTOMERS_MISSING_COUNTRY',
            'CUSTOMERS_MISSING_COUNTRY_CODE',
            'VENDORS_MISSING_COUNTRY',
            'VENDORS_MISSING_COUNTRY_CODE':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 4, 0.20, 8);
            'CUSTOMERS_MISSING_CUSTOMER_POSTING_GROUP',
            'CUSTOMERS_MISSING_POSTING_GROUP',
            'VENDORS_MISSING_VENDOR_POSTING_GROUP',
            'VENDORS_MISSING_POSTING_GROUP':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 12, 0.45, 12);
            'CUSTOMERS_MISSING_EMAIL',
            'VENDORS_MISSING_EMAIL':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 3, 0.30, 12);
            'CUSTOMERS_MISSING_GEN_BUS_POSTING',
            'CUSTOMERS_MISSING_GEN_BUS_POSTING_GROUP',
            'VENDORS_MISSING_GEN_BUS_POSTING',
            'VENDORS_MISSING_GEN_BUS_POSTING_GROUP':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 10, 0.40, 12);
            'CUSTOMERS_MISSING_NAME',
            'VENDORS_MISSING_NAME':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 8, 0.60, 12);
            'CUSTOMERS_MISSING_PAYMENT_METHOD':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 7, 0.30, 12);
            'VENDORS_MISSING_PAYMENT_METHOD':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 7, 0.28, 12);
            'CUSTOMERS_MISSING_PAYMENT_TERMS':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 10, 0.30, 12);
            'VENDORS_MISSING_PAYMENT_TERMS':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 9, 0.30, 12);
            'CUSTOMERS_MISSING_PHONE',
            'CUSTOMERS_MISSING_PHONE_NO',
            'VENDORS_MISSING_PHONE',
            'VENDORS_MISSING_PHONE_NO':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 2, 0.20, 12);
            'CUSTOMERS_MISSING_POST_CODE',
            'CUSTOMERS_MISSING_POSTCODE',
            'VENDORS_MISSING_POST_CODE',
            'VENDORS_MISSING_POSTCODE':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 4, 0.25, 8);
            'CUSTOMERS_MISSING_SEARCH_NAME',
            'VENDORS_MISSING_SEARCH_NAME':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 2, 0.20, 12);
            'CUSTOMERS_MISSING_VAT_BUS_POSTING',
            'CUSTOMERS_MISSING_VAT_BUS_POSTING_GROUP',
            'VENDORS_MISSING_VAT_BUS_POSTING',
            'VENDORS_MISSING_VAT_BUS_POSTING_GROUP':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 10, 0.40, 12);
            'CUSTOMERS_MISSING_VAT_REG_NO':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 15, 0.40, 12);
            'CUSTOMER_LEDGER_OVERDUE_30',
            'VENDOR_LEDGER_OVERDUE_30':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 16, 0.35, 12);
            'ITEMS_MISSING_BASE_UOM',
            'ITEMS_MISSING_BASE_UNIT':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 7, 0.35, 12);
            'ITEMS_MISSING_CATEGORY':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 4, 0.20, 12);
            'ITEMS_MISSING_DESCRIPTION':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 2, 0.15, 24);
            'ITEMS_MISSING_GEN_PROD_POSTING',
            'ITEMS_MISSING_GEN_PROD_POSTING_GROUP':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 10, 0.45, 12);
            'ITEMS_MISSING_INVENTORY_POSTING',
            'ITEMS_MISSING_INVENTORY_POSTING_GROUP':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 12, 0.45, 12);
            'ITEMS_MISSING_VAT_PROD_POSTING_GROUP':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 9, 0.35, 12);
            'ITEMS_WITHOUT_VENDOR_NO',
            'ITEMS_MISSING_VENDOR_NO':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 4, 0.20, 12);
            'ITEMS_NEGATIVE_INVENTORY':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 20, 0.60, 12);
            'ITEMS_WITHOUT_UNIT_COST':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 12, 0.60, 12);
            'ITEMS_WITHOUT_UNIT_PRICE':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 12, 0.70, 12);
            'PURCHASE_DOCS_WITH_BLOCKED_VENDORS',
            'SALES_DOCS_WITH_BLOCKED_CUSTOMERS':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 15, 0.50, 12);
            'PURCHASE_LINES_MISSING_DIMENSIONS',
            'SALES_LINES_MISSING_DIMENSIONS':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 5, 0.25, 12);
            'PURCHASE_LINES_MISSING_NO',
            'SALES_LINES_MISSING_NO':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 12, 0.50, 12);
            'PURCHASE_LINES_ZERO_COST':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 14, 0.65, 12);
            'SALES_LINES_ZERO_PRICE':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 15, 0.70, 12);
            'PURCHASE_LINES_ZERO_QUANTITY',
            'SALES_LINES_ZERO_QUANTITY':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 8, 0.40, 12);
            'PURCHASE_ORDERS_MISSING_EXPECTED_DATE':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 7, 0.30, 12);
            'PURCHASE_ORDERS_OLD_OPEN',
            'SALES_ORDERS_OLD_OPEN':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 10, 0.40, 12);
            'SALES_ORDERS_MISSING_SHIPMENT_DATE':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 8, 0.35, 12);
            'VENDORS_MISSING_BANK_ACCOUNT':
                SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 12, 0.55, 12);
            else
                SetFallbackDefinition(NormalizedCode, MinutesPerOccurrence, Probability, FrequencyPerYear);
        end;
    end;

    local procedure SetDefinition(var MinutesPerOccurrence: Decimal; var Probability: Decimal; var FrequencyPerYear: Decimal; NewMinutes: Decimal; NewProbability: Decimal; NewFrequency: Decimal)
    begin
        MinutesPerOccurrence := NewMinutes;
        Probability := NewProbability;
        FrequencyPerYear := NewFrequency;
    end;

    local procedure SetFallbackDefinition(NormalizedCode: Text; var MinutesPerOccurrence: Decimal; var Probability: Decimal; var FrequencyPerYear: Decimal)
    begin
        if StrPos(NormalizedCode, 'DUPLICATE') > 0 then begin
            SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 20, 0.25, 12);
            exit;
        end;

        if (StrPos(NormalizedCode, 'ZERO_PRICE') > 0) or (StrPos(NormalizedCode, 'WITHOUT_UNIT_PRICE') > 0) then begin
            SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 15, 0.70, 12);
            exit;
        end;

        if (StrPos(NormalizedCode, 'ZERO_COST') > 0) or (StrPos(NormalizedCode, 'WITHOUT_UNIT_COST') > 0) then begin
            SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 14, 0.65, 12);
            exit;
        end;

        if (StrPos(NormalizedCode, 'NEGATIVE_INVENTORY') > 0) or (StrPos(NormalizedCode, 'BLOCKED_') > 0) then begin
            SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 18, 0.50, 12);
            exit;
        end;

        if (StrPos(NormalizedCode, 'PAYMENT') > 0) or (StrPos(NormalizedCode, 'POSTING') > 0) then begin
            SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 10, 0.40, 12);
            exit;
        end;

        if StrPos(NormalizedCode, 'EMAIL') > 0 then begin
            SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 3, 0.30, 12);
            exit;
        end;

        if StrPos(NormalizedCode, 'PHONE') > 0 then begin
            SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 2, 0.20, 12);
            exit;
        end;

        if (StrPos(NormalizedCode, 'ADDRESS') > 0) or (StrPos(NormalizedCode, 'POST_CODE') > 0) or (StrPos(NormalizedCode, 'POSTCODE') > 0) then begin
            SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 4, 0.25, 8);
            exit;
        end;

        SetDefinition(MinutesPerOccurrence, Probability, FrequencyPerYear, 5, 0.20, 12);
    end;
}
