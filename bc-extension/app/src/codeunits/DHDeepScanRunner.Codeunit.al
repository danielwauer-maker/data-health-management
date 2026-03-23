codeunit 53128 "DH Deep Scan Runner"
{
    TableNo = "DH Deep Scan Run";

    trigger OnRun()
    begin
        ProcessRun(Rec);
    end;

    local procedure ProcessRun(var DeepScanRun: Record "DH Deep Scan Run")
    var
        Score: Integer;
        ChecksCount: Integer;
        IssuesCount: Integer;
        Setup: Record "DH Setup";
        ApiClient: Codeunit "DH API Client";
        RequestText: Text;
    begin
        DeepScanRun.LockTable();
        if not DeepScanRun.Get(DeepScanRun."Entry No.") then
            exit;

        if DeepScanRun.Status <> DeepScanRun.Status::Queued then
            exit;

        DeepScanRun.Status := DeepScanRun.Status::Running;
        DeepScanRun."Started At" := CurrentDateTime();
        DeepScanRun."Finished At" := 0DT;
        DeepScanRun."Error Message" := '';
        DeepScanRun."Headline" := 'Deep scan is running';
        DeepScanRun.Modify(true);
        Commit();

        RunChecks(DeepScanRun, Score, ChecksCount, IssuesCount);

        DeepScanRun.Get(DeepScanRun."Entry No.");
        DeepScanRun."Deep Score" := Score;
        DeepScanRun."Checks Count" := ChecksCount;
        DeepScanRun."Issues Count" := IssuesCount;
        DeepScanRun."Rating" := CopyStr(GetRating(Score), 1, MaxStrLen(DeepScanRun."Rating"));
        DeepScanRun."Headline" := CopyStr(GetHeadline(Score, IssuesCount), 1, MaxStrLen(DeepScanRun."Headline"));
        DeepScanRun.Status := DeepScanRun.Status::Completed;
        DeepScanRun."Finished At" := CurrentDateTime();
        DeepScanRun.Modify(true);

        EnsureDashboardHeaderForDeepScan(DeepScanRun);
        Commit();

        if Setup.Get('SETUP') then begin
            RequestText := BuildSyncPayload(Setup, DeepScanRun);
            ApiClient.SyncScanToBackend(Setup, RequestText);
        end;
    end;

    local procedure RunChecks(var DeepScanRun: Record "DH Deep Scan Run"; var Score: Integer; var ChecksCount: Integer; var IssuesCount: Integer)
    begin
        Score := 100;
        ChecksCount := 0;
        IssuesCount := 0;

        RunCustomerMasterDataChecks(DeepScanRun, Score, ChecksCount, IssuesCount);
        RunVendorMasterDataChecks(DeepScanRun, Score, ChecksCount, IssuesCount);
        RunCustomerDuplicateEmailCheck(DeepScanRun, Score, ChecksCount, IssuesCount);
        RunVendorDuplicateEmailCheck(DeepScanRun, Score, ChecksCount, IssuesCount);
        RunCustomerDuplicateVatCheck(DeepScanRun, Score, ChecksCount, IssuesCount);
        RunVendorDuplicateVatCheck(DeepScanRun, Score, ChecksCount, IssuesCount);
        RunCustomerDuplicateNamePostCodeCityCheck(DeepScanRun, Score, ChecksCount, IssuesCount);
        RunVendorDuplicateNamePostCodeCityCheck(DeepScanRun, Score, ChecksCount, IssuesCount);
        RunItemMasterDataChecks(DeepScanRun, Score, ChecksCount, IssuesCount);
        RunSalesDocumentQualityChecks(DeepScanRun, Score, ChecksCount, IssuesCount);
        RunPurchaseDocumentQualityChecks(DeepScanRun, Score, ChecksCount, IssuesCount);
        RunLedgerAgingChecks(DeepScanRun, Score, ChecksCount, IssuesCount);

        if Score < 0 then
            Score := 0;
    end;

    local procedure RunCustomerMasterDataChecks(var DeepScanRun: Record "DH Deep Scan Run"; var Score: Integer; var ChecksCount: Integer; var IssuesCount: Integer)
    var
        Customer: Record Customer;
        ExceptionMgt: Codeunit "DH Exception Mgt.";
        MissingName: Integer;
        MissingSearchName: Integer;
        MissingAddress: Integer;
        MissingCity: Integer;
        MissingPostCode: Integer;
        MissingCountryCode: Integer;
        MissingEmail: Integer;
        MissingPhone: Integer;
        MissingPaymentTerms: Integer;
        MissingPaymentMethod: Integer;
        MissingCustomerPostingGroup: Integer;
        MissingGenBusPostingGroup: Integer;
        MissingVatBusPostingGroup: Integer;
        MissingCreditLimit: Integer;
        BlockedWithOpenSalesDocs: Integer;
        BlockedWithOpenLedgerEntries: Integer;
    begin
        ChecksCount += 16;

        Customer.Reset();
        if Customer.FindSet() then
            repeat
                if (Customer.Name = '') and not ExceptionMgt.IsCustomerIssueExcluded(Customer, 'CUSTOMERS_MISSING_NAME') then
                    MissingName += 1;
                if (Customer."Search Name" = '') and not ExceptionMgt.IsCustomerIssueExcluded(Customer, 'CUSTOMERS_MISSING_SEARCH_NAME') then
                    MissingSearchName += 1;
                if (Customer.Address = '') and not ExceptionMgt.IsCustomerIssueExcluded(Customer, 'CUSTOMERS_MISSING_ADDRESS') then
                    MissingAddress += 1;
                if (Customer.City = '') and not ExceptionMgt.IsCustomerIssueExcluded(Customer, 'CUSTOMERS_MISSING_CITY') then
                    MissingCity += 1;
                if (Customer."Post Code" = '') and not ExceptionMgt.IsCustomerIssueExcluded(Customer, 'CUSTOMERS_MISSING_POST_CODE') then
                    MissingPostCode += 1;
                if (Customer."Country/Region Code" = '') and not ExceptionMgt.IsCustomerIssueExcluded(Customer, 'CUSTOMERS_MISSING_COUNTRY') then
                    MissingCountryCode += 1;
                if (Customer."E-Mail" = '') and not ExceptionMgt.IsCustomerIssueExcluded(Customer, 'CUSTOMERS_MISSING_EMAIL') then
                    MissingEmail += 1;
                if (Customer."Phone No." = '') and not ExceptionMgt.IsCustomerIssueExcluded(Customer, 'CUSTOMERS_MISSING_PHONE') then
                    MissingPhone += 1;
                if (Customer."Payment Terms Code" = '') and not ExceptionMgt.IsCustomerIssueExcluded(Customer, 'CUSTOMERS_MISSING_PAYMENT_TERMS') then
                    MissingPaymentTerms += 1;
                if (Customer."Payment Method Code" = '') and not ExceptionMgt.IsCustomerIssueExcluded(Customer, 'CUSTOMERS_MISSING_PAYMENT_METHOD') then
                    MissingPaymentMethod += 1;
                if (Customer."Customer Posting Group" = '') and not ExceptionMgt.IsCustomerIssueExcluded(Customer, 'CUSTOMERS_MISSING_POSTING_GROUP') then
                    MissingCustomerPostingGroup += 1;
                if (Customer."Gen. Bus. Posting Group" = '') and not ExceptionMgt.IsCustomerIssueExcluded(Customer, 'CUSTOMERS_MISSING_GEN_BUS_POSTING') then
                    MissingGenBusPostingGroup += 1;
                if (Customer."VAT Bus. Posting Group" = '') and not ExceptionMgt.IsCustomerIssueExcluded(Customer, 'CUSTOMERS_MISSING_VAT_BUS_POSTING') then
                    MissingVatBusPostingGroup += 1;
                if (Customer."Credit Limit (LCY)" = 0) and not ExceptionMgt.IsCustomerIssueExcluded(Customer, 'CUSTOMERS_MISSING_CREDIT_LIMIT') then
                    MissingCreditLimit += 1;

                if Customer.Blocked <> Customer.Blocked::" " then begin
                    if HasOpenSalesDocumentsForCustomer(Customer."No.") and not ExceptionMgt.IsCustomerIssueExcluded(Customer, 'BLOCKED_CUSTOMERS_WITH_OPEN_SALES_DOCS') then
                        BlockedWithOpenSalesDocs += 1;
                    if HasOpenCustomerLedgerEntries(Customer."No.") and not ExceptionMgt.IsCustomerIssueExcluded(Customer, 'BLOCKED_CUSTOMERS_WITH_OPEN_LEDGER') then
                        BlockedWithOpenLedgerEntries += 1;
                end;
            until Customer.Next() = 0;

        AddCountFinding(DeepScanRun, Score, IssuesCount, 'CUSTOMER', 'CUSTOMERS_MISSING_NAME', 'Kunden ohne Name', 'high', MissingName, 'Kundennamen in den betroffenen Debitoren pflegen.', 5);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'CUSTOMER', 'CUSTOMERS_MISSING_SEARCH_NAME', 'Kunden ohne Suchname', 'low', MissingSearchName, 'Suchnamen pflegen, um Suche und Dublettenprüfung zu verbessern.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'CUSTOMER', 'CUSTOMERS_MISSING_ADDRESS', 'Kunden ohne Adresse', 'high', MissingAddress, 'Adressdaten in den betroffenen Debitoren vervollständigen.', 5);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'CUSTOMER', 'CUSTOMERS_MISSING_CITY', 'Kunden ohne Ort', 'medium', MissingCity, 'Ortsangaben in den betroffenen Debitoren pflegen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'CUSTOMER', 'CUSTOMERS_MISSING_POST_CODE', 'Kunden ohne Postleitzahl', 'medium', MissingPostCode, 'Postleitzahlen pflegen, damit Auswertungen und Plausibilitäten sauber funktionieren.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'CUSTOMER', 'CUSTOMERS_MISSING_COUNTRY', 'Kunden ohne Länder-/Regionscode', 'medium', MissingCountryCode, 'Länder-/Regionscode bei den betroffenen Debitoren ergänzen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'CUSTOMER', 'CUSTOMERS_MISSING_EMAIL', 'Kunden ohne E-Mail', 'medium', MissingEmail, 'E-Mail-Adressen pflegen, um Kommunikation und Automatisierung zu verbessern.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'CUSTOMER', 'CUSTOMERS_MISSING_PHONE', 'Kunden ohne Telefonnummer', 'low', MissingPhone, 'Telefonnummern ergänzen, damit Kontaktaufnahmen möglich bleiben.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'CUSTOMER', 'CUSTOMERS_MISSING_PAYMENT_TERMS', 'Kunden ohne Zahlungsbedingung', 'high', MissingPaymentTerms, 'Zahlungsbedingungen ergänzen, um offene Posten und Prozesse zu stabilisieren.', 5);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'CUSTOMER', 'CUSTOMERS_MISSING_PAYMENT_METHOD', 'Kunden ohne Zahlungsform', 'medium', MissingPaymentMethod, 'Zahlungsform pflegen, sofern im Mandanten genutzt.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'CUSTOMER', 'CUSTOMERS_MISSING_POSTING_GROUP', 'Kunden ohne Debitorenbuchungsgruppe', 'high', MissingCustomerPostingGroup, 'Debitorenbuchungsgruppen bei den betroffenen Kunden ergänzen.', 6);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'CUSTOMER', 'CUSTOMERS_MISSING_GEN_BUS_POSTING', 'Kunden ohne Geschäftsbuchungsgruppe', 'high', MissingGenBusPostingGroup, 'Geschäftsbuchungsgruppen vervollständigen.', 6);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'CUSTOMER', 'CUSTOMERS_MISSING_VAT_BUS_POSTING', 'Kunden ohne MwSt.-Geschäftsbuchungsgruppe', 'high', MissingVatBusPostingGroup, 'MwSt.-Geschäftsbuchungsgruppen ergänzen.', 6);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'CUSTOMER', 'CUSTOMERS_MISSING_CREDIT_LIMIT', 'Kunden ohne Kreditlimit', 'low', MissingCreditLimit, 'Kreditlimits fachlich prüfen und bei Bedarf pflegen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'CUSTOMER', 'BLOCKED_CUSTOMERS_WITH_OPEN_SALES_DOCS', 'Gesperrte Kunden mit offenen Verkaufsbelegen', 'high', BlockedWithOpenSalesDocs, 'Gesperrte Debitoren und offene Verkaufsbelege fachlich bereinigen.', 7);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'CUSTOMER', 'BLOCKED_CUSTOMERS_WITH_OPEN_LEDGER', 'Gesperrte Kunden mit offenen Posten', 'high', BlockedWithOpenLedgerEntries, 'Offene Posten gesperrter Debitoren prüfen und Altlasten bereinigen.', 7);
    end;

    local procedure RunVendorMasterDataChecks(var DeepScanRun: Record "DH Deep Scan Run"; var Score: Integer; var ChecksCount: Integer; var IssuesCount: Integer)
    var
        Vendor: Record Vendor;
        ExceptionMgt: Codeunit "DH Exception Mgt.";
        MissingName: Integer;
        MissingSearchName: Integer;
        MissingAddress: Integer;
        MissingCity: Integer;
        MissingPostCode: Integer;
        MissingCountryCode: Integer;
        MissingEmail: Integer;
        MissingPhone: Integer;
        MissingPaymentTerms: Integer;
        MissingPaymentMethod: Integer;
        MissingVendorPostingGroup: Integer;
        MissingGenBusPostingGroup: Integer;
        MissingVatBusPostingGroup: Integer;
        MissingBankAccount: Integer;
        BlockedWithOpenPurchaseDocs: Integer;
        BlockedWithOpenLedgerEntries: Integer;
    begin
        ChecksCount += 16;

        Vendor.Reset();
        if Vendor.FindSet() then
            repeat
                if (Vendor.Name = '') and not ExceptionMgt.IsVendorIssueExcluded(Vendor, 'VENDORS_MISSING_NAME') then
                    MissingName += 1;
                if (Vendor."Search Name" = '') and not ExceptionMgt.IsVendorIssueExcluded(Vendor, 'VENDORS_MISSING_SEARCH_NAME') then
                    MissingSearchName += 1;
                if (Vendor.Address = '') and not ExceptionMgt.IsVendorIssueExcluded(Vendor, 'VENDORS_MISSING_ADDRESS') then
                    MissingAddress += 1;
                if (Vendor.City = '') and not ExceptionMgt.IsVendorIssueExcluded(Vendor, 'VENDORS_MISSING_CITY') then
                    MissingCity += 1;
                if (Vendor."Post Code" = '') and not ExceptionMgt.IsVendorIssueExcluded(Vendor, 'VENDORS_MISSING_POST_CODE') then
                    MissingPostCode += 1;
                if (Vendor."Country/Region Code" = '') and not ExceptionMgt.IsVendorIssueExcluded(Vendor, 'VENDORS_MISSING_COUNTRY') then
                    MissingCountryCode += 1;
                if (Vendor."E-Mail" = '') and not ExceptionMgt.IsVendorIssueExcluded(Vendor, 'VENDORS_MISSING_EMAIL') then
                    MissingEmail += 1;
                if (Vendor."Phone No." = '') and not ExceptionMgt.IsVendorIssueExcluded(Vendor, 'VENDORS_MISSING_PHONE') then
                    MissingPhone += 1;
                if (Vendor."Payment Terms Code" = '') and not ExceptionMgt.IsVendorIssueExcluded(Vendor, 'VENDORS_MISSING_PAYMENT_TERMS') then
                    MissingPaymentTerms += 1;
                if (Vendor."Payment Method Code" = '') and not ExceptionMgt.IsVendorIssueExcluded(Vendor, 'VENDORS_MISSING_PAYMENT_METHOD') then
                    MissingPaymentMethod += 1;
                if (Vendor."Vendor Posting Group" = '') and not ExceptionMgt.IsVendorIssueExcluded(Vendor, 'VENDORS_MISSING_POSTING_GROUP') then
                    MissingVendorPostingGroup += 1;
                if (Vendor."Gen. Bus. Posting Group" = '') and not ExceptionMgt.IsVendorIssueExcluded(Vendor, 'VENDORS_MISSING_GEN_BUS_POSTING') then
                    MissingGenBusPostingGroup += 1;
                if (Vendor."VAT Bus. Posting Group" = '') and not ExceptionMgt.IsVendorIssueExcluded(Vendor, 'VENDORS_MISSING_VAT_BUS_POSTING') then
                    MissingVatBusPostingGroup += 1;
                if (Vendor."Preferred Bank Account Code" = '') and not ExceptionMgt.IsVendorIssueExcluded(Vendor, 'VENDORS_MISSING_BANK_ACCOUNT') then
                    MissingBankAccount += 1;

                if Vendor.Blocked <> Vendor.Blocked::" " then begin
                    if HasOpenPurchaseDocumentsForVendor(Vendor."No.") and not ExceptionMgt.IsVendorIssueExcluded(Vendor, 'BLOCKED_VENDORS_WITH_OPEN_PURCHASE_DOCS') then
                        BlockedWithOpenPurchaseDocs += 1;
                    if HasOpenVendorLedgerEntries(Vendor."No.") and not ExceptionMgt.IsVendorIssueExcluded(Vendor, 'BLOCKED_VENDORS_WITH_OPEN_LEDGER') then
                        BlockedWithOpenLedgerEntries += 1;
                end;
            until Vendor.Next() = 0;

        AddCountFinding(DeepScanRun, Score, IssuesCount, 'VENDOR', 'VENDORS_MISSING_NAME', 'Lieferanten ohne Name', 'high', MissingName, 'Lieferantennamen in den betroffenen Kreditoren pflegen.', 5);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'VENDOR', 'VENDORS_MISSING_SEARCH_NAME', 'Lieferanten ohne Suchname', 'low', MissingSearchName, 'Suchnamen pflegen, um Suche und Dublettenprüfung zu verbessern.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'VENDOR', 'VENDORS_MISSING_ADDRESS', 'Lieferanten ohne Adresse', 'high', MissingAddress, 'Adressdaten in den betroffenen Kreditoren vervollständigen.', 5);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'VENDOR', 'VENDORS_MISSING_CITY', 'Lieferanten ohne Ort', 'medium', MissingCity, 'Ortsangaben in den betroffenen Kreditoren pflegen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'VENDOR', 'VENDORS_MISSING_POST_CODE', 'Lieferanten ohne Postleitzahl', 'medium', MissingPostCode, 'Postleitzahlen pflegen, damit Auswertungen und Plausibilitäten sauber funktionieren.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'VENDOR', 'VENDORS_MISSING_COUNTRY', 'Lieferanten ohne Länder-/Regionscode', 'medium', MissingCountryCode, 'Länder-/Regionscode bei den betroffenen Kreditoren ergänzen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'VENDOR', 'VENDORS_MISSING_EMAIL', 'Lieferanten ohne E-Mail', 'medium', MissingEmail, 'E-Mail-Adressen pflegen, um Kommunikation und Automatisierung zu verbessern.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'VENDOR', 'VENDORS_MISSING_PHONE', 'Lieferanten ohne Telefonnummer', 'low', MissingPhone, 'Telefonnummern ergänzen, damit Kontaktaufnahmen möglich bleiben.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'VENDOR', 'VENDORS_MISSING_PAYMENT_TERMS', 'Lieferanten ohne Zahlungsbedingung', 'high', MissingPaymentTerms, 'Zahlungsbedingungen ergänzen, um offene Posten und Prozesse zu stabilisieren.', 5);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'VENDOR', 'VENDORS_MISSING_PAYMENT_METHOD', 'Lieferanten ohne Zahlungsform', 'medium', MissingPaymentMethod, 'Zahlungsform pflegen, sofern im Mandanten genutzt.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'VENDOR', 'VENDORS_MISSING_POSTING_GROUP', 'Lieferanten ohne Kreditorenbuchungsgruppe', 'high', MissingVendorPostingGroup, 'Kreditorenbuchungsgruppen bei den betroffenen Lieferanten ergänzen.', 6);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'VENDOR', 'VENDORS_MISSING_GEN_BUS_POSTING', 'Lieferanten ohne Geschäftsbuchungsgruppe', 'high', MissingGenBusPostingGroup, 'Geschäftsbuchungsgruppen vervollständigen.', 6);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'VENDOR', 'VENDORS_MISSING_VAT_BUS_POSTING', 'Lieferanten ohne MwSt.-Geschäftsbuchungsgruppe', 'high', MissingVatBusPostingGroup, 'MwSt.-Geschäftsbuchungsgruppen ergänzen.', 6);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'VENDOR', 'VENDORS_MISSING_BANK_ACCOUNT', 'Lieferanten ohne Bankverbindung', 'medium', MissingBankAccount, 'Bankverbindungen für betroffene Kreditoren pflegen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'VENDOR', 'BLOCKED_VENDORS_WITH_OPEN_PURCHASE_DOCS', 'Gesperrte Lieferanten mit offenen Einkaufsbelegen', 'high', BlockedWithOpenPurchaseDocs, 'Gesperrte Kreditoren und offene Einkaufsbelege fachlich bereinigen.', 7);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'VENDOR', 'BLOCKED_VENDORS_WITH_OPEN_LEDGER', 'Gesperrte Lieferanten mit offenen Posten', 'high', BlockedWithOpenLedgerEntries, 'Offene Posten gesperrter Kreditoren prüfen und Altlasten bereinigen.', 7);
    end;

    local procedure RunCustomerDuplicateEmailCheck(var DeepScanRun: Record "DH Deep Scan Run"; var Score: Integer; var ChecksCount: Integer; var IssuesCount: Integer)
    var
        EmailQuery: Query "DH Customer Duplicate Email";
        DuplicateCount: Integer;
        Email: Text[100];
    begin
        ChecksCount += 1;

        EmailQuery.SetFilter(EmailFilter, '<>%1', '');
        EmailQuery.Open();

        while EmailQuery.Read() do begin
            Email := CopyStr(EmailQuery.Email, 1, MaxStrLen(Email));
            DuplicateCount := CountCustomersByEmail(Email, 'CUSTOMERS_DUPLICATE_EMAIL');

            if DuplicateCount > 1 then begin
                InsertFinding(
                    DeepScanRun."Entry No.",
                    'CUSTOMER',
                    'CUSTOMERS_DUPLICATE_EMAIL',
                    StrSubstNo('Mehrere Kunden mit gleicher E-Mail: %1', Email),
                    'high',
                    DuplicateCount,
                    'Dubletten prüfen und einen führenden Debitor festlegen.');

                IssuesCount += 1;
                ApplyPenalty(Score, 8);
            end;
        end;

        EmailQuery.Close();
    end;

    local procedure RunVendorDuplicateEmailCheck(var DeepScanRun: Record "DH Deep Scan Run"; var Score: Integer; var ChecksCount: Integer; var IssuesCount: Integer)
    var
        EmailQuery: Query "DH Vendor Duplicate Email";
        DuplicateCount: Integer;
        Email: Text[100];
    begin
        ChecksCount += 1;

        EmailQuery.SetFilter(EmailFilter, '<>%1', '');
        EmailQuery.Open();

        while EmailQuery.Read() do begin
            Email := CopyStr(EmailQuery.Email, 1, MaxStrLen(Email));
            DuplicateCount := CountVendorsByEmail(Email, 'VENDORS_DUPLICATE_EMAIL');

            if DuplicateCount > 1 then begin
                InsertFinding(
                    DeepScanRun."Entry No.",
                    'VENDOR',
                    'VENDORS_DUPLICATE_EMAIL',
                    StrSubstNo('Mehrere Lieferanten mit gleicher E-Mail: %1', Email),
                    'high',
                    DuplicateCount,
                    'Dubletten prüfen und betroffene Kreditoren bereinigen.');

                IssuesCount += 1;
                ApplyPenalty(Score, 8);
            end;
        end;

        EmailQuery.Close();
    end;

    local procedure RunCustomerDuplicateVatCheck(var DeepScanRun: Record "DH Deep Scan Run"; var Score: Integer; var ChecksCount: Integer; var IssuesCount: Integer)
    var
        Customer: Record Customer;
        DuplicateCount: Integer;
    begin
        ChecksCount += 1;

        Customer.Reset();
        Customer.SetFilter("VAT Registration No.", '<>%1', '');

        if Customer.FindSet() then
            repeat
                if not IsCustomerDuplicateExcluded(Customer, 'CUSTOMERS_DUPLICATE_VAT') then
                    if not FindingExists(DeepScanRun."Entry No.", 'CUSTOMERS_DUPLICATE_VAT', Customer."VAT Registration No.") then begin
                        DuplicateCount := CountCustomersByVat(Customer."VAT Registration No.", 'CUSTOMERS_DUPLICATE_VAT');

                        if DuplicateCount > 1 then begin
                            InsertFinding(
                                DeepScanRun."Entry No.",
                                'CUSTOMER',
                                'CUSTOMERS_DUPLICATE_VAT',
                                StrSubstNo('Mehrere Kunden mit gleicher USt.-IdNr.: %1', Customer."VAT Registration No."),
                                'high',
                                DuplicateCount,
                                'USt.-IdNr. und Stammdaten auf Dubletten prüfen.');

                            IssuesCount += 1;
                            ApplyPenalty(Score, 8);
                        end;
                    end;
            until Customer.Next() = 0;
    end;

    local procedure RunVendorDuplicateVatCheck(var DeepScanRun: Record "DH Deep Scan Run"; var Score: Integer; var ChecksCount: Integer; var IssuesCount: Integer)
    var
        Vendor: Record Vendor;
        DuplicateCount: Integer;
    begin
        ChecksCount += 1;

        Vendor.Reset();
        Vendor.SetFilter("VAT Registration No.", '<>%1', '');

        if Vendor.FindSet() then
            repeat
                if not IsVendorDuplicateExcluded(Vendor, 'VENDORS_DUPLICATE_VAT') then
                    if not FindingExists(DeepScanRun."Entry No.", 'VENDORS_DUPLICATE_VAT', Vendor."VAT Registration No.") then begin
                        DuplicateCount := CountVendorsByVat(Vendor."VAT Registration No.", 'VENDORS_DUPLICATE_VAT');

                        if DuplicateCount > 1 then begin
                            InsertFinding(
                                DeepScanRun."Entry No.",
                                'VENDOR',
                                'VENDORS_DUPLICATE_VAT',
                                StrSubstNo('Mehrere Lieferanten mit gleicher USt.-IdNr.: %1', Vendor."VAT Registration No."),
                                'high',
                                DuplicateCount,
                                'USt.-IdNr. und Kreditorenstammdaten auf Dubletten prüfen.');

                            IssuesCount += 1;
                            ApplyPenalty(Score, 8);
                        end;
                    end;
            until Vendor.Next() = 0;
    end;

    local procedure RunCustomerDuplicateNamePostCodeCityCheck(var DeepScanRun: Record "DH Deep Scan Run"; var Score: Integer; var ChecksCount: Integer; var IssuesCount: Integer)
    var
        Customer: Record Customer;
        DuplicateCount: Integer;
        Marker: Text[250];
    begin
        ChecksCount += 1;

        Customer.Reset();
        Customer.SetFilter(Name, '<>%1', '');
        Customer.SetFilter("Post Code", '<>%1', '');
        Customer.SetFilter(City, '<>%1', '');

        if Customer.FindSet() then
            repeat
                if not IsCustomerDuplicateExcluded(Customer, 'CUSTOMERS_DUPLICATE_NAME_POST_CITY') then begin
                    Marker := CopyStr(Customer.Name + '|' + Customer."Post Code" + '|' + Customer.City, 1, MaxStrLen(Marker));
                    if not FindingExists(DeepScanRun."Entry No.", 'CUSTOMERS_DUPLICATE_NAME_POST_CITY', Marker) then begin
                        DuplicateCount := CountCustomersByNamePostCity(Customer.Name, Customer."Post Code", Customer.City, 'CUSTOMERS_DUPLICATE_NAME_POST_CITY');

                        if DuplicateCount > 1 then begin
                            InsertFinding(
                                DeepScanRun."Entry No.",
                                'CUSTOMER',
                                'CUSTOMERS_DUPLICATE_NAME_POST_CITY',
                                StrSubstNo('Mehrere Kunden mit gleichem Namen/PLZ/Ort: %1 | %2 %3', Customer.Name, Customer."Post Code", Customer.City),
                                'high',
                                DuplicateCount,
                                'Mögliche Debitoren-Dubletten prüfen und zusammenführen.');

                            IssuesCount += 1;
                            ApplyPenalty(Score, 8);
                        end;
                    end;
                end;
            until Customer.Next() = 0;
    end;

    local procedure RunVendorDuplicateNamePostCodeCityCheck(var DeepScanRun: Record "DH Deep Scan Run"; var Score: Integer; var ChecksCount: Integer; var IssuesCount: Integer)
    var
        Vendor: Record Vendor;
        DuplicateCount: Integer;
        Marker: Text[250];
    begin
        ChecksCount += 1;

        Vendor.Reset();
        Vendor.SetFilter(Name, '<>%1', '');
        Vendor.SetFilter("Post Code", '<>%1', '');
        Vendor.SetFilter(City, '<>%1', '');

        if Vendor.FindSet() then
            repeat
                if not IsVendorDuplicateExcluded(Vendor, 'VENDORS_DUPLICATE_NAME_POST_CITY') then begin
                    Marker := CopyStr(Vendor.Name + '|' + Vendor."Post Code" + '|' + Vendor.City, 1, MaxStrLen(Marker));
                    if not FindingExists(DeepScanRun."Entry No.", 'VENDORS_DUPLICATE_NAME_POST_CITY', Marker) then begin
                        DuplicateCount := CountVendorsByNamePostCity(Vendor.Name, Vendor."Post Code", Vendor.City, 'VENDORS_DUPLICATE_NAME_POST_CITY');

                        if DuplicateCount > 1 then begin
                            InsertFinding(
                                DeepScanRun."Entry No.",
                                'VENDOR',
                                'VENDORS_DUPLICATE_NAME_POST_CITY',
                                StrSubstNo('Mehrere Lieferanten mit gleichem Namen/PLZ/Ort: %1 | %2 %3', Vendor.Name, Vendor."Post Code", Vendor.City),
                                'high',
                                DuplicateCount,
                                'Mögliche Kreditoren-Dubletten prüfen und zusammenführen.');

                            IssuesCount += 1;
                            ApplyPenalty(Score, 8);
                        end;
                    end;
                end;
            until Vendor.Next() = 0;
    end;

    local procedure RunItemMasterDataChecks(var DeepScanRun: Record "DH Deep Scan Run"; var Score: Integer; var ChecksCount: Integer; var IssuesCount: Integer)
    var
        Item: Record Item;
        ExceptionMgt: Codeunit "DH Exception Mgt.";
        MissingDescription: Integer;
        MissingBaseUom: Integer;
        MissingItemCategory: Integer;
        MissingGenProdPostingGroup: Integer;
        MissingInventoryPostingGroup: Integer;
        MissingVendorNo: Integer;
        MissingUnitCost: Integer;
        MissingUnitPrice: Integer;
        NegativeInventory: Integer;
        BlockedWithInventory: Integer;
    begin
        ChecksCount += 10;

        Item.Reset();
        if Item.FindSet() then
            repeat
                Item.CalcFields(Inventory);

                if (Item.Description = '') and not ExceptionMgt.IsItemIssueExcluded(Item, 'ITEMS_MISSING_DESCRIPTION') then
                    MissingDescription += 1;
                if (Item."Base Unit of Measure" = '') and not ExceptionMgt.IsItemIssueExcluded(Item, 'ITEMS_MISSING_BASE_UOM') then
                    MissingBaseUom += 1;
                if (Item."Item Category Code" = '') and not ExceptionMgt.IsItemIssueExcluded(Item, 'ITEMS_MISSING_CATEGORY') then
                    MissingItemCategory += 1;
                if (Item."Gen. Prod. Posting Group" = '') and not ExceptionMgt.IsItemIssueExcluded(Item, 'ITEMS_MISSING_GEN_PROD_POSTING') then
                    MissingGenProdPostingGroup += 1;
                if (Item."Inventory Posting Group" = '') and not ExceptionMgt.IsItemIssueExcluded(Item, 'ITEMS_MISSING_INVENTORY_POSTING') then
                    MissingInventoryPostingGroup += 1;
                if (Item."Vendor No." = '') and not ExceptionMgt.IsItemIssueExcluded(Item, 'ITEMS_WITHOUT_VENDOR_NO') then
                    MissingVendorNo += 1;
                if (Item."Unit Cost" = 0) and not ExceptionMgt.IsItemIssueExcluded(Item, 'ITEMS_WITHOUT_UNIT_COST') then
                    MissingUnitCost += 1;
                if (Item."Unit Price" = 0) and not ExceptionMgt.IsItemIssueExcluded(Item, 'ITEMS_WITHOUT_UNIT_PRICE') then
                    MissingUnitPrice += 1;
                if (Item.Inventory < 0) and not ExceptionMgt.IsItemIssueExcluded(Item, 'ITEMS_NEGATIVE_INVENTORY') then
                    NegativeInventory += 1;
                if Item.Blocked and (Item.Inventory <> 0) and not ExceptionMgt.IsItemIssueExcluded(Item, 'BLOCKED_ITEMS_WITH_INVENTORY') then
                    BlockedWithInventory += 1;
            until Item.Next() = 0;

        AddCountFinding(DeepScanRun, Score, IssuesCount, 'ITEM', 'ITEMS_MISSING_DESCRIPTION', 'Artikel ohne Beschreibung', 'high', MissingDescription, 'Beschreibungen bei betroffenen Artikeln pflegen.', 5);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'ITEM', 'ITEMS_MISSING_BASE_UOM', 'Artikel ohne Basiseinheit', 'high', MissingBaseUom, 'Basiseinheiten bei den betroffenen Artikeln ergänzen.', 6);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'ITEM', 'ITEMS_MISSING_CATEGORY', 'Artikel ohne Artikelkategorie', 'medium', MissingItemCategory, 'Artikelkategorien pflegen, damit Auswertungen und Steuerung sauber funktionieren.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'ITEM', 'ITEMS_MISSING_GEN_PROD_POSTING', 'Artikel ohne Gen. Prod. Posting Group', 'high', MissingGenProdPostingGroup, 'Produktbuchungsgruppen vervollständigen.', 6);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'ITEM', 'ITEMS_MISSING_INVENTORY_POSTING', 'Artikel ohne Inventory Posting Group', 'high', MissingInventoryPostingGroup, 'Lagerbuchungsgruppen vervollständigen.', 6);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'ITEM', 'ITEMS_WITHOUT_VENDOR_NO', 'Artikel ohne Standard-Kreditor', 'medium', MissingVendorNo, 'Standard-Kreditor bei betroffenen Artikeln ergänzen, sofern fachlich erforderlich.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'ITEM', 'ITEMS_WITHOUT_UNIT_COST', 'Artikel ohne Einstandspreis', 'high', MissingUnitCost, 'Einstandspreise für betroffene Artikel prüfen und pflegen.', 6);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'ITEM', 'ITEMS_WITHOUT_UNIT_PRICE', 'Artikel ohne Verkaufspreis', 'medium', MissingUnitPrice, 'Verkaufspreise für aktiv nutzbare Artikel prüfen und pflegen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'ITEM', 'ITEMS_NEGATIVE_INVENTORY', 'Artikel mit negativem Bestand', 'high', NegativeInventory, 'Negative Bestände prüfen und Buchungslogik korrigieren.', 8);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'ITEM', 'BLOCKED_ITEMS_WITH_INVENTORY', 'Gesperrte Artikel mit Bestand', 'medium', BlockedWithInventory, 'Sperrstatus und vorhandenen Bestand fachlich abstimmen.', 4);
    end;

    local procedure RunSalesDocumentQualityChecks(var DeepScanRun: Record "DH Deep Scan Run"; var Score: Integer; var ChecksCount: Integer; var IssuesCount: Integer)
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        Customer: Record Customer;
        Item: Record Item;
        MissingShipmentDate: Integer;
        OldOrders: Integer;
        MissingNoOnLine: Integer;
        ZeroQuantity: Integer;
        ZeroPrice: Integer;
        MissingDimensions: Integer;
        BlockedCustomersOnDocs: Integer;
        BlockedItemsOnDocs: Integer;
        ThresholdDate: Date;
    begin
        ChecksCount += 8;

        ThresholdDate := CalcDate('<-30D>', Today());

        SalesHeader.Reset();
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        if SalesHeader.FindSet() then
            repeat
                if SalesHeader."Shipment Date" = 0D then
                    MissingShipmentDate += 1;
                if SalesHeader."Document Date" <> 0D then
                    if SalesHeader."Document Date" <= ThresholdDate then
                        OldOrders += 1;

                if Customer.Get(SalesHeader."Sell-to Customer No.") then
                    if Customer.Blocked <> Customer.Blocked::" " then
                        BlockedCustomersOnDocs += 1;
            until SalesHeader.Next() = 0;

        SalesLine.Reset();
        SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
        if SalesLine.FindSet() then
            repeat
                if ((SalesLine.Type = SalesLine.Type::Item) or (SalesLine.Type = SalesLine.Type::"G/L Account")) and (SalesLine."No." = '') then
                    MissingNoOnLine += 1;

                if (SalesLine.Type = SalesLine.Type::Item) or (SalesLine.Type = SalesLine.Type::"G/L Account") then
                    if SalesLine.Quantity = 0 then
                        ZeroQuantity += 1;

                if SalesLine.Type = SalesLine.Type::Item then
                    if SalesLine."Unit Price" = 0 then
                        ZeroPrice += 1;

                if ((SalesLine.Type = SalesLine.Type::Item) or (SalesLine.Type = SalesLine.Type::"G/L Account")) and
                   (SalesLine."Shortcut Dimension 1 Code" = '') and
                   (SalesLine."Shortcut Dimension 2 Code" = '')
                then
                    MissingDimensions += 1;

                if (SalesLine.Type = SalesLine.Type::Item) and (SalesLine."No." <> '') then
                    if Item.Get(SalesLine."No.") then
                        if Item.Blocked then
                            BlockedItemsOnDocs += 1;
            until SalesLine.Next() = 0;

        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SALES', 'SALES_ORDERS_MISSING_SHIPMENT_DATE', 'Offene Verkaufsaufträge ohne Lieferdatum', 'medium', MissingShipmentDate, 'Liefertermine in offenen Verkaufsaufträgen pflegen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SALES', 'SALES_ORDERS_OLD_OPEN', 'Sehr alte offene Verkaufsaufträge', 'medium', OldOrders, 'Alte Aufträge auf Relevanz, Status und Abschluss prüfen.', 4);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SALES', 'SALES_LINES_MISSING_NO', 'Verkaufszeilen ohne Artikel-/Sachkontobezug', 'high', MissingNoOnLine, 'Zeilenbezug korrigieren oder fehlerhafte Belegzeilen bereinigen.', 6);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SALES', 'SALES_LINES_ZERO_QUANTITY', 'Verkaufszeilen mit Nullmengen', 'medium', ZeroQuantity, 'Nullmengen in offenen Verkaufsbelegen bereinigen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SALES', 'SALES_LINES_ZERO_PRICE', 'Verkaufszeilen mit Nullpreisen', 'high', ZeroPrice, 'Preisfindung und offene Verkaufszeilen mit Nullpreis prüfen.', 6);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SALES', 'SALES_LINES_MISSING_DIMENSIONS', 'Verkaufszeilen ohne Dimensionen', 'high', MissingDimensions, 'Dimensionen in offenen Verkaufsbelegen ergänzen.', 6);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SALES', 'SALES_DOCS_WITH_BLOCKED_CUSTOMERS', 'Verkaufsbelege mit gesperrten Kunden', 'high', BlockedCustomersOnDocs, 'Sperrstatus der Debitoren und betroffene Belege prüfen.', 7);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SALES', 'SALES_LINES_WITH_BLOCKED_ITEMS', 'Verkaufszeilen mit gesperrten Artikeln', 'high', BlockedItemsOnDocs, 'Sperrstatus der Artikel und betroffene Verkaufszeilen prüfen.', 7);
    end;

    local procedure RunPurchaseDocumentQualityChecks(var DeepScanRun: Record "DH Deep Scan Run"; var Score: Integer; var ChecksCount: Integer; var IssuesCount: Integer)
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        Vendor: Record Vendor;
        Item: Record Item;
        MissingExpectedReceiptDate: Integer;
        OldOrders: Integer;
        MissingNoOnLine: Integer;
        ZeroQuantity: Integer;
        ZeroCost: Integer;
        MissingDimensions: Integer;
        BlockedVendorsOnDocs: Integer;
        BlockedItemsOnDocs: Integer;
        ThresholdDate: Date;
    begin
        ChecksCount += 8;

        ThresholdDate := CalcDate('<-30D>', Today());

        PurchaseHeader.Reset();
        PurchaseHeader.SetRange("Document Type", PurchaseHeader."Document Type"::Order);
        if PurchaseHeader.FindSet() then
            repeat
                if PurchaseHeader."Expected Receipt Date" = 0D then
                    MissingExpectedReceiptDate += 1;
                if PurchaseHeader."Document Date" <> 0D then
                    if PurchaseHeader."Document Date" <= ThresholdDate then
                        OldOrders += 1;

                if Vendor.Get(PurchaseHeader."Buy-from Vendor No.") then
                    if Vendor.Blocked <> Vendor.Blocked::" " then
                        BlockedVendorsOnDocs += 1;
            until PurchaseHeader.Next() = 0;

        PurchaseLine.Reset();
        PurchaseLine.SetRange("Document Type", PurchaseLine."Document Type"::Order);
        if PurchaseLine.FindSet() then
            repeat
                if ((PurchaseLine.Type = PurchaseLine.Type::Item) or (PurchaseLine.Type = PurchaseLine.Type::"G/L Account")) and (PurchaseLine."No." = '') then
                    MissingNoOnLine += 1;

                if (PurchaseLine.Type = PurchaseLine.Type::Item) or (PurchaseLine.Type = PurchaseLine.Type::"G/L Account") then
                    if PurchaseLine.Quantity = 0 then
                        ZeroQuantity += 1;

                if PurchaseLine.Type = PurchaseLine.Type::Item then
                    if PurchaseLine."Direct Unit Cost" = 0 then
                        ZeroCost += 1;

                if ((PurchaseLine.Type = PurchaseLine.Type::Item) or (PurchaseLine.Type = PurchaseLine.Type::"G/L Account")) and
                   (PurchaseLine."Shortcut Dimension 1 Code" = '') and
                   (PurchaseLine."Shortcut Dimension 2 Code" = '')
                then
                    MissingDimensions += 1;

                if (PurchaseLine.Type = PurchaseLine.Type::Item) and (PurchaseLine."No." <> '') then
                    if Item.Get(PurchaseLine."No.") then
                        if Item.Blocked then
                            BlockedItemsOnDocs += 1;
            until PurchaseLine.Next() = 0;

        AddCountFinding(DeepScanRun, Score, IssuesCount, 'PURCHASE', 'PURCHASE_ORDERS_MISSING_EXPECTED_DATE', 'Offene Einkaufsaufträge ohne erwartetes Wareneingangsdatum', 'medium', MissingExpectedReceiptDate, 'Erwartete Wareneingangsdaten in offenen Einkaufsaufträgen pflegen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'PURCHASE', 'PURCHASE_ORDERS_OLD_OPEN', 'Sehr alte offene Einkaufsaufträge', 'medium', OldOrders, 'Alte Aufträge auf Relevanz, Status und Abschluss prüfen.', 4);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'PURCHASE', 'PURCHASE_LINES_MISSING_NO', 'Einkaufszeilen ohne Artikel-/Sachkontobezug', 'high', MissingNoOnLine, 'Zeilenbezug korrigieren oder fehlerhafte Belegzeilen bereinigen.', 6);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'PURCHASE', 'PURCHASE_LINES_ZERO_QUANTITY', 'Einkaufszeilen mit Nullmengen', 'medium', ZeroQuantity, 'Nullmengen in offenen Einkaufsbelegen bereinigen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'PURCHASE', 'PURCHASE_LINES_ZERO_COST', 'Einkaufszeilen mit Nullpreisen', 'high', ZeroCost, 'Preisfindung und offene Einkaufszeilen mit Nullpreis prüfen.', 6);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'PURCHASE', 'PURCHASE_LINES_MISSING_DIMENSIONS', 'Einkaufszeilen ohne Dimensionen', 'high', MissingDimensions, 'Dimensionen in offenen Einkaufsbelegen ergänzen.', 6);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'PURCHASE', 'PURCHASE_DOCS_WITH_BLOCKED_VENDORS', 'Einkaufsbelege mit gesperrten Lieferanten', 'high', BlockedVendorsOnDocs, 'Sperrstatus der Kreditoren und betroffene Belege prüfen.', 7);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'PURCHASE', 'PURCHASE_LINES_WITH_BLOCKED_ITEMS', 'Einkaufszeilen mit gesperrten Artikeln', 'high', BlockedItemsOnDocs, 'Sperrstatus der Artikel und betroffene Einkaufszeilen prüfen.', 7);
    end;

    local procedure RunLedgerAgingChecks(var DeepScanRun: Record "DH Deep Scan Run"; var Score: Integer; var ChecksCount: Integer; var IssuesCount: Integer)
    var
        CustLedgerEntry: Record "Cust. Ledger Entry";
        VendorLedgerEntry: Record "Vendor Ledger Entry";
        OverdueCustomerEntries: Integer;
        OverdueVendorEntries: Integer;
        ThresholdDate: Date;
    begin
        ChecksCount += 2;

        ThresholdDate := CalcDate('<-30D>', Today());

        CustLedgerEntry.Reset();
        CustLedgerEntry.SetRange(Open, true);
        CustLedgerEntry.SetFilter("Due Date", '<>%1&<=%2', 0D, ThresholdDate);
        OverdueCustomerEntries := CustLedgerEntry.Count();

        VendorLedgerEntry.Reset();
        VendorLedgerEntry.SetRange(Open, true);
        VendorLedgerEntry.SetFilter("Due Date", '<>%1&<=%2', 0D, ThresholdDate);
        OverdueVendorEntries := VendorLedgerEntry.Count();

        AddCountFinding(DeepScanRun, Score, IssuesCount, 'LEDGER', 'CUSTOMER_LEDGER_OVERDUE_30', 'Offene Debitorenposten überfällig > 30 Tage', 'high', OverdueCustomerEntries, 'Überfällige Debitorenposten prüfen und Forderungsmanagement nachschärfen.', 6);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'LEDGER', 'VENDOR_LEDGER_OVERDUE_30', 'Offene Kreditorenposten überfällig > 30 Tage', 'medium', OverdueVendorEntries, 'Überfällige Kreditorenposten und Zahlungsprozesse prüfen.', 4);
    end;

    local procedure CountCustomersByEmail(Email: Text[100]; IssueCode: Code[50]): Integer
    var
        Customer: Record Customer;
        Count: Integer;
    begin
        Customer.SetRange("E-Mail", Email);
        if Customer.FindSet() then
            repeat
                if not IsCustomerDuplicateExcluded(Customer, IssueCode) then
                    Count += 1;
            until Customer.Next() = 0;

        exit(Count);
    end;

    local procedure CountVendorsByEmail(Email: Text[100]; IssueCode: Code[50]): Integer
    var
        Vendor: Record Vendor;
        Count: Integer;
    begin
        Vendor.SetRange("E-Mail", Email);
        if Vendor.FindSet() then
            repeat
                if not IsVendorDuplicateExcluded(Vendor, IssueCode) then
                    Count += 1;
            until Vendor.Next() = 0;

        exit(Count);
    end;

    local procedure CountCustomersByVat(VatRegNo: Code[20]; IssueCode: Code[50]): Integer
    var
        Customer: Record Customer;
        Count: Integer;
    begin
        Customer.SetRange("VAT Registration No.", VatRegNo);
        if Customer.FindSet() then
            repeat
                if not IsCustomerDuplicateExcluded(Customer, IssueCode) then
                    Count += 1;
            until Customer.Next() = 0;

        exit(Count);
    end;

    local procedure CountVendorsByVat(VatRegNo: Code[20]; IssueCode: Code[50]): Integer
    var
        Vendor: Record Vendor;
        Count: Integer;
    begin
        Vendor.SetRange("VAT Registration No.", VatRegNo);
        if Vendor.FindSet() then
            repeat
                if not IsVendorDuplicateExcluded(Vendor, IssueCode) then
                    Count += 1;
            until Vendor.Next() = 0;

        exit(Count);
    end;

    local procedure CountCustomersByNamePostCity(NameValue: Text[100]; PostCode: Code[20]; CityValue: Text[30]; IssueCode: Code[50]): Integer
    var
        Customer: Record Customer;
        Count: Integer;
    begin
        Customer.SetRange(Name, NameValue);
        Customer.SetRange("Post Code", PostCode);
        Customer.SetRange(City, CityValue);
        if Customer.FindSet() then
            repeat
                if not IsCustomerDuplicateExcluded(Customer, IssueCode) then
                    Count += 1;
            until Customer.Next() = 0;

        exit(Count);
    end;

    local procedure CountVendorsByNamePostCity(NameValue: Text[100]; PostCode: Code[20]; CityValue: Text[30]; IssueCode: Code[50]): Integer
    var
        Vendor: Record Vendor;
        Count: Integer;
    begin
        Vendor.SetRange(Name, NameValue);
        Vendor.SetRange("Post Code", PostCode);
        Vendor.SetRange(City, CityValue);
        if Vendor.FindSet() then
            repeat
                if not IsVendorDuplicateExcluded(Vendor, IssueCode) then
                    Count += 1;
            until Vendor.Next() = 0;

        exit(Count);
    end;

    local procedure IsCustomerDuplicateExcluded(var Customer: Record Customer; IssueCode: Code[50]): Boolean
    var
        ExceptionMgt: Codeunit "DH Exception Mgt.";
    begin
        exit(ExceptionMgt.IsCustomerIssueExcluded(Customer, IssueCode));
    end;

    local procedure IsVendorDuplicateExcluded(var Vendor: Record Vendor; IssueCode: Code[50]): Boolean
    var
        ExceptionMgt: Codeunit "DH Exception Mgt.";
    begin
        exit(ExceptionMgt.IsVendorIssueExcluded(Vendor, IssueCode));
    end;

    local procedure AddCountFinding(var DeepScanRun: Record "DH Deep Scan Run"; var Score: Integer; var IssuesCount: Integer; Category: Code[30]; IssueCode: Code[50]; Title: Text[150]; Severity: Code[20]; AffectedCount: Integer; RecommendationPreview: Text[250]; PenaltyPoints: Integer)
    begin
        if AffectedCount <= 0 then
            exit;

        InsertFinding(
            DeepScanRun."Entry No.",
            Category,
            IssueCode,
            Title,
            Severity,
            AffectedCount,
            RecommendationPreview);

        IssuesCount += 1;
        ApplyPenalty(Score, PenaltyPoints);
    end;

    local procedure ApplyPenalty(var Score: Integer; PenaltyPoints: Integer)
    begin
        Score -= PenaltyPoints;
        if Score < 0 then
            Score := 0;
    end;

    local procedure HasOpenSalesDocumentsForCustomer(CustomerNo: Code[20]): Boolean
    var
        SalesHeader: Record "Sales Header";
    begin
        SalesHeader.Reset();
        SalesHeader.SetRange("Sell-to Customer No.", CustomerNo);
        SalesHeader.SetFilter("Document Type", '%1|%2|%3', SalesHeader."Document Type"::Quote, SalesHeader."Document Type"::Order, SalesHeader."Document Type"::Invoice);
        exit(not SalesHeader.IsEmpty());
    end;

    local procedure HasOpenPurchaseDocumentsForVendor(VendorNo: Code[20]): Boolean
    var
        PurchaseHeader: Record "Purchase Header";
    begin
        PurchaseHeader.Reset();
        PurchaseHeader.SetRange("Buy-from Vendor No.", VendorNo);
        PurchaseHeader.SetFilter("Document Type", '%1|%2|%3', PurchaseHeader."Document Type"::Quote, PurchaseHeader."Document Type"::Order, PurchaseHeader."Document Type"::Invoice);
        exit(not PurchaseHeader.IsEmpty());
    end;

    local procedure HasOpenCustomerLedgerEntries(CustomerNo: Code[20]): Boolean
    var
        CustLedgerEntry: Record "Cust. Ledger Entry";
    begin
        CustLedgerEntry.Reset();
        CustLedgerEntry.SetRange("Customer No.", CustomerNo);
        CustLedgerEntry.SetRange(Open, true);
        exit(not CustLedgerEntry.IsEmpty());
    end;

    local procedure HasOpenVendorLedgerEntries(VendorNo: Code[20]): Boolean
    var
        VendorLedgerEntry: Record "Vendor Ledger Entry";
    begin
        VendorLedgerEntry.Reset();
        VendorLedgerEntry.SetRange("Vendor No.", VendorNo);
        VendorLedgerEntry.SetRange(Open, true);
        exit(not VendorLedgerEntry.IsEmpty());
    end;

    local procedure EnsureDashboardHeaderForDeepScan(var DeepScanRun: Record "DH Deep Scan Run")
    var
        ScanHeader: Record "DH Scan Header";
    begin
        ScanHeader.Reset();
        ScanHeader.SetRange("Scan Type", ScanHeader."Scan Type"::Deep);
        ScanHeader.SetRange("Backend Scan Id", DeepScanRun."Run ID");

        if not ScanHeader.FindFirst() then begin
            ScanHeader.Init();
            ScanHeader."Entry No." := GetNextHeaderEntryNo();
            ScanHeader."Scan Type" := ScanHeader."Scan Type"::Deep;
            ScanHeader."Backend Scan Id" := DeepScanRun."Run ID";
            ScanHeader.Insert();
        end;

        if DeepScanRun."Finished At" <> 0DT then
            ScanHeader."Scan DateTime" := DeepScanRun."Finished At"
        else
            ScanHeader."Scan DateTime" := DeepScanRun."Requested At";

        ScanHeader."Data Score" := DeepScanRun."Deep Score";
        ScanHeader."Checks Count" := DeepScanRun."Checks Count";
        ScanHeader."Issues Count" := DeepScanRun."Issues Count";
        ScanHeader."Headline" := CopyStr(DeepScanRun."Headline", 1, MaxStrLen(ScanHeader."Headline"));
        ScanHeader."Rating" := CopyStr(DeepScanRun."Rating", 1, MaxStrLen(ScanHeader."Rating"));
        ScanHeader."Premium Available" := true;
        ScanHeader.Modify(true);
    end;

    local procedure BuildSyncPayload(var Setup: Record "DH Setup"; var DeepScanRun: Record "DH Deep Scan Run"): Text
    var
        Finding: Record "DH Deep Scan Finding";
        Payload: JsonObject;
        IssuesArray: JsonArray;
        IssueObject: JsonObject;
        ScanDateTime: DateTime;
        RequestText: Text;
    begin
        if DeepScanRun."Finished At" <> 0DT then
            ScanDateTime := DeepScanRun."Finished At"
        else
            ScanDateTime := DeepScanRun."Requested At";

        Payload.Add('tenant_id', Setup."Tenant ID");
        Payload.Add('scan_id', Format(DeepScanRun."Run ID"));
        Payload.Add('scan_type', 'deep');
        Payload.Add('generated_at_utc', Format(ScanDateTime, 0, 9));
        Payload.Add('data_score', DeepScanRun."Deep Score");
        Payload.Add('checks_count', DeepScanRun."Checks Count");
        Payload.Add('issues_count', DeepScanRun."Issues Count");
        Payload.Add('premium_available', true);
        Payload.Add('headline', DeepScanRun."Headline");
        Payload.Add('rating', DeepScanRun."Rating");

        Finding.Reset();
        Finding.SetRange("Deep Scan Entry No.", DeepScanRun."Entry No.");
        if Finding.FindSet() then
            repeat
                Clear(IssueObject);
                IssueObject.Add('code', Format(Finding."Issue Code"));
                IssueObject.Add('title', Finding.Title);
                IssueObject.Add('severity', LowerCase(Format(Finding.Severity)));
                IssueObject.Add('affected_count', Finding."Affected Count");
                IssueObject.Add('premium_only', Finding."Premium Only");
                IssueObject.Add('recommendation_preview', Finding."Recommendation Preview");
                IssuesArray.Add(IssueObject);
            until Finding.Next() = 0;

        Payload.Add('issues', IssuesArray);
        Payload.WriteTo(RequestText);
        exit(RequestText);
    end;

    local procedure InsertFinding(DeepScanEntryNo: Integer; Category: Code[30]; IssueCode: Code[50]; Title: Text[150]; Severity: Code[20]; AffectedCount: Integer; RecommendationPreview: Text[250])
    var
        Finding: Record "DH Deep Scan Finding";
    begin
        Finding.Init();
        Finding."Entry No." := GetNextFindingEntryNo();
        Finding."Deep Scan Entry No." := DeepScanEntryNo;
        Finding.Category := Category;
        Finding."Issue Code" := IssueCode;
        Finding.Title := CopyStr(Title, 1, MaxStrLen(Finding.Title));
        Finding.Severity := Severity;
        Finding."Severity Sort Order" := GetSeveritySortOrder(Finding.Severity);
        Finding."Affected Count" := AffectedCount;
        Finding."Affected Count Sort Value" := -AffectedCount;
        Finding."Recommendation Preview" := CopyStr(RecommendationPreview, 1, MaxStrLen(Finding."Recommendation Preview"));
        Finding."Premium Only" := true;
        Finding.Insert(true);
    end;

    local procedure FindingExists(DeepScanEntryNo: Integer; IssueCode: Code[50]; ValueMarker: Text): Boolean
    var
        Finding: Record "DH Deep Scan Finding";
    begin
        Finding.SetRange("Deep Scan Entry No.", DeepScanEntryNo);
        Finding.SetRange("Issue Code", IssueCode);
        Finding.SetFilter(Title, '*%1*', ValueMarker);
        exit(not Finding.IsEmpty());
    end;

    local procedure GetNextFindingEntryNo(): Integer
    var
        Finding: Record "DH Deep Scan Finding";
    begin
        if Finding.FindLast() then
            exit(Finding."Entry No." + 1);

        exit(1);
    end;

    local procedure GetNextHeaderEntryNo(): Integer
    var
        ScanHeader: Record "DH Scan Header";
    begin
        if ScanHeader.FindLast() then
            exit(ScanHeader."Entry No." + 1);

        exit(1);
    end;

    local procedure GetRating(Score: Integer): Text
    begin
        if Score >= 90 then
            exit('good');

        if Score >= 75 then
            exit('fair');

        exit('critical');
    end;

    local procedure GetHeadline(Score: Integer; IssuesCount: Integer): Text
    begin
        if IssuesCount = 0 then
            exit('Deep scan completed without findings.');

        if Score >= 90 then
            exit('Deep scan completed with minor findings.');

        if Score >= 75 then
            exit('Deep scan completed with relevant improvement potential.');

        exit('Deep scan completed with critical findings.');
    end;


    local procedure GetSeveritySortOrder(SeverityValue: Code[20]): Integer
    begin
        case LowerCase(SeverityValue) of
            'high':
                exit(1);
            'medium':
                exit(2);
            'low':
                exit(3);
        end;

        exit(99);
    end;
}
