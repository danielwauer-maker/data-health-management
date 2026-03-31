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
        SyncResponseText: Text;
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
        DeepScanRun."Current Module" := 'Initializing';
        DeepScanRun."Progress %" := 0;
        DeepScanRun."Completed Modules" := 0;
        DeepScanRun."ETA Text" := 'Calculating...';
        DeepScanRun.Modify(true);
        Commit();

        RunChecks(DeepScanRun, Score, ChecksCount, IssuesCount);

        DeepScanRun.Get(DeepScanRun."Entry No.");
        RecalculateScoreMetrics(DeepScanRun, Score);
        ClearDeepScanCommercials(DeepScanRun);
        DeepScanRun."Deep Score" := Score;
        DeepScanRun."Checks Count" := ChecksCount;
        DeepScanRun."Issues Count" := IssuesCount;
        DeepScanRun."Rating" := CopyStr(GetRating(Score), 1, MaxStrLen(DeepScanRun."Rating"));
        DeepScanRun."Headline" := CopyStr(GetHeadline(Score, IssuesCount), 1, MaxStrLen(DeepScanRun."Headline"));
        DeepScanRun.Status := DeepScanRun.Status::Completed;
        DeepScanRun."Finished At" := CurrentDateTime();
        DeepScanRun."Current Module" := 'Completed';
        DeepScanRun."Progress %" := 100;
        DeepScanRun."Completed Modules" := DeepScanRun."Total Modules";
        DeepScanRun."ETA Text" := 'Completed';
        DeepScanRun."System Progress %" := 100;
        DeepScanRun."Finance Progress %" := 100;
        DeepScanRun."Sales Progress %" := 100;
        DeepScanRun."Purchasing Progress %" := 100;
        DeepScanRun."Inventory Progress %" := 100;
        DeepScanRun."CRM Progress %" := 100;
        DeepScanRun."Manufacturing Progress %" := 100;
        DeepScanRun."Service Progress %" := 100;
        DeepScanRun."Jobs Progress %" := 100;
        DeepScanRun."HR Progress %" := 100;
        DeepScanRun.Modify(true);

        EnsureDashboardHeaderForDeepScan(DeepScanRun);
        Commit();

        if Setup.Get('SETUP') then begin
            RequestText := BuildSyncPayload(Setup, DeepScanRun);
            SyncResponseText := ApiClient.SyncScanToBackendAndGetResponse(Setup, RequestText);
            ApplySyncCommercials(DeepScanRun, SyncResponseText);
            ApplySyncFindingImpacts(DeepScanRun, SyncResponseText);
        end;
    end;

    local procedure RunChecks(var DeepScanRun: Record "DH Deep Scan Run"; var Score: Integer; var ChecksCount: Integer; var IssuesCount: Integer)
    var
        Setup: Record "DH Setup";
        ModuleNo: Integer;
        TotalModules: Integer;
    begin
        Score := 100;
        ChecksCount := 0;
        IssuesCount := 0;
        ModuleNo := 0;

        if Setup.Get('SETUP') then
            Setup.ApplyDefaults()
        else begin
            Setup.Init();
            Setup."Scan System Module" := true;
            Setup."Scan Finance Module" := true;
            Setup."Scan Sales Module" := true;
            Setup."Scan Purchasing Module" := true;
            Setup."Scan Inventory Module" := true;
            Setup."Scan CRM Module" := true;
            Setup."Scan Manufacturing Module" := true;
            Setup."Scan Service Module" := true;
            Setup."Scan Jobs Module" := true;
            Setup."Scan HR Module" := true;
        end;

        TotalModules := GetEnabledModuleCount(Setup);
        InitializeProgress(DeepScanRun, TotalModules);

        if IsModuleEnabled(Setup, 'System') then begin
            ModuleNo += 1;
            StartModule(DeepScanRun, 'System', ModuleNo);
            RunSystemConfigurationChecks(DeepScanRun, Score, ChecksCount, IssuesCount);
            CompleteModule(DeepScanRun, 'System', ModuleNo);
        end;

        if IsModuleEnabled(Setup, 'Finance') then begin
            ModuleNo += 1;
            StartModule(DeepScanRun, 'Finance', ModuleNo);
            RunCustomerMasterDataChecks(DeepScanRun, Score, ChecksCount, IssuesCount);
            RunVendorMasterDataChecks(DeepScanRun, Score, ChecksCount, IssuesCount);
            RunCustomerDuplicateEmailCheck(DeepScanRun, Score, ChecksCount, IssuesCount);
            RunVendorDuplicateEmailCheck(DeepScanRun, Score, ChecksCount, IssuesCount);
            RunCustomerDuplicateVatCheck(DeepScanRun, Score, ChecksCount, IssuesCount);
            RunVendorDuplicateVatCheck(DeepScanRun, Score, ChecksCount, IssuesCount);
            RunCustomerDuplicateNamePostCodeCityCheck(DeepScanRun, Score, ChecksCount, IssuesCount);
            RunVendorDuplicateNamePostCodeCityCheck(DeepScanRun, Score, ChecksCount, IssuesCount);
            RunLedgerAgingChecks(DeepScanRun, Score, ChecksCount, IssuesCount);
            RunFinanceCommercialChecks(DeepScanRun, Score, ChecksCount, IssuesCount);
            CompleteModule(DeepScanRun, 'Finance', ModuleNo);
        end;

        if IsModuleEnabled(Setup, 'Sales') then begin
            ModuleNo += 1;
            StartModule(DeepScanRun, 'Sales', ModuleNo);
            RunSalesDocumentQualityChecks(DeepScanRun, Score, ChecksCount, IssuesCount);
            RunSalesExecutionChecks(DeepScanRun, Score, ChecksCount, IssuesCount);
            CompleteModule(DeepScanRun, 'Sales', ModuleNo);
        end;

        if IsModuleEnabled(Setup, 'Purchasing') then begin
            ModuleNo += 1;
            StartModule(DeepScanRun, 'Purchasing', ModuleNo);
            RunPurchaseDocumentQualityChecks(DeepScanRun, Score, ChecksCount, IssuesCount);
            RunPurchaseExecutionChecks(DeepScanRun, Score, ChecksCount, IssuesCount);
            CompleteModule(DeepScanRun, 'Purchasing', ModuleNo);
        end;

        if IsModuleEnabled(Setup, 'Inventory') then begin
            ModuleNo += 1;
            StartModule(DeepScanRun, 'Inventory', ModuleNo);
            RunItemMasterDataChecks(DeepScanRun, Score, ChecksCount, IssuesCount);
            RunInventoryValueChecks(DeepScanRun, Score, ChecksCount, IssuesCount);
            CompleteModule(DeepScanRun, 'Inventory', ModuleNo);
        end;

        if IsModuleEnabled(Setup, 'CRM') then begin
            ModuleNo += 1;
            StartModule(DeepScanRun, 'CRM', ModuleNo);
            RunCRMContactChecks(DeepScanRun, Score, ChecksCount, IssuesCount);
            CompleteModule(DeepScanRun, 'CRM', ModuleNo);
        end;

        if IsModuleEnabled(Setup, 'Manufacturing') then begin
            ModuleNo += 1;
            StartModule(DeepScanRun, 'Manufacturing', ModuleNo);
            RunManufacturingChecks(DeepScanRun, Score, ChecksCount, IssuesCount);
            CompleteModule(DeepScanRun, 'Manufacturing', ModuleNo);
        end;

        if IsModuleEnabled(Setup, 'Service') then begin
            ModuleNo += 1;
            StartModule(DeepScanRun, 'Service', ModuleNo);
            RunServiceChecks(DeepScanRun, Score, ChecksCount, IssuesCount);
            CompleteModule(DeepScanRun, 'Service', ModuleNo);
        end;

        if IsModuleEnabled(Setup, 'Jobs') then begin
            ModuleNo += 1;
            StartModule(DeepScanRun, 'Jobs', ModuleNo);
            RunJobsChecks(DeepScanRun, Score, ChecksCount, IssuesCount);
            CompleteModule(DeepScanRun, 'Jobs', ModuleNo);
        end;

        if IsModuleEnabled(Setup, 'HR') then begin
            ModuleNo += 1;
            StartModule(DeepScanRun, 'HR', ModuleNo);
            RunHRChecks(DeepScanRun, Score, ChecksCount, IssuesCount);
            CompleteModule(DeepScanRun, 'HR', ModuleNo);
        end;

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

    local procedure RunSystemConfigurationChecks(var DeepScanRun: Record "DH Deep Scan Run"; var Score: Integer; var ChecksCount: Integer; var IssuesCount: Integer)
    var
        GLEntry: Record "G/L Entry";
        GLAccount: Record "G/L Account";
        Customer: Record Customer;
        Vendor: Record Vendor;
        Item: Record Item;
        MissingDim1: Integer;
        MissingDim2: Integer;
        MissingBothDims: Integer;
        AccountsBlockedButUsed: Integer;
        AccountsWithoutDirectPostingButUsed: Integer;
        CustomersWithoutGenBusPosting: Integer;
        CustomersWithoutVatBusPosting: Integer;
        VendorsWithoutGenBusPosting: Integer;
        VendorsWithoutVatBusPosting: Integer;
        ItemsWithoutGenProdPosting: Integer;
        ItemsWithoutInventoryPosting: Integer;
        CustLedgerWithoutDueDate: Integer;
        VendLedgerWithoutDueDate: Integer;
        CustLedgerEntry: Record "Cust. Ledger Entry";
        VendorLedgerEntry: Record "Vendor Ledger Entry";
    begin
        ChecksCount += 14;

        GLEntry.Reset();
        if GLEntry.FindSet() then
            repeat
                if GLEntry."Global Dimension 1 Code" = '' then
                    MissingDim1 += 1;
                if GLEntry."Global Dimension 2 Code" = '' then
                    MissingDim2 += 1;
                if (GLEntry."Global Dimension 1 Code" = '') and (GLEntry."Global Dimension 2 Code" = '') then
                    MissingBothDims += 1;
            until GLEntry.Next() = 0;

        GLAccount.Reset();
        if GLAccount.FindSet() then
            repeat
                if GLAccount.Blocked and HasGLEntriesForAccount(GLAccount."No.") then
                    AccountsBlockedButUsed += 1;
                if (not GLAccount."Direct Posting") and HasGLEntriesForAccount(GLAccount."No.") then
                    AccountsWithoutDirectPostingButUsed += 1;
            until GLAccount.Next() = 0;

        Customer.Reset();
        if Customer.FindSet() then
            repeat
                if Customer."Gen. Bus. Posting Group" = '' then
                    CustomersWithoutGenBusPosting += 1;
                if Customer."VAT Bus. Posting Group" = '' then
                    CustomersWithoutVatBusPosting += 1;
            until Customer.Next() = 0;

        Vendor.Reset();
        if Vendor.FindSet() then
            repeat
                if Vendor."Gen. Bus. Posting Group" = '' then
                    VendorsWithoutGenBusPosting += 1;
                if Vendor."VAT Bus. Posting Group" = '' then
                    VendorsWithoutVatBusPosting += 1;
            until Vendor.Next() = 0;

        Item.Reset();
        if Item.FindSet() then
            repeat
                if Item."Gen. Prod. Posting Group" = '' then
                    ItemsWithoutGenProdPosting += 1;
                if Item."Inventory Posting Group" = '' then
                    ItemsWithoutInventoryPosting += 1;
            until Item.Next() = 0;

        CustLedgerEntry.SetRange(Open, true);
        CustLedgerEntry.SetRange("Due Date", 0D);
        CustLedgerWithoutDueDate := CustLedgerEntry.Count();

        VendorLedgerEntry.SetRange(Open, true);
        VendorLedgerEntry.SetRange("Due Date", 0D);
        VendLedgerWithoutDueDate := VendorLedgerEntry.Count();

        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SYSTEM', 'GL_ENTRIES_MISSING_DIM1', 'Sachposten ohne Dimension 1', 'medium', MissingDim1, 'Dimension 1 in den relevanten Buchungsprozessen pflegen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SYSTEM', 'GL_ENTRIES_MISSING_DIM2', 'Sachposten ohne Dimension 2', 'medium', MissingDim2, 'Dimension 2 in den relevanten Buchungsprozessen pflegen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SYSTEM', 'GL_ENTRIES_MISSING_BOTH_DIMS', 'Sachposten ohne beide Dimensionen', 'high', MissingBothDims, 'Buchungslogik für Dimensionen konsequent vervollständigen.', 6);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SYSTEM', 'GL_ACCOUNTS_BLOCKED_BUT_USED', 'Gesperrte Sachkonten mit Buchungen', 'high', AccountsBlockedButUsed, 'Sperrstatus und Kontennutzung fachlich bereinigen.', 5);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SYSTEM', 'GL_ACCOUNTS_NO_DIRECT_POSTING_BUT_USED', 'Sachkonten ohne Direktbuchung mit Buchungen', 'medium', AccountsWithoutDirectPostingButUsed, 'Direktbuchungslogik und Kontenstammdaten abstimmen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SYSTEM', 'SYSTEM_CUSTOMERS_MISSING_GEN_BUS_POSTING', 'Kunden ohne Geschäftsbuchungsgruppe', 'high', CustomersWithoutGenBusPosting, 'Geschäftsbuchungsgruppen bei Debitoren pflegen.', 4);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SYSTEM', 'SYSTEM_CUSTOMERS_MISSING_VAT_BUS_POSTING', 'Kunden ohne MwSt.-Geschäftsbuchungsgruppe', 'high', CustomersWithoutVatBusPosting, 'MwSt.-Geschäftsbuchungsgruppen bei Debitoren ergänzen.', 4);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SYSTEM', 'SYSTEM_VENDORS_MISSING_GEN_BUS_POSTING', 'Lieferanten ohne Geschäftsbuchungsgruppe', 'high', VendorsWithoutGenBusPosting, 'Geschäftsbuchungsgruppen bei Kreditoren pflegen.', 4);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SYSTEM', 'SYSTEM_VENDORS_MISSING_VAT_BUS_POSTING', 'Lieferanten ohne MwSt.-Geschäftsbuchungsgruppe', 'high', VendorsWithoutVatBusPosting, 'MwSt.-Geschäftsbuchungsgruppen bei Kreditoren ergänzen.', 4);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SYSTEM', 'SYSTEM_ITEMS_MISSING_GEN_PROD_POSTING', 'Artikel ohne Produktbuchungsgruppe', 'high', ItemsWithoutGenProdPosting, 'Produktbuchungsgruppen bei Artikeln pflegen.', 4);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SYSTEM', 'SYSTEM_ITEMS_MISSING_INVENTORY_POSTING', 'Artikel ohne Lagerbuchungsgruppe', 'high', ItemsWithoutInventoryPosting, 'Lagerbuchungsgruppen bei Artikeln pflegen.', 4);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SYSTEM', 'CUSTOMER_LEDGER_MISSING_DUE_DATE', 'Offene Debitorenposten ohne Fälligkeitsdatum', 'medium', CustLedgerWithoutDueDate, 'Fälligkeitsdaten in Debitorenposten und Zahlungsbedingungen prüfen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SYSTEM', 'VENDOR_LEDGER_MISSING_DUE_DATE', 'Offene Kreditorenposten ohne Fälligkeitsdatum', 'medium', VendLedgerWithoutDueDate, 'Fälligkeitsdaten in Kreditorenposten und Zahlungsbedingungen prüfen.', 3);
    end;

    local procedure RunFinanceCommercialChecks(var DeepScanRun: Record "DH Deep Scan Run"; var Score: Integer; var ChecksCount: Integer; var IssuesCount: Integer)
    var
        Customer: Record Customer;
        Vendor: Record Vendor;
        CustLedgerEntry: Record "Cust. Ledger Entry";
        VendorLedgerEntry: Record "Vendor Ledger Entry";
        CustomerMissingVat: Integer;
        CustomerMissingSalesperson: Integer;
        CustomerMissingPriceGroup: Integer;
        CustomerMissingDiscGroup: Integer;
        CustomerMissingReminderTerms: Integer;
        CustomerMissingFinChargeTerms: Integer;
        CustomerMissingContact: Integer;
        CustomerMissingHomePage: Integer;
        VendorMissingVat: Integer;
        VendorMissingPurchaser: Integer;
        VendorMissingContact: Integer;
        VendorMissingHomePage: Integer;
        CustomerOverdue60: Integer;
        CustomerOverdue90: Integer;
        VendorOverdue60: Integer;
        VendorOverdue90: Integer;
    begin
        ChecksCount += 16;

        if Customer.FindSet() then
            repeat
                if Customer."VAT Registration No." = '' then
                    CustomerMissingVat += 1;
                if Customer."Salesperson Code" = '' then
                    CustomerMissingSalesperson += 1;
                if Customer."Customer Price Group" = '' then
                    CustomerMissingPriceGroup += 1;
                if Customer."Customer Disc. Group" = '' then
                    CustomerMissingDiscGroup += 1;
                if Customer."Reminder Terms Code" = '' then
                    CustomerMissingReminderTerms += 1;
                if Customer."Fin. Charge Terms Code" = '' then
                    CustomerMissingFinChargeTerms += 1;
                if Customer.Contact = '' then
                    CustomerMissingContact += 1;
                if Customer."Home Page" = '' then
                    CustomerMissingHomePage += 1;
            until Customer.Next() = 0;

        if Vendor.FindSet() then
            repeat
                if Vendor."VAT Registration No." = '' then
                    VendorMissingVat += 1;
                if Vendor."Purchaser Code" = '' then
                    VendorMissingPurchaser += 1;
                if Vendor.Contact = '' then
                    VendorMissingContact += 1;
                if Vendor."Home Page" = '' then
                    VendorMissingHomePage += 1;
            until Vendor.Next() = 0;

        CustLedgerEntry.SetRange(Open, true);
        CustLedgerEntry.SetFilter("Due Date", '<>%1&<=%2', 0D, CalcDate('<-60D>', Today()));
        CustomerOverdue60 := CustLedgerEntry.Count();
        CustLedgerEntry.SetRange("Due Date");
        CustLedgerEntry.SetFilter("Due Date", '<>%1&<=%2', 0D, CalcDate('<-90D>', Today()));
        CustomerOverdue90 := CustLedgerEntry.Count();

        VendorLedgerEntry.SetRange(Open, true);
        VendorLedgerEntry.SetFilter("Due Date", '<>%1&<=%2', 0D, CalcDate('<-60D>', Today()));
        VendorOverdue60 := VendorLedgerEntry.Count();
        VendorLedgerEntry.SetRange("Due Date");
        VendorLedgerEntry.SetFilter("Due Date", '<>%1&<=%2', 0D, CalcDate('<-90D>', Today()));
        VendorOverdue90 := VendorLedgerEntry.Count();

        AddCountFinding(DeepScanRun, Score, IssuesCount, 'FINANCE', 'CUSTOMERS_MISSING_VAT_REG_NO', 'Kunden ohne USt-IdNr.', 'medium', CustomerMissingVat, 'USt-IdNr. bei betroffenen Kunden ergänzen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'FINANCE', 'CUSTOMERS_MISSING_SALESPERSON', 'Kunden ohne Verkäufercode', 'low', CustomerMissingSalesperson, 'Verantwortliche Verkäufer zuordnen.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'FINANCE', 'CUSTOMERS_MISSING_PRICE_GROUP', 'Kunden ohne Preisgruppe', 'medium', CustomerMissingPriceGroup, 'Preisgruppen pflegen, um saubere Preisfindung sicherzustellen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'FINANCE', 'CUSTOMERS_MISSING_DISC_GROUP', 'Kunden ohne Rabattgruppe', 'medium', CustomerMissingDiscGroup, 'Rabattgruppen pflegen, um Margenverluste zu vermeiden.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'FINANCE', 'CUSTOMERS_MISSING_REMINDER_TERMS', 'Kunden ohne Mahnbedingungen', 'medium', CustomerMissingReminderTerms, 'Mahnbedingungen für Forderungsmanagement pflegen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'FINANCE', 'CUSTOMERS_MISSING_FIN_CHARGE_TERMS', 'Kunden ohne Verzugszinsbedingungen', 'low', CustomerMissingFinChargeTerms, 'Verzugszinsbedingungen prüfen und pflegen.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'FINANCE', 'CUSTOMERS_MISSING_CONTACT', 'Kunden ohne Ansprechpartner', 'low', CustomerMissingContact, 'Ansprechpartner in den Debitorenstammdaten ergänzen.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'FINANCE', 'CUSTOMERS_MISSING_HOME_PAGE', 'Kunden ohne Website', 'low', CustomerMissingHomePage, 'Webseiten nur pflegen, wenn fachlich gewünscht.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'FINANCE', 'VENDORS_MISSING_VAT_REG_NO', 'Lieferanten ohne USt-IdNr.', 'medium', VendorMissingVat, 'USt-IdNr. bei Lieferanten ergänzen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'FINANCE', 'VENDORS_MISSING_PURCHASER', 'Lieferanten ohne Einkäufercode', 'low', VendorMissingPurchaser, 'Verantwortliche Einkäufer zuordnen.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'FINANCE', 'VENDORS_MISSING_CONTACT', 'Lieferanten ohne Ansprechpartner', 'low', VendorMissingContact, 'Ansprechpartner in den Kreditorenstammdaten ergänzen.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'FINANCE', 'VENDORS_MISSING_HOME_PAGE', 'Lieferanten ohne Website', 'low', VendorMissingHomePage, 'Webseiten nur pflegen, wenn fachlich gewünscht.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'FINANCE', 'CUSTOMER_LEDGER_OVERDUE_60', 'Offene Debitorenposten überfällig > 60 Tage', 'high', CustomerOverdue60, 'Überfällige Forderungen aktiv nachverfolgen.', 4);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'FINANCE', 'CUSTOMER_LEDGER_OVERDUE_90', 'Offene Debitorenposten überfällig > 90 Tage', 'high', CustomerOverdue90, 'Kritische Außenstände priorisiert bearbeiten.', 5);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'FINANCE', 'VENDOR_LEDGER_OVERDUE_60', 'Offene Kreditorenposten überfällig > 60 Tage', 'medium', VendorOverdue60, 'Fällige Kreditorenzahlungen und Prozessengpässe prüfen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'FINANCE', 'VENDOR_LEDGER_OVERDUE_90', 'Offene Kreditorenposten überfällig > 90 Tage', 'medium', VendorOverdue90, 'Kritische Kreditorenposten und Eskalationsrisiken prüfen.', 4);
    end;

    local procedure RunSalesExecutionChecks(var DeepScanRun: Record "DH Deep Scan Run"; var Score: Integer; var ChecksCount: Integer; var IssuesCount: Integer)
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        Item: Record Item;
        MissingPaymentTerms: Integer;
        MissingPaymentMethod: Integer;
        MissingRequestedDeliveryDate: Integer;
        MissingShipmentMethod: Integer;
        MissingExternalDocumentNo: Integer;
        PastDueRequestedDeliveryDate: Integer;
        DiscountAbove25: Integer;
        DiscountAbove50: Integer;
        BelowUnitCost: Integer;
        ShippedNotInvoiced: Integer;
        OutstandingPastShipmentDate: Integer;
        MissingDescription: Integer;
        MissingLocationCode: Integer;
    begin
        ChecksCount += 13;

        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        if SalesHeader.FindSet() then
            repeat
                if SalesHeader."Payment Terms Code" = '' then
                    MissingPaymentTerms += 1;
                if SalesHeader."Payment Method Code" = '' then
                    MissingPaymentMethod += 1;
                if SalesHeader."Requested Delivery Date" = 0D then
                    MissingRequestedDeliveryDate += 1;
                if SalesHeader."Shipment Method Code" = '' then
                    MissingShipmentMethod += 1;
                if SalesHeader."External Document No." = '' then
                    MissingExternalDocumentNo += 1;
                if (SalesHeader."Requested Delivery Date" <> 0D) and (SalesHeader."Requested Delivery Date" < Today()) then
                    PastDueRequestedDeliveryDate += 1;
            until SalesHeader.Next() = 0;

        SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
        if SalesLine.FindSet() then
            repeat
                if SalesLine."Line Discount %" > 25 then
                    DiscountAbove25 += 1;
                if SalesLine."Line Discount %" > 50 then
                    DiscountAbove50 += 1;
                if (SalesLine.Type = SalesLine.Type::Item) and (SalesLine."No." <> '') then begin
                    if Item.Get(SalesLine."No.") then
                        if SalesLine."Unit Price" < Item."Unit Cost" then
                            BelowUnitCost += 1;
                end;
                if SalesLine."Quantity Shipped" > SalesLine."Quantity Invoiced" then
                    ShippedNotInvoiced += 1;
                if (SalesLine."Outstanding Quantity" > 0) and (SalesLine."Shipment Date" <> 0D) and (SalesLine."Shipment Date" < Today()) then
                    OutstandingPastShipmentDate += 1;
                if SalesLine.Description = '' then
                    MissingDescription += 1;
                if SalesLine."Location Code" = '' then
                    MissingLocationCode += 1;
            until SalesLine.Next() = 0;

        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SALES', 'SALES_HEADERS_MISSING_PAYMENT_TERMS', 'Verkaufsaufträge ohne Zahlungsbedingungen', 'medium', MissingPaymentTerms, 'Zahlungsbedingungen in offenen Verkaufsaufträgen ergänzen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SALES', 'SALES_HEADERS_MISSING_PAYMENT_METHOD', 'Verkaufsaufträge ohne Zahlungsform', 'medium', MissingPaymentMethod, 'Zahlungsform in offenen Verkaufsaufträgen ergänzen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SALES', 'SALES_HEADERS_MISSING_REQUESTED_DELIVERY_DATE', 'Verkaufsaufträge ohne Wunschlieferdatum', 'medium', MissingRequestedDeliveryDate, 'Wunschlieferdaten in offenen Aufträgen pflegen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SALES', 'SALES_HEADERS_MISSING_SHIPMENT_METHOD', 'Verkaufsaufträge ohne Versandart', 'low', MissingShipmentMethod, 'Versandart in offenen Aufträgen ergänzen.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SALES', 'SALES_HEADERS_MISSING_EXTERNAL_DOC_NO', 'Verkaufsaufträge ohne externen Belegbezug', 'low', MissingExternalDocumentNo, 'Externen Belegbezug ergänzen, sofern fachlich erforderlich.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SALES', 'SALES_HEADERS_PAST_REQUESTED_DELIVERY_DATE', 'Verkaufsaufträge mit überfälligem Wunschlieferdatum', 'high', PastDueRequestedDeliveryDate, 'Überfällige Aufträge terminlich bereinigen und aktiv nachverfolgen.', 4);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SALES', 'SALES_LINES_DISCOUNT_OVER_25', 'Verkaufszeilen mit Rabatt > 25%', 'medium', DiscountAbove25, 'Rabatte und Preisfreigaben prüfen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SALES', 'SALES_LINES_DISCOUNT_OVER_50', 'Verkaufszeilen mit Rabatt > 50%', 'high', DiscountAbove50, 'Kritische Rabatte priorisiert prüfen.', 4);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SALES', 'SALES_LINES_PRICE_BELOW_UNIT_COST', 'Verkaufszeilen unter Einstandspreis', 'high', BelowUnitCost, 'Preisfindung und Marge auf betroffenen Verkaufszeilen prüfen.', 6);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SALES', 'SALES_LINES_SHIPPED_NOT_INVOICED', 'Gelieferte, aber nicht fakturierte Verkaufszeilen', 'high', ShippedNotInvoiced, 'Lieferungen zeitnah abrechnen, um Umsatz nicht liegen zu lassen.', 6);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SALES', 'SALES_LINES_OUTSTANDING_PAST_SHIPMENT_DATE', 'Offene Verkaufszeilen mit überfälligem Lieferdatum', 'medium', OutstandingPastShipmentDate, 'Offene Mengen und Liefertermine bereinigen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SALES', 'SALES_LINES_MISSING_DESCRIPTION', 'Verkaufszeilen ohne Beschreibung', 'low', MissingDescription, 'Beschreibung in Verkaufszeilen ergänzen.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SALES', 'SALES_LINES_MISSING_LOCATION', 'Verkaufszeilen ohne Lagerort', 'medium', MissingLocationCode, 'Lagerort in Verkaufszeilen ergänzen.', 2);
    end;

    local procedure RunPurchaseExecutionChecks(var DeepScanRun: Record "DH Deep Scan Run"; var Score: Integer; var ChecksCount: Integer; var IssuesCount: Integer)
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        Item: Record Item;
        MissingPaymentTerms: Integer;
        MissingPaymentMethod: Integer;
        MissingPurchaserCode: Integer;
        MissingVendorInvoiceNo: Integer;
        PastExpectedReceiptDate: Integer;
        DiscountAbove25: Integer;
        DiscountAbove50: Integer;
        ReceivedNotInvoiced: Integer;
        OutstandingPastReceiptDate: Integer;
        MissingDescription: Integer;
        MissingLocationCode: Integer;
        CostBelowItemCost: Integer;
    begin
        ChecksCount += 12;

        PurchaseHeader.SetRange("Document Type", PurchaseHeader."Document Type"::Order);
        if PurchaseHeader.FindSet() then
            repeat
                if PurchaseHeader."Payment Terms Code" = '' then
                    MissingPaymentTerms += 1;
                if PurchaseHeader."Payment Method Code" = '' then
                    MissingPaymentMethod += 1;
                if PurchaseHeader."Purchaser Code" = '' then
                    MissingPurchaserCode += 1;
                if PurchaseHeader."Vendor Invoice No." = '' then
                    MissingVendorInvoiceNo += 1;
                if (PurchaseHeader."Expected Receipt Date" <> 0D) and (PurchaseHeader."Expected Receipt Date" < Today()) then
                    PastExpectedReceiptDate += 1;
            until PurchaseHeader.Next() = 0;

        PurchaseLine.SetRange("Document Type", PurchaseLine."Document Type"::Order);
        if PurchaseLine.FindSet() then
            repeat
                if PurchaseLine."Line Discount %" > 25 then
                    DiscountAbove25 += 1;
                if PurchaseLine."Line Discount %" > 50 then
                    DiscountAbove50 += 1;
                if PurchaseLine."Quantity Received" > PurchaseLine."Quantity Invoiced" then
                    ReceivedNotInvoiced += 1;
                if (PurchaseLine."Outstanding Quantity" > 0) and (PurchaseLine."Expected Receipt Date" <> 0D) and (PurchaseLine."Expected Receipt Date" < Today()) then
                    OutstandingPastReceiptDate += 1;
                if PurchaseLine.Description = '' then
                    MissingDescription += 1;
                if PurchaseLine."Location Code" = '' then
                    MissingLocationCode += 1;
                if (PurchaseLine.Type = PurchaseLine.Type::Item) and (PurchaseLine."No." <> '') then
                    if Item.Get(PurchaseLine."No.") then
                        if (PurchaseLine."Direct Unit Cost" > 0) and (Item."Last Direct Cost" > 0) and (PurchaseLine."Direct Unit Cost" < Item."Last Direct Cost") then
                            CostBelowItemCost += 1;
            until PurchaseLine.Next() = 0;

        AddCountFinding(DeepScanRun, Score, IssuesCount, 'PURCHASE', 'PURCHASE_HEADERS_MISSING_PAYMENT_TERMS', 'Einkaufsaufträge ohne Zahlungsbedingungen', 'medium', MissingPaymentTerms, 'Zahlungsbedingungen in offenen Einkaufsaufträgen ergänzen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'PURCHASE', 'PURCHASE_HEADERS_MISSING_PAYMENT_METHOD', 'Einkaufsaufträge ohne Zahlungsform', 'medium', MissingPaymentMethod, 'Zahlungsform in offenen Einkaufsaufträgen ergänzen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'PURCHASE', 'PURCHASE_HEADERS_MISSING_PURCHASER', 'Einkaufsaufträge ohne Einkäufercode', 'low', MissingPurchaserCode, 'Verantwortliche Einkäufer zuordnen.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'PURCHASE', 'PURCHASE_HEADERS_MISSING_VENDOR_INVOICE_NO', 'Einkaufsaufträge ohne Kreditorenbelegnummer', 'low', MissingVendorInvoiceNo, 'Externen Belegbezug ergänzen, sofern fachlich erforderlich.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'PURCHASE', 'PURCHASE_HEADERS_PAST_EXPECTED_RECEIPT_DATE', 'Einkaufsaufträge mit überfälligem Wareneingang', 'high', PastExpectedReceiptDate, 'Überfällige Einkaufsaufträge terminlich bereinigen und eskalieren.', 4);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'PURCHASE', 'PURCHASE_LINES_DISCOUNT_OVER_25', 'Einkaufszeilen mit Rabatt > 25%', 'low', DiscountAbove25, 'Rabatte und Preisvereinbarungen prüfen.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'PURCHASE', 'PURCHASE_LINES_DISCOUNT_OVER_50', 'Einkaufszeilen mit Rabatt > 50%', 'medium', DiscountAbove50, 'Außergewöhnliche Rabatte fachlich validieren.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'PURCHASE', 'PURCHASE_LINES_RECEIVED_NOT_INVOICED', 'Empfangene, aber nicht fakturierte Einkaufszeilen', 'medium', ReceivedNotInvoiced, 'Wareneingänge zeitnah abrechnen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'PURCHASE', 'PURCHASE_LINES_OUTSTANDING_PAST_RECEIPT_DATE', 'Offene Einkaufszeilen mit überfälligem Wareneingang', 'medium', OutstandingPastReceiptDate, 'Offene Bestellungen und Liefertermine bereinigen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'PURCHASE', 'PURCHASE_LINES_MISSING_DESCRIPTION', 'Einkaufszeilen ohne Beschreibung', 'low', MissingDescription, 'Beschreibung in Einkaufszeilen ergänzen.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'PURCHASE', 'PURCHASE_LINES_MISSING_LOCATION', 'Einkaufszeilen ohne Lagerort', 'medium', MissingLocationCode, 'Lagerort in Einkaufszeilen ergänzen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'PURCHASE', 'PURCHASE_LINES_COST_BELOW_LAST_DIRECT_COST', 'Einkaufszeilen mit Kosten unter letztem Direktkostenwert', 'low', CostBelowItemCost, 'Preisabweichungen im Einkauf fachlich prüfen.', 1);
    end;

    local procedure RunInventoryValueChecks(var DeepScanRun: Record "DH Deep Scan Run"; var Score: Integer; var ChecksCount: Integer; var IssuesCount: Integer)
    var
        Item: Record Item;
        LastMovementDate: Date;
        PriceBelowUnitCost: Integer;
        PriceBelowStandardCost: Integer;
        StandardCostZero: Integer;
        LastDirectCostZero: Integer;
        MissingLeadTime: Integer;
        SafetyStockZero: Integer;
        ReorderPointZero: Integer;
        MaxInventoryZero: Integer;
        MinOrderQtyZero: Integer;
        OrderMultipleZero: Integer;
        MissingShelfNo: Integer;
        MissingTariffNo: Integer;
        GrossWeightZero: Integer;
        NetWeightZero: Integer;
        UnitVolumeZero: Integer;
        DeadStock90: Integer;
        DeadStock180: Integer;
        DeadStock365: Integer;
        InventoryWithoutUnitCost: Integer;
    begin
        ChecksCount += 21;

        if Item.FindSet() then
            repeat
                Item.CalcFields(Inventory);
                if (Item."Unit Price" > 0) and (Item."Unit Cost" > 0) and (Item."Unit Price" < Item."Unit Cost") then
                    PriceBelowUnitCost += 1;
                if (Item."Unit Price" > 0) and (Item."Standard Cost" > 0) and (Item."Unit Price" < Item."Standard Cost") then
                    PriceBelowStandardCost += 1;
                if Item."Standard Cost" = 0 then
                    StandardCostZero += 1;
                if Item."Last Direct Cost" = 0 then
                    LastDirectCostZero += 1;
                if Format(Item."Lead Time Calculation") = '' then
                    MissingLeadTime += 1;
                if Item."Safety Stock Quantity" = 0 then
                    SafetyStockZero += 1;
                if Item."Reorder Point" = 0 then
                    ReorderPointZero += 1;
                if Item."Maximum Inventory" = 0 then
                    MaxInventoryZero += 1;
                if Item."Minimum Order Quantity" = 0 then
                    MinOrderQtyZero += 1;
                if Item."Order Multiple" = 0 then
                    OrderMultipleZero += 1;
                if Item."Shelf No." = '' then
                    MissingShelfNo += 1;
                if Item."Tariff No." = '' then
                    MissingTariffNo += 1;
                if Item."Gross Weight" = 0 then
                    GrossWeightZero += 1;
                if Item."Net Weight" = 0 then
                    NetWeightZero += 1;
                if Item."Unit Volume" = 0 then
                    UnitVolumeZero += 1;
                if (Item.Inventory > 0) and (Item."Unit Cost" = 0) then
                    InventoryWithoutUnitCost += 1;

                LastMovementDate := GetLastItemMovementDate(Item."No.");
                if (Item.Inventory > 0) and (LastMovementDate <> 0D) and (LastMovementDate <= CalcDate('<-90D>', Today())) then
                    DeadStock90 += 1;
                if (Item.Inventory > 0) and (LastMovementDate <> 0D) and (LastMovementDate <= CalcDate('<-180D>', Today())) then
                    DeadStock180 += 1;
                if (Item.Inventory > 0) and (LastMovementDate <> 0D) and (LastMovementDate <= CalcDate('<-365D>', Today())) then
                    DeadStock365 += 1;
            until Item.Next() = 0;

        AddCountFinding(DeepScanRun, Score, IssuesCount, 'INVENTORY', 'ITEMS_PRICE_BELOW_UNIT_COST', 'Artikel mit Verkaufspreis unter Einstandspreis', 'high', PriceBelowUnitCost, 'Preisfindung und Kalkulation prüfen.', 6);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'INVENTORY', 'ITEMS_PRICE_BELOW_STANDARD_COST', 'Artikel mit Verkaufspreis unter Standardkosten', 'high', PriceBelowStandardCost, 'Standardkosten und Verkaufspreise abstimmen.', 5);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'INVENTORY', 'ITEMS_STANDARD_COST_ZERO', 'Artikel ohne Standardkosten', 'medium', StandardCostZero, 'Standardkosten pflegen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'INVENTORY', 'ITEMS_LAST_DIRECT_COST_ZERO', 'Artikel ohne letzte Direktkosten', 'medium', LastDirectCostZero, 'Letzte Direktkosten prüfen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'INVENTORY', 'ITEMS_MISSING_LEAD_TIME', 'Artikel ohne Beschaffungszeit', 'medium', MissingLeadTime, 'Beschaffungszeiten für Disposition pflegen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'INVENTORY', 'ITEMS_SAFETY_STOCK_ZERO', 'Artikel ohne Sicherheitsbestand', 'low', SafetyStockZero, 'Sicherheitsbestände pflegen, sofern fachlich relevant.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'INVENTORY', 'ITEMS_REORDER_POINT_ZERO', 'Artikel ohne Meldebestand', 'low', ReorderPointZero, 'Meldebestände pflegen, sofern fachlich relevant.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'INVENTORY', 'ITEMS_MAX_INVENTORY_ZERO', 'Artikel ohne Maximalbestand', 'low', MaxInventoryZero, 'Maximalbestände pflegen, sofern fachlich relevant.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'INVENTORY', 'ITEMS_MIN_ORDER_QTY_ZERO', 'Artikel ohne Mindestbestellmenge', 'low', MinOrderQtyZero, 'Mindestbestellmengen pflegen, sofern fachlich relevant.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'INVENTORY', 'ITEMS_ORDER_MULTIPLE_ZERO', 'Artikel ohne Bestellvielfaches', 'low', OrderMultipleZero, 'Bestellvielfache pflegen, sofern fachlich relevant.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'INVENTORY', 'ITEMS_MISSING_SHELF_NO', 'Artikel ohne Lagerplatzhinweis', 'low', MissingShelfNo, 'Lagerplatzhinweise ergänzen, sofern genutzt.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'INVENTORY', 'ITEMS_MISSING_TARIFF_NO', 'Artikel ohne Zolltarifnummer', 'low', MissingTariffNo, 'Zolltarifnummern pflegen, sofern exportrelevant.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'INVENTORY', 'ITEMS_GROSS_WEIGHT_ZERO', 'Artikel ohne Bruttogewicht', 'low', GrossWeightZero, 'Gewichtsdaten pflegen.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'INVENTORY', 'ITEMS_NET_WEIGHT_ZERO', 'Artikel ohne Nettogewicht', 'low', NetWeightZero, 'Gewichtsdaten pflegen.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'INVENTORY', 'ITEMS_UNIT_VOLUME_ZERO', 'Artikel ohne Volumen', 'low', UnitVolumeZero, 'Volumendaten pflegen.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'INVENTORY', 'DEAD_STOCK_90', 'Lagerartikel ohne Bewegung > 90 Tage', 'medium', DeadStock90, 'Langsamdreher prüfen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'INVENTORY', 'DEAD_STOCK_180', 'Lagerartikel ohne Bewegung > 180 Tage', 'medium', DeadStock180, 'Totes Kapital und Abverkaufsoptionen prüfen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'INVENTORY', 'DEAD_STOCK_365', 'Lagerartikel ohne Bewegung > 365 Tage', 'high', DeadStock365, 'Langfristig totes Kapital priorisiert abbauen.', 5);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'INVENTORY', 'INVENTORY_WITHOUT_UNIT_COST', 'Bestandsartikel ohne Einstandspreis', 'high', InventoryWithoutUnitCost, 'Bewertung und Kalkulation der Bestandsartikel korrigieren.', 5);
    end;

    local procedure RunCRMContactChecks(var DeepScanRun: Record "DH Deep Scan Run"; var Score: Integer; var ChecksCount: Integer; var IssuesCount: Integer)
    var
        Contact: Record Contact;
        MissingName: Integer;
        MissingEmail: Integer;
        MissingPhone: Integer;
        MissingMobilePhone: Integer;
        MissingCompanyNo: Integer;
        MissingAddress: Integer;
        MissingCity: Integer;
        MissingPostCode: Integer;
        MissingCountryCode: Integer;
    begin
        ChecksCount += 9;

        if Contact.FindSet() then
            repeat
                if Contact.Name = '' then
                    MissingName += 1;
                if Contact."E-Mail" = '' then
                    MissingEmail += 1;
                if Contact."Phone No." = '' then
                    MissingPhone += 1;
                if Contact."Mobile Phone No." = '' then
                    MissingMobilePhone += 1;
                if (Contact.Type = Contact.Type::Person) and (Contact."Company No." = '') then
                    MissingCompanyNo += 1;
                if Contact.Address = '' then
                    MissingAddress += 1;
                if Contact.City = '' then
                    MissingCity += 1;
                if Contact."Post Code" = '' then
                    MissingPostCode += 1;
                if Contact."Country/Region Code" = '' then
                    MissingCountryCode += 1;
            until Contact.Next() = 0;

        AddCountFinding(DeepScanRun, Score, IssuesCount, 'CRM', 'CONTACTS_MISSING_NAME', 'Kontakte ohne Name', 'medium', MissingName, 'Namen in Kontaktstammdaten ergänzen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'CRM', 'CONTACTS_MISSING_EMAIL', 'Kontakte ohne E-Mail', 'medium', MissingEmail, 'E-Mail-Adressen in Kontaktstammdaten pflegen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'CRM', 'CONTACTS_MISSING_PHONE', 'Kontakte ohne Telefonnummer', 'low', MissingPhone, 'Telefonnummern pflegen, sofern fachlich relevant.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'CRM', 'CONTACTS_MISSING_MOBILE_PHONE', 'Kontakte ohne Mobilnummer', 'low', MissingMobilePhone, 'Mobilnummern pflegen, sofern fachlich relevant.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'CRM', 'CONTACTS_PERSONS_MISSING_COMPANY', 'Personenkontakte ohne Firmenzuordnung', 'medium', MissingCompanyNo, 'Personenkontakte einer Firma zuordnen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'CRM', 'CONTACTS_MISSING_ADDRESS', 'Kontakte ohne Adresse', 'low', MissingAddress, 'Adressdaten in Kontakten pflegen.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'CRM', 'CONTACTS_MISSING_CITY', 'Kontakte ohne Ort', 'low', MissingCity, 'Ortsangaben in Kontakten pflegen.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'CRM', 'CONTACTS_MISSING_POST_CODE', 'Kontakte ohne Postleitzahl', 'low', MissingPostCode, 'Postleitzahlen in Kontakten pflegen.', 1);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'CRM', 'CONTACTS_MISSING_COUNTRY', 'Kontakte ohne Land', 'low', MissingCountryCode, 'Länderangaben in Kontakten pflegen.', 1);
    end;


        local procedure RunManufacturingChecks(var DeepScanRun: Record "DH Deep Scan Run"; var Score: Integer; var ChecksCount: Integer; var IssuesCount: Integer)
    var
        ProdBOMHeader: Record "Production BOM Header";
        ProdBOMLine: Record "Production BOM Line";
        RoutingHeader: Record "Routing Header";
        RoutingLine: Record "Routing Line";
        WorkCenter: Record "Work Center";
        MachineCenter: Record "Machine Center";
        Item: Record Item;
        MissingBOMDescription: Integer;
        BOMNotCertified: Integer;
        BOMLinesMissingNo: Integer;
        BOMLinesZeroQty: Integer;
        RoutingMissingDescription: Integer;
        RoutingNotCertified: Integer;
        RoutingLinesMissingNo: Integer;
        RoutingLinesZeroSetupTime: Integer;
        RoutingLinesZeroRunTime: Integer;
        WorkCentersBlocked: Integer;
        WorkCentersMissingName: Integer;
        WorkCentersZeroCost: Integer;
        MachineCentersBlocked: Integer;
        MachineCentersMissingName: Integer;
        MachineCentersZeroCost: Integer;
        ItemsMissingProdBomNo: Integer;
        ItemsMissingRoutingNo: Integer;
    begin
        ChecksCount += 17;

        if ProdBOMHeader.FindSet() then
            repeat
                if ProdBOMHeader.Description = '' then
                    MissingBOMDescription += 1;
                if ProdBOMHeader.Status <> ProdBOMHeader.Status::Certified then
                    BOMNotCertified += 1;
            until ProdBOMHeader.Next() = 0;

        if ProdBOMLine.FindSet() then
            repeat
                if (Format(ProdBOMLine.Type) <> '') and (ProdBOMLine."No." = '') then
                    BOMLinesMissingNo += 1;
                if ProdBOMLine.Quantity = 0 then
                    BOMLinesZeroQty += 1;
            until ProdBOMLine.Next() = 0;

        if RoutingHeader.FindSet() then
            repeat
                if RoutingHeader.Description = '' then
                    RoutingMissingDescription += 1;
                if RoutingHeader.Status <> RoutingHeader.Status::Certified then
                    RoutingNotCertified += 1;
            until RoutingHeader.Next() = 0;

        if RoutingLine.FindSet() then
            repeat
                if (Format(RoutingLine.Type) <> '') and (RoutingLine."No." = '') then
                    RoutingLinesMissingNo += 1;
                if RoutingLine."Setup Time" = 0 then
                    RoutingLinesZeroSetupTime += 1;
                if RoutingLine."Run Time" = 0 then
                    RoutingLinesZeroRunTime += 1;
            until RoutingLine.Next() = 0;

        if WorkCenter.FindSet() then
            repeat
                if WorkCenter.Blocked then
                    WorkCentersBlocked += 1;
                if WorkCenter.Name = '' then
                    WorkCentersMissingName += 1;
                if WorkCenter."Unit Cost" = 0 then
                    WorkCentersZeroCost += 1;
            until WorkCenter.Next() = 0;

        if MachineCenter.FindSet() then
            repeat
                if MachineCenter.Blocked then
                    MachineCentersBlocked += 1;
                if MachineCenter.Name = '' then
                    MachineCentersMissingName += 1;
                if MachineCenter."Unit Cost" = 0 then
                    MachineCentersZeroCost += 1;
            until MachineCenter.Next() = 0;

        if Item.FindSet() then
            repeat
                if (Item."Production BOM No." <> '') and (Item."Routing No." = '') then
                    ItemsMissingRoutingNo += 1;
                if (Item."Routing No." <> '') and (Item."Production BOM No." = '') then
                    ItemsMissingProdBomNo += 1;
            until Item.Next() = 0;

        AddCountFinding(DeepScanRun, Score, IssuesCount, 'MANUFACTURING', 'MFG_BOM_MISSING_DESCRIPTION', 'Fertigungsstücklisten ohne Beschreibung', 'medium', MissingBOMDescription, 'Beschreibungen in den betroffenen Fertigungsstücklisten ergänzen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'MANUFACTURING', 'MFG_BOM_NOT_CERTIFIED', 'Nicht zertifizierte Fertigungsstücklisten', 'high', BOMNotCertified, 'Stücklisten fachlich prüfen und zertifizieren.', 5);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'MANUFACTURING', 'MFG_BOM_LINES_MISSING_NO', 'Stücklistenzeilen ohne Artikel-/Ressourcennummer', 'high', BOMLinesMissingNo, 'Nummern in den betroffenen Stücklistenzeilen ergänzen.', 6);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'MANUFACTURING', 'MFG_BOM_LINES_ZERO_QTY', 'Stücklistenzeilen mit Menge 0', 'high', BOMLinesZeroQty, 'Mengen in den betroffenen Stücklistenzeilen prüfen.', 6);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'MANUFACTURING', 'MFG_ROUTING_MISSING_DESCRIPTION', 'Arbeitspläne ohne Beschreibung', 'low', RoutingMissingDescription, 'Beschreibungen in den betroffenen Arbeitsplänen ergänzen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'MANUFACTURING', 'MFG_ROUTING_NOT_CERTIFIED', 'Nicht zertifizierte Arbeitspläne', 'high', RoutingNotCertified, 'Arbeitspläne fachlich prüfen und zertifizieren.', 5);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'MANUFACTURING', 'MFG_ROUTING_LINES_MISSING_NO', 'Arbeitsplanschritte ohne Arbeitsplatz/Maschinenzentrum', 'high', RoutingLinesMissingNo, 'Arbeitsplätze bzw. Maschinenzentren in den Arbeitsplänen pflegen.', 6);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'MANUFACTURING', 'MFG_ROUTING_LINES_ZERO_SETUP', 'Arbeitsplanschritte ohne Rüstzeit', 'medium', RoutingLinesZeroSetupTime, 'Rüstzeiten in den betroffenen Arbeitsschritten prüfen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'MANUFACTURING', 'MFG_ROUTING_LINES_ZERO_RUN', 'Arbeitsplanschritte ohne Laufzeit', 'high', RoutingLinesZeroRunTime, 'Laufzeiten in den betroffenen Arbeitsschritten prüfen.', 4);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'MANUFACTURING', 'MFG_WORK_CENTERS_BLOCKED', 'Gesperrte Arbeitsplätze', 'medium', WorkCentersBlocked, 'Gesperrte Arbeitsplätze fachlich prüfen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'MANUFACTURING', 'MFG_WORK_CENTERS_MISSING_NAME', 'Arbeitsplätze ohne Name', 'low', WorkCentersMissingName, 'Namen der betroffenen Arbeitsplätze ergänzen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'MANUFACTURING', 'MFG_WORK_CENTERS_ZERO_COST', 'Arbeitsplätze ohne Einstandskosten', 'medium', WorkCentersZeroCost, 'Einstandskosten für Arbeitsplätze pflegen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'MANUFACTURING', 'MFG_MACHINE_CENTERS_BLOCKED', 'Gesperrte Maschinenzentren', 'medium', MachineCentersBlocked, 'Gesperrte Maschinenzentren fachlich prüfen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'MANUFACTURING', 'MFG_MACHINE_CENTERS_MISSING_NAME', 'Maschinenzentren ohne Name', 'low', MachineCentersMissingName, 'Namen der betroffenen Maschinenzentren ergänzen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'MANUFACTURING', 'MFG_MACHINE_CENTERS_ZERO_COST', 'Maschinenzentren ohne Einstandskosten', 'medium', MachineCentersZeroCost, 'Einstandskosten für Maschinenzentren pflegen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'MANUFACTURING', 'MFG_ITEMS_MISSING_PROD_BOM_NO', 'Artikel mit Arbeitsplan aber ohne Fertigungsstückliste', 'high', ItemsMissingProdBomNo, 'Stücklisten bei den betroffenen Artikeln ergänzen.', 5);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'MANUFACTURING', 'MFG_ITEMS_MISSING_ROUTING_NO', 'Artikel mit Fertigungsstückliste aber ohne Arbeitsplan', 'high', ItemsMissingRoutingNo, 'Arbeitspläne bei den betroffenen Artikeln ergänzen.', 5);
    end;

    local procedure RunServiceChecks(var DeepScanRun: Record "DH Deep Scan Run"; var Score: Integer; var ChecksCount: Integer; var IssuesCount: Integer)
    var
        ServiceItem: Record "Service Item";
        ServiceHeader: Record "Service Header";
        ServiceLine: Record "Service Line";
        MissingServiceItemDescription: Integer;
        MissingServiceItemCustomer: Integer;
        MissingServiceItemItemNo: Integer;
        MissingServiceItemSerialNo: Integer;
        MissingHeaderCustomer: Integer;
        MissingHeaderBillToCustomer: Integer;
        MissingHeaderDescription: Integer;
        MissingHeaderAssignedUser: Integer;
        MissingLineNo: Integer;
        MissingLineDescription: Integer;
        ZeroLineQuantity: Integer;
        ZeroLineUnitPrice: Integer;
    begin
        ChecksCount += 12;

        if ServiceItem.FindSet() then
            repeat
                if ServiceItem.Description = '' then
                    MissingServiceItemDescription += 1;
                if ServiceItem."Customer No." = '' then
                    MissingServiceItemCustomer += 1;
                if ServiceItem."Item No." = '' then
                    MissingServiceItemItemNo += 1;
                if ServiceItem."Serial No." = '' then
                    MissingServiceItemSerialNo += 1;
            until ServiceItem.Next() = 0;

        if ServiceHeader.FindSet() then
            repeat
                if ServiceHeader."Customer No." = '' then
                    MissingHeaderCustomer += 1;
                if ServiceHeader."Bill-to Customer No." = '' then
                    MissingHeaderBillToCustomer += 1;
                if ServiceHeader.Description = '' then
                    MissingHeaderDescription += 1;
                if ServiceHeader."Assigned User ID" = '' then
                    MissingHeaderAssignedUser += 1;
            until ServiceHeader.Next() = 0;

        if ServiceLine.FindSet() then
            repeat
                if (Format(ServiceLine.Type) <> '') and (ServiceLine."No." = '') then
                    MissingLineNo += 1;
                if (Format(ServiceLine.Type) <> '') and (ServiceLine.Description = '') then
                    MissingLineDescription += 1;
                if (Format(ServiceLine.Type) <> '') and (ServiceLine.Quantity = 0) then
                    ZeroLineQuantity += 1;
                if (Format(ServiceLine.Type) <> '') and (ServiceLine."Unit Price" = 0) then
                    ZeroLineUnitPrice += 1;
            until ServiceLine.Next() = 0;

        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SERVICE', 'SERVICE_ITEMS_MISSING_DESCRIPTION', 'Serviceartikel ohne Beschreibung', 'medium', MissingServiceItemDescription, 'Beschreibungen bei den betroffenen Serviceartikeln ergänzen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SERVICE', 'SERVICE_ITEMS_MISSING_CUSTOMER', 'Serviceartikel ohne Kunde', 'high', MissingServiceItemCustomer, 'Kundenbezug bei den betroffenen Serviceartikeln ergänzen.', 5);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SERVICE', 'SERVICE_ITEMS_MISSING_ITEM_NO', 'Serviceartikel ohne Artikelnummer', 'high', MissingServiceItemItemNo, 'Artikelnummern bei den betroffenen Serviceartikeln ergänzen.', 5);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SERVICE', 'SERVICE_ITEMS_MISSING_SERIAL_NO', 'Serviceartikel ohne Seriennummer', 'medium', MissingServiceItemSerialNo, 'Seriennummern bei den betroffenen Serviceartikeln ergänzen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SERVICE', 'SERVICE_ORDERS_MISSING_CUSTOMER', 'Servicebelege ohne Kunde', 'high', MissingHeaderCustomer, 'Kunden in den betroffenen Servicebelegen ergänzen.', 6);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SERVICE', 'SERVICE_ORDERS_MISSING_BILL_TO', 'Servicebelege ohne Rechnungskunde', 'high', MissingHeaderBillToCustomer, 'Rechnungskunde in den betroffenen Servicebelegen pflegen.', 6);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SERVICE', 'SERVICE_ORDERS_MISSING_DESCRIPTION', 'Servicebelege ohne Beschreibung', 'medium', MissingHeaderDescription, 'Beschreibungen in den betroffenen Servicebelegen ergänzen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SERVICE', 'SERVICE_ORDERS_MISSING_ASSIGNED_USER', 'Servicebelege ohne verantwortlichen Benutzer', 'medium', MissingHeaderAssignedUser, 'Verantwortlichen Benutzer in Servicebelegen pflegen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SERVICE', 'SERVICE_LINES_MISSING_NO', 'Servicezeilen ohne Nummer', 'high', MissingLineNo, 'Nummern in den betroffenen Servicezeilen ergänzen.', 5);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SERVICE', 'SERVICE_LINES_MISSING_DESCRIPTION', 'Servicezeilen ohne Beschreibung', 'medium', MissingLineDescription, 'Beschreibungen in den betroffenen Servicezeilen ergänzen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SERVICE', 'SERVICE_LINES_ZERO_QTY', 'Servicezeilen mit Menge 0', 'medium', ZeroLineQuantity, 'Mengen in den betroffenen Servicezeilen prüfen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'SERVICE', 'SERVICE_LINES_ZERO_UNIT_PRICE', 'Servicezeilen mit Preis 0', 'high', ZeroLineUnitPrice, 'Verkaufspreise in den betroffenen Servicezeilen prüfen.', 5);
    end;

    local procedure RunJobsChecks(var DeepScanRun: Record "DH Deep Scan Run"; var Score: Integer; var ChecksCount: Integer; var IssuesCount: Integer)
    var
        JobRec: Record Job;
        JobTask: Record "Job Task";
        JobPlanningLine: Record "Job Planning Line";
        MissingJobDescription: Integer;
        MissingBillToCustomer: Integer;
        MissingPersonResponsible: Integer;
        MissingJobPostingGroup: Integer;
        MissingTaskDescription: Integer;
        MissingPlanningLineNo: Integer;
        MissingPlanningDescription: Integer;
        ZeroPlanningQuantity: Integer;
        ZeroUnitCost: Integer;
        ZeroUnitPrice: Integer;
    begin
        ChecksCount += 10;

        if JobRec.FindSet() then
            repeat
                if JobRec.Description = '' then
                    MissingJobDescription += 1;
                if JobRec."Bill-to Customer No." = '' then
                    MissingBillToCustomer += 1;
                if JobRec."Person Responsible" = '' then
                    MissingPersonResponsible += 1;
                if JobRec."Job Posting Group" = '' then
                    MissingJobPostingGroup += 1;
            until JobRec.Next() = 0;

        if JobTask.FindSet() then
            repeat
                if JobTask.Description = '' then
                    MissingTaskDescription += 1;
            until JobTask.Next() = 0;

        if JobPlanningLine.FindSet() then
            repeat
                if (Format(JobPlanningLine.Type) <> '') and (JobPlanningLine."No." = '') then
                    MissingPlanningLineNo += 1;
                if (Format(JobPlanningLine.Type) <> '') and (JobPlanningLine.Description = '') then
                    MissingPlanningDescription += 1;
                if (Format(JobPlanningLine.Type) <> '') and (JobPlanningLine.Quantity = 0) then
                    ZeroPlanningQuantity += 1;
                if (Format(JobPlanningLine.Type) <> '') and (JobPlanningLine."Unit Cost" = 0) then
                    ZeroUnitCost += 1;
                if (Format(JobPlanningLine.Type) <> '') and (JobPlanningLine."Unit Price" = 0) then
                    ZeroUnitPrice += 1;
            until JobPlanningLine.Next() = 0;

        AddCountFinding(DeepScanRun, Score, IssuesCount, 'JOB', 'JOBS_MISSING_DESCRIPTION', 'Projekte ohne Beschreibung', 'medium', MissingJobDescription, 'Beschreibungen bei den betroffenen Projekten ergänzen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'JOB', 'JOBS_MISSING_BILL_TO_CUSTOMER', 'Projekte ohne Rechnungskunden', 'high', MissingBillToCustomer, 'Rechnungskunden in den betroffenen Projekten pflegen.', 5);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'JOB', 'JOBS_MISSING_RESPONSIBLE', 'Projekte ohne Verantwortlichen', 'medium', MissingPersonResponsible, 'Verantwortliche Person in den betroffenen Projekten pflegen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'JOB', 'JOBS_MISSING_POSTING_GROUP', 'Projekte ohne Projektbuchungsgruppe', 'high', MissingJobPostingGroup, 'Projektbuchungsgruppen bei den betroffenen Projekten ergänzen.', 5);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'JOB', 'JOB_TASKS_MISSING_DESCRIPTION', 'Projektaufgaben ohne Beschreibung', 'medium', MissingTaskDescription, 'Beschreibungen in den betroffenen Projektaufgaben ergänzen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'JOB', 'JOB_PLANNING_LINES_MISSING_NO', 'Projektplanungszeilen ohne Nummer', 'high', MissingPlanningLineNo, 'Nummern in den betroffenen Projektplanungszeilen ergänzen.', 5);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'JOB', 'JOB_PLANNING_LINES_MISSING_DESCRIPTION', 'Projektplanungszeilen ohne Beschreibung', 'medium', MissingPlanningDescription, 'Beschreibungen in den betroffenen Projektplanungszeilen ergänzen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'JOB', 'JOB_PLANNING_LINES_ZERO_QTY', 'Projektplanungszeilen mit Menge 0', 'medium', ZeroPlanningQuantity, 'Mengen in den betroffenen Projektplanungszeilen prüfen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'JOB', 'JOB_PLANNING_LINES_ZERO_UNIT_COST', 'Projektplanungszeilen ohne Einstandskosten', 'high', ZeroUnitCost, 'Einstandskosten in den betroffenen Projektplanungszeilen ergänzen.', 4);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'JOB', 'JOB_PLANNING_LINES_ZERO_UNIT_PRICE', 'Projektplanungszeilen ohne Preis', 'high', ZeroUnitPrice, 'Preise in den betroffenen Projektplanungszeilen ergänzen.', 4);
    end;

    local procedure RunHRChecks(var DeepScanRun: Record "DH Deep Scan Run"; var Score: Integer; var ChecksCount: Integer; var IssuesCount: Integer)
    var
        Employee: Record Employee;
        ResourceRec: Record Resource;
        MissingFirstName: Integer;
        MissingLastName: Integer;
        MissingSearchName: Integer;
        MissingEmail: Integer;
        MissingPhone: Integer;
        MissingCountryCode: Integer;
        MissingResourceNo: Integer;
        MissingJobTitle: Integer;
        ResourcesMissingName: Integer;
        ResourcesZeroUnitCost: Integer;
        ResourcesZeroUnitPrice: Integer;
        ResourcesMissingBaseUOM: Integer;
    begin
        ChecksCount += 12;

        if Employee.FindSet() then
            repeat
                if Employee."First Name" = '' then
                    MissingFirstName += 1;
                if Employee."Last Name" = '' then
                    MissingLastName += 1;
                if Employee."Search Name" = '' then
                    MissingSearchName += 1;
                if Employee."E-Mail" = '' then
                    MissingEmail += 1;
                if Employee."Phone No." = '' then
                    MissingPhone += 1;
                if Employee."Country/Region Code" = '' then
                    MissingCountryCode += 1;
                if Employee."Resource No." = '' then
                    MissingResourceNo += 1;
                if Employee."Job Title" = '' then
                    MissingJobTitle += 1;
            until Employee.Next() = 0;

        if ResourceRec.FindSet() then
            repeat
                if ResourceRec.Name = '' then
                    ResourcesMissingName += 1;
                if ResourceRec."Unit Cost" = 0 then
                    ResourcesZeroUnitCost += 1;
                if ResourceRec."Unit Price" = 0 then
                    ResourcesZeroUnitPrice += 1;
                if ResourceRec."Base Unit of Measure" = '' then
                    ResourcesMissingBaseUOM += 1;
            until ResourceRec.Next() = 0;

        AddCountFinding(DeepScanRun, Score, IssuesCount, 'HR', 'EMPLOYEES_MISSING_FIRST_NAME', 'Mitarbeiter ohne Vorname', 'low', MissingFirstName, 'Vornamen bei den betroffenen Mitarbeitern ergänzen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'HR', 'EMPLOYEES_MISSING_LAST_NAME', 'Mitarbeiter ohne Nachname', 'medium', MissingLastName, 'Nachnamen bei den betroffenen Mitarbeitern ergänzen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'HR', 'EMPLOYEES_MISSING_SEARCH_NAME', 'Mitarbeiter ohne Suchname', 'low', MissingSearchName, 'Suchnamen bei den betroffenen Mitarbeitern ergänzen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'HR', 'EMPLOYEES_MISSING_EMAIL', 'Mitarbeiter ohne E-Mail', 'medium', MissingEmail, 'E-Mail-Adressen bei den betroffenen Mitarbeitern ergänzen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'HR', 'EMPLOYEES_MISSING_PHONE', 'Mitarbeiter ohne Telefonnummer', 'low', MissingPhone, 'Telefonnummern bei den betroffenen Mitarbeitern ergänzen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'HR', 'EMPLOYEES_MISSING_COUNTRY', 'Mitarbeiter ohne Länder-/Regionscode', 'low', MissingCountryCode, 'Länder-/Regionscode bei den betroffenen Mitarbeitern ergänzen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'HR', 'EMPLOYEES_MISSING_RESOURCE_NO', 'Mitarbeiter ohne Ressourcennummer', 'medium', MissingResourceNo, 'Ressourcennummer bei den betroffenen Mitarbeitern pflegen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'HR', 'EMPLOYEES_MISSING_JOB_TITLE', 'Mitarbeiter ohne Jobtitel', 'low', MissingJobTitle, 'Jobtitel bei den betroffenen Mitarbeitern ergänzen.', 2);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'HR', 'RESOURCES_MISSING_NAME', 'Ressourcen ohne Name', 'medium', ResourcesMissingName, 'Namen bei den betroffenen Ressourcen ergänzen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'HR', 'RESOURCES_ZERO_UNIT_COST', 'Ressourcen ohne Einstandskosten', 'medium', ResourcesZeroUnitCost, 'Einstandskosten bei den betroffenen Ressourcen pflegen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'HR', 'RESOURCES_ZERO_UNIT_PRICE', 'Ressourcen ohne Preis', 'medium', ResourcesZeroUnitPrice, 'Preise bei den betroffenen Ressourcen pflegen.', 3);
        AddCountFinding(DeepScanRun, Score, IssuesCount, 'HR', 'RESOURCES_MISSING_BASE_UOM', 'Ressourcen ohne Basiseinheit', 'low', ResourcesMissingBaseUOM, 'Basiseinheiten bei den betroffenen Ressourcen ergänzen.', 2);
    end;

local procedure GetEnabledModuleCount(var Setup: Record "DH Setup"): Integer
    var
        EnabledCount: Integer;
    begin
        if Setup.GetEnabledDeepScanModuleCount() > 0 then
            exit(Setup.GetEnabledDeepScanModuleCount());

        exit(10);
    end;

    local procedure IsModuleEnabled(var Setup: Record "DH Setup"; ModuleName: Text): Boolean
    begin
        case ModuleName of
            'System':
                exit(Setup."Scan System Module");
            'Finance':
                exit(Setup."Scan Finance Module");
            'Sales':
                exit(Setup."Scan Sales Module");
            'Purchasing':
                exit(Setup."Scan Purchasing Module");
            'Inventory':
                exit(Setup."Scan Inventory Module");
            'CRM':
                exit(Setup."Scan CRM Module");
            'Manufacturing':
                exit(Setup."Scan Manufacturing Module");
            'Service':
                exit(Setup."Scan Service Module");
            'Jobs':
                exit(Setup."Scan Jobs Module");
            'HR':
                exit(Setup."Scan HR Module");
        end;

        exit(true);
    end;

    local procedure InitializeProgress(var DeepScanRun: Record "DH Deep Scan Run"; TotalModules: Integer)
    begin
        DeepScanRun.Get(DeepScanRun."Entry No.");
        DeepScanRun."Current Module" := 'Initializing';
        DeepScanRun."Progress %" := 0;
        DeepScanRun."Completed Modules" := 0;
        DeepScanRun."Total Modules" := TotalModules;
        DeepScanRun."ETA Text" := 'Calculating...';
        DeepScanRun."System Progress %" := 0;
        DeepScanRun."Finance Progress %" := 0;
        DeepScanRun."Sales Progress %" := 0;
        DeepScanRun."Purchasing Progress %" := 0;
        DeepScanRun."Inventory Progress %" := 0;
        DeepScanRun."CRM Progress %" := 0;
        DeepScanRun."Manufacturing Progress %" := 0;
        DeepScanRun."Service Progress %" := 0;
        DeepScanRun."Jobs Progress %" := 0;
        DeepScanRun."HR Progress %" := 0;
        DeepScanRun.Modify(true);
        Commit();
    end;

    local procedure StartModule(var DeepScanRun: Record "DH Deep Scan Run"; ModuleName: Text[50]; ModuleNo: Integer)
    begin
        DeepScanRun.Get(DeepScanRun."Entry No.");
        DeepScanRun."Current Module" := ModuleName;
        SetModuleProgress(DeepScanRun, ModuleName, 10);
        if DeepScanRun."Total Modules" > 0 then
            DeepScanRun."Progress %" := ((ModuleNo - 1) * 100) div DeepScanRun."Total Modules";
        DeepScanRun."ETA Text" := GetEtaText(DeepScanRun, ModuleNo - 1);
        DeepScanRun.Modify(true);
        Commit();
    end;

    local procedure CompleteModule(var DeepScanRun: Record "DH Deep Scan Run"; ModuleName: Text[50]; ModuleNo: Integer)
    begin
        DeepScanRun.Get(DeepScanRun."Entry No.");
        SetModuleProgress(DeepScanRun, ModuleName, 100);
        DeepScanRun."Completed Modules" := ModuleNo;
        if DeepScanRun."Total Modules" > 0 then
            DeepScanRun."Progress %" := (ModuleNo * 100) div DeepScanRun."Total Modules";
        if ModuleNo >= DeepScanRun."Total Modules" then begin
            DeepScanRun."Current Module" := 'Finalizing';
            DeepScanRun."ETA Text" := 'Less than 1 minute';
        end else
            DeepScanRun."ETA Text" := GetEtaText(DeepScanRun, ModuleNo);
        DeepScanRun.Modify(true);
        Commit();
    end;

    local procedure SetModuleProgress(var DeepScanRun: Record "DH Deep Scan Run"; ModuleName: Text; PercentValue: Integer)
    begin
        case ModuleName of
            'System':
                DeepScanRun."System Progress %" := PercentValue;
            'Finance':
                DeepScanRun."Finance Progress %" := PercentValue;
            'Sales':
                DeepScanRun."Sales Progress %" := PercentValue;
            'Purchasing':
                DeepScanRun."Purchasing Progress %" := PercentValue;
            'Inventory':
                DeepScanRun."Inventory Progress %" := PercentValue;
            'CRM':
                DeepScanRun."CRM Progress %" := PercentValue;
            'Manufacturing':
                DeepScanRun."Manufacturing Progress %" := PercentValue;
            'Service':
                DeepScanRun."Service Progress %" := PercentValue;
            'Jobs':
                DeepScanRun."Jobs Progress %" := PercentValue;
            'HR':
                DeepScanRun."HR Progress %" := PercentValue;
        end;
    end;

    local procedure GetEtaText(var DeepScanRun: Record "DH Deep Scan Run"; CompletedModules: Integer): Text[100]
    var
        ElapsedSeconds: Integer;
        RemainingSeconds: Integer;
        RemainingMinutes: Integer;
    begin
        if (CompletedModules <= 0) or (DeepScanRun."Started At" = 0DT) or (DeepScanRun."Total Modules" <= 0) then
            exit('Calculating...');

        ElapsedSeconds := GetElapsedSeconds(DeepScanRun."Started At", CurrentDateTime());
        RemainingSeconds := (ElapsedSeconds div CompletedModules) * (DeepScanRun."Total Modules" - CompletedModules);
        if RemainingSeconds < 60 then
            exit('Less than 1 minute');

        RemainingMinutes := (RemainingSeconds + 59) div 60;
        exit(StrSubstNo('%1 min remaining', RemainingMinutes));
    end;

    local procedure GetElapsedSeconds(StartDateTime: DateTime; EndDateTime: DateTime): Integer
    begin
        exit((EndDateTime - StartDateTime) div 1000);
    end;

    local procedure GetLastItemMovementDate(ItemNo: Code[20]): Date
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        ItemLedgerEntry.SetCurrentKey("Item No.", "Posting Date");
        ItemLedgerEntry.SetRange("Item No.", ItemNo);
        if ItemLedgerEntry.FindLast() then
            exit(ItemLedgerEntry."Posting Date");

        exit(0D);
    end;

    local procedure HasGLEntriesForAccount(GLAccountNo: Code[20]): Boolean
    var
        GLEntry: Record "G/L Entry";
    begin
        GLEntry.SetRange("G/L Account No.", GLAccountNo);
        exit(not GLEntry.IsEmpty());
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

    local procedure RecalculateScoreMetrics(var DeepScanRun: Record "DH Deep Scan Run"; var Score: Integer)
    var
        Finding: Record "DH Deep Scan Finding";
        Setup: Record "DH Setup";
        WeightedScoreTotal: Integer;
        EnabledWeightTotal: Integer;
        AffectedRecords: Integer;
        ModuleName: Text[30];
    begin
        ClearRunScoreMetrics(DeepScanRun);

        Finding.SetRange("Deep Scan Entry No.", DeepScanRun."Entry No.");
        if Finding.FindSet() then
            repeat
                AffectedRecords += Finding."Affected Count";
                ModuleName := ResolveModuleFromCategory(Finding.Category);
                AddPenaltyToModule(DeepScanRun, ModuleName, GetSeverityPenalty(Finding.Severity) + GetAffectedPenalty(Finding."Affected Count"));
            until Finding.Next() = 0;

        DeepScanRun."Affected Records" := AffectedRecords;
        DeepScanRun."System Score" := NormalizeModuleScore(DeepScanRun."System Score");
        DeepScanRun."Finance Score" := NormalizeModuleScore(DeepScanRun."Finance Score");
        DeepScanRun."Sales Score" := NormalizeModuleScore(DeepScanRun."Sales Score");
        DeepScanRun."Purchasing Score" := NormalizeModuleScore(DeepScanRun."Purchasing Score");
        DeepScanRun."Inventory Score" := NormalizeModuleScore(DeepScanRun."Inventory Score");
        DeepScanRun."CRM Score" := NormalizeModuleScore(DeepScanRun."CRM Score");
        DeepScanRun."Manufacturing Score" := NormalizeModuleScore(DeepScanRun."Manufacturing Score");
        DeepScanRun."Service Score" := NormalizeModuleScore(DeepScanRun."Service Score");
        DeepScanRun."Jobs Score" := NormalizeModuleScore(DeepScanRun."Jobs Score");
        DeepScanRun."HR Score" := NormalizeModuleScore(DeepScanRun."HR Score");

        if Setup.Get('SETUP') then
            Setup.ApplyDefaults()
        else begin
            Setup.Init();
            Setup."Scan System Module" := true;
            Setup."Scan Finance Module" := true;
            Setup."Scan Sales Module" := true;
            Setup."Scan Purchasing Module" := true;
            Setup."Scan Inventory Module" := true;
            Setup."Scan CRM Module" := true;
            Setup."Scan Manufacturing Module" := true;
            Setup."Scan Service Module" := true;
            Setup."Scan Jobs Module" := true;
            Setup."Scan HR Module" := true;
        end;

        AddWeightedModuleScore(Setup."Scan System Module", 15, DeepScanRun."System Score", WeightedScoreTotal, EnabledWeightTotal);
        AddWeightedModuleScore(Setup."Scan Finance Module", 20, DeepScanRun."Finance Score", WeightedScoreTotal, EnabledWeightTotal);
        AddWeightedModuleScore(Setup."Scan Sales Module", 15, DeepScanRun."Sales Score", WeightedScoreTotal, EnabledWeightTotal);
        AddWeightedModuleScore(Setup."Scan Purchasing Module", 10, DeepScanRun."Purchasing Score", WeightedScoreTotal, EnabledWeightTotal);
        AddWeightedModuleScore(Setup."Scan Inventory Module", 15, DeepScanRun."Inventory Score", WeightedScoreTotal, EnabledWeightTotal);
        AddWeightedModuleScore(Setup."Scan CRM Module", 5, DeepScanRun."CRM Score", WeightedScoreTotal, EnabledWeightTotal);
        AddWeightedModuleScore(Setup."Scan Manufacturing Module", 10, DeepScanRun."Manufacturing Score", WeightedScoreTotal, EnabledWeightTotal);
        AddWeightedModuleScore(Setup."Scan Service Module", 5, DeepScanRun."Service Score", WeightedScoreTotal, EnabledWeightTotal);
        AddWeightedModuleScore(Setup."Scan Jobs Module", 3, DeepScanRun."Jobs Score", WeightedScoreTotal, EnabledWeightTotal);
        AddWeightedModuleScore(Setup."Scan HR Module", 2, DeepScanRun."HR Score", WeightedScoreTotal, EnabledWeightTotal);

        if EnabledWeightTotal > 0 then
            Score := (WeightedScoreTotal + (EnabledWeightTotal div 2)) div EnabledWeightTotal
        else
            Score := 100;

        DeepScanRun."Deep Score" := Score;
        DeepScanRun.Modify(true);
    end;

    local procedure ClearRunScoreMetrics(var DeepScanRun: Record "DH Deep Scan Run")
    begin
        DeepScanRun."Affected Records" := 0;
        DeepScanRun."System Score" := 0;
        DeepScanRun."Finance Score" := 0;
        DeepScanRun."Sales Score" := 0;
        DeepScanRun."Purchasing Score" := 0;
        DeepScanRun."Inventory Score" := 0;
        DeepScanRun."CRM Score" := 0;
        DeepScanRun."Manufacturing Score" := 0;
        DeepScanRun."Service Score" := 0;
        DeepScanRun."Jobs Score" := 0;
        DeepScanRun."HR Score" := 0;
    end;

    local procedure ResolveModuleFromCategory(Category: Code[30]): Text[30]
    begin
        case UpperCase(Format(Category)) of
            'SYSTEM':
                exit('System');
            'FINANCE', 'CUSTOMER', 'VENDOR', 'LEDGER':
                exit('Finance');
            'SALES':
                exit('Sales');
            'PURCHASE':
                exit('Purchasing');
            'INVENTORY', 'ITEM':
                exit('Inventory');
            'CRM':
                exit('CRM');
            'MANUFACTURING':
                exit('Manufacturing');
            'SERVICE':
                exit('Service');
            'JOB':
                exit('Jobs');
            'HR':
                exit('HR');
        end;

        exit('System');
    end;

    local procedure AddPenaltyToModule(var DeepScanRun: Record "DH Deep Scan Run"; ModuleName: Text[30]; PenaltyPoints: Integer)
    begin
        case ModuleName of
            'System':
                DeepScanRun."System Score" += PenaltyPoints;
            'Finance':
                DeepScanRun."Finance Score" += PenaltyPoints;
            'Sales':
                DeepScanRun."Sales Score" += PenaltyPoints;
            'Purchasing':
                DeepScanRun."Purchasing Score" += PenaltyPoints;
            'Inventory':
                DeepScanRun."Inventory Score" += PenaltyPoints;
            'CRM':
                DeepScanRun."CRM Score" += PenaltyPoints;
            'Manufacturing':
                DeepScanRun."Manufacturing Score" += PenaltyPoints;
            'Service':
                DeepScanRun."Service Score" += PenaltyPoints;
            'Jobs':
                DeepScanRun."Jobs Score" += PenaltyPoints;
            'HR':
                DeepScanRun."HR Score" += PenaltyPoints;
        end;
    end;

    local procedure GetSeverityPenalty(Severity: Code[20]): Integer
    begin
        case LowerCase(Format(Severity)) of
            'high':
                exit(6);
            'medium':
                exit(3);
            'low':
                exit(1);
        end;

        exit(2);
    end;

    local procedure GetAffectedPenalty(AffectedCount: Integer): Integer
    begin
        if AffectedCount <= 0 then
            exit(0);
        if AffectedCount >= 5000 then
            exit(8);
        if AffectedCount >= 1000 then
            exit(6);
        if AffectedCount >= 250 then
            exit(4);
        if AffectedCount >= 50 then
            exit(2);
        exit(1);
    end;

    local procedure NormalizeModuleScore(PenaltyTotal: Integer): Integer
    begin
        if PenaltyTotal <= 0 then
            exit(100);

        exit(100 - ((PenaltyTotal * 100) div (PenaltyTotal + 40)));
    end;

    local procedure AddWeightedModuleScore(IsEnabled: Boolean; Weight: Integer; ModuleScore: Integer; var WeightedScoreTotal: Integer; var EnabledWeightTotal: Integer)
    begin
        if not IsEnabled then
            exit;

        WeightedScoreTotal += ModuleScore * Weight;
        EnabledWeightTotal += Weight;
    end;

    local procedure EnsureDashboardHeaderForDeepScan(var DeepScanRun: Record "DH Deep Scan Run")
    var
        ScanHeader: Record "DH Scan Header";
    begin
        ScanHeader.Reset();
        ScanHeader.SetRange("Scan Type", ScanHeader."Scan Type"::Deep);
        ScanHeader.SetRange("Run ID", DeepScanRun."Run ID");

        if not ScanHeader.FindFirst() then begin
            ScanHeader.Reset();
            ScanHeader.SetRange("Scan Type", ScanHeader."Scan Type"::Deep);
            ScanHeader.SetRange("Backend Scan Id", DeepScanRun."Run ID");

            if not ScanHeader.FindFirst() then begin
                ScanHeader.Init();
                ScanHeader."Entry No." := GetNextHeaderEntryNo();
                ScanHeader."Scan Type" := ScanHeader."Scan Type"::Deep;
                ScanHeader."Run ID" := DeepScanRun."Run ID";
                ScanHeader."Backend Scan Id" := DeepScanRun."Run ID";
                ScanHeader.Insert();
            end;
        end;

        if ScanHeader."Run ID" = '' then
            ScanHeader."Run ID" := DeepScanRun."Run ID";

        if DeepScanRun."Finished At" <> 0DT then
            ScanHeader."Scan DateTime" := DeepScanRun."Finished At"
        else
            ScanHeader."Scan DateTime" := DeepScanRun."Requested At";

        ScanHeader."Data Score" := DeepScanRun."Deep Score";
        ScanHeader."Checks Count" := DeepScanRun."Checks Count";
        ScanHeader."Issues Count" := DeepScanRun."Issues Count";
        ScanHeader."Affected Records" := DeepScanRun."Affected Records";
        ScanHeader."System Score" := DeepScanRun."System Score";
        ScanHeader."Finance Score" := DeepScanRun."Finance Score";
        ScanHeader."Sales Score" := DeepScanRun."Sales Score";
        ScanHeader."Purchasing Score" := DeepScanRun."Purchasing Score";
        ScanHeader."Inventory Score" := DeepScanRun."Inventory Score";
        ScanHeader."CRM Score" := DeepScanRun."CRM Score";
        ScanHeader."Manufacturing Score" := DeepScanRun."Manufacturing Score";
        ScanHeader."Service Score" := DeepScanRun."Service Score";
        ScanHeader."Jobs Score" := DeepScanRun."Jobs Score";
        ScanHeader."HR Score" := DeepScanRun."HR Score";
        ScanHeader."Estimated Loss (EUR)" := DeepScanRun."Estimated Loss (EUR)";
        ScanHeader."Potential Saving (EUR)" := DeepScanRun."Potential Saving (EUR)";
        ScanHeader."Est. Loss" := DeepScanRun."Estimated Loss (EUR)";
        ScanHeader."Potential Saving" := DeepScanRun."Potential Saving (EUR)";
        ScanHeader."Headline" := CopyStr(DeepScanRun."Headline", 1, MaxStrLen(ScanHeader."Headline"));
        ScanHeader."Rating" := CopyStr(DeepScanRun."Rating", 1, MaxStrLen(ScanHeader."Rating"));
        ScanHeader."Premium Available" := true;
        ScanHeader.Modify(true);
    end;

    local procedure ApplySyncCommercials(var DeepScanRun: Record "DH Deep Scan Run"; SyncResponseText: Text)
    var
        JsonObj: JsonObject;
        CommercialsToken: JsonToken;
        CommercialsObj: JsonObject;
        Token: JsonToken;
        ScanHeader: Record "DH Scan Header";
    begin
        if SyncResponseText = '' then
            exit;

        if not JsonObj.ReadFrom(SyncResponseText) then
            exit;

        if not JsonObj.Get('commercials', CommercialsToken) then
            exit;

        CommercialsObj := CommercialsToken.AsObject();

        if CommercialsObj.Get('estimated_loss_eur', Token) then
            DeepScanRun."Estimated Loss (EUR)" := ReadJsonDecimal(Token);

        if CommercialsObj.Get('potential_saving_eur', Token) then
            DeepScanRun."Potential Saving (EUR)" := ReadJsonDecimal(Token);

        DeepScanRun.Modify(true);

        ScanHeader.Reset();
        ScanHeader.SetRange("Scan Type", ScanHeader."Scan Type"::Deep);
        ScanHeader.SetRange("Run ID", DeepScanRun."Run ID");
        if not ScanHeader.FindFirst() then begin
            ScanHeader.Reset();
            ScanHeader.SetRange("Scan Type", ScanHeader."Scan Type"::Deep);
            ScanHeader.SetRange("Backend Scan Id", DeepScanRun."Run ID");
            if not ScanHeader.FindFirst() then
                exit;
        end;

        if CommercialsObj.Get('total_records', Token) then
            ScanHeader."Total Records" := Token.AsValue().AsInteger();

        ScanHeader."Estimated Loss (EUR)" := DeepScanRun."Estimated Loss (EUR)";
        ScanHeader."Potential Saving (EUR)" := DeepScanRun."Potential Saving (EUR)";
        ScanHeader."Est. Loss" := DeepScanRun."Estimated Loss (EUR)";
        ScanHeader."Potential Saving" := DeepScanRun."Potential Saving (EUR)";

        if CommercialsObj.Get('premium_price_per_month', Token) then
            ScanHeader."Est. Premium Price" := ReadJsonDecimal(Token)
        else
            if CommercialsObj.Get('estimated_premium_price_monthly', Token) then
                ScanHeader."Est. Premium Price" := ReadJsonDecimal(Token);

        if CommercialsObj.Get('roi_eur', Token) then
            ScanHeader."ROI" := ReadJsonDecimal(Token);

        ScanHeader.Modify(true);
    end;

    local procedure ApplySyncFindingImpacts(var DeepScanRun: Record "DH Deep Scan Run"; SyncResponseText: Text)
    var
        JsonObj: JsonObject;
        IssuesToken: JsonToken;
        IssuesArray: JsonArray;
        IssueToken: JsonToken;
        IssueObj: JsonObject;
        Finding: Record "DH Deep Scan Finding";
        i: Integer;
        CodeTxt: Text;
    begin
        if SyncResponseText = '' then
            exit;

        if not JsonObj.ReadFrom(SyncResponseText) then
            exit;

        if not JsonObj.Get('issues', IssuesToken) then
            exit;

        IssuesArray := IssuesToken.AsArray();

        for i := 0 to IssuesArray.Count() - 1 do begin
            IssuesArray.Get(i, IssueToken);
            IssueObj := IssueToken.AsObject();
            CodeTxt := GetJsonText(IssueObj, 'code');

            Finding.Reset();
            Finding.SetRange("Deep Scan Entry No.", DeepScanRun."Entry No.");
            Finding.SetRange("Issue Code", CopyStr(CodeTxt, 1, MaxStrLen(Finding."Issue Code")));
            if Finding.FindFirst() then begin
                Finding."Estimated Impact (EUR)" := ReadJsonDecimalFromObject(IssueObj, 'estimated_impact_eur');
                Finding.Modify(true);
            end;
        end;
    end;

    local procedure GetJsonText(var JsonObj: JsonObject; FieldName: Text): Text
    var
        Token: JsonToken;
    begin
        if JsonObj.Get(FieldName, Token) then
            if not IsJsonNull(Token) then
                exit(Token.AsValue().AsText());

        exit('');
    end;

    local procedure ReadJsonDecimalFromObject(var JsonObj: JsonObject; FieldName: Text): Decimal
    var
        Token: JsonToken;
    begin
        if JsonObj.Get(FieldName, Token) then
            if not IsJsonNull(Token) then
                exit(ReadJsonDecimal(Token));

        exit(0);
    end;

    local procedure ReadJsonDecimal(Token: JsonToken): Decimal
    var
        ValueText: Text;
        ValueDecimal: Decimal;
    begin
        if IsJsonNull(Token) then
            exit(0);

        ValueText := DelChr(Token.AsValue().AsText(), '=', ' ');
        if ValueText = '' then
            exit(0);

        if TryEvaluateDecimal(ValueText, ValueDecimal) then
            exit(ValueDecimal);

        if (StrPos(ValueText, '.') > 0) and (StrPos(ValueText, ',') = 0) then begin
            ValueText := ConvertStr(ValueText, '.', ',');
            if TryEvaluateDecimal(ValueText, ValueDecimal) then
                exit(ValueDecimal);
        end;

        if (StrPos(ValueText, '.') > 0) and (StrPos(ValueText, ',') > 0) then begin
            ValueText := DelChr(ValueText, '=', '.');
            if TryEvaluateDecimal(ValueText, ValueDecimal) then
                exit(ValueDecimal);
        end;

        Error('Could not parse decimal value from backend JSON: %1', Token.AsValue().AsText());
    end;

    [TryFunction]
    local procedure TryEvaluateDecimal(ValueText: Text; var ValueDecimal: Decimal)
    begin
        Evaluate(ValueDecimal, ValueText);
    end;

    local procedure IsJsonNull(Token: JsonToken): Boolean
    var
        JsonValueText: Text;
    begin
        JsonValueText := LowerCase(Format(Token));
        exit((JsonValueText = 'null') or (JsonValueText = '<null>'));
    end;

    local procedure BuildSyncPayload(var Setup: Record "DH Setup"; var DeepScanRun: Record "DH Deep Scan Run"): Text
    var
        Finding: Record "DH Deep Scan Finding";
        Payload: JsonObject;
        IssuesArray: JsonArray;
        IssueObject: JsonObject;
        ScanDateTime: DateTime;
        RequestText: Text;
        DataProfilingMgt: Codeunit "DH Data Profiling Mgt.";
    begin
        if DeepScanRun."Finished At" <> 0DT then
            ScanDateTime := DeepScanRun."Finished At"
        else
            ScanDateTime := DeepScanRun."Requested At";

        Payload.Add('tenant_id', Setup."Tenant ID");
        Payload.Add('scan_id', Format(DeepScanRun."Run ID"));
        Payload.Add('bc_run_id', DeepScanRun."Run ID");
        Payload.Add('scan_type', 'deep');
        Payload.Add('generated_at_utc', Format(ScanDateTime, 0, 9));
        Payload.Add('data_score', DeepScanRun."Deep Score");
        Payload.Add('checks_count', DeepScanRun."Checks Count");
        Payload.Add('issues_count', DeepScanRun."Issues Count");
        Payload.Add('premium_available', true);
        Payload.Add('data_profile', DataProfilingMgt.BuildDataProfile());
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
        Finding."Estimated Impact (EUR)" := 0;
        Finding.Insert(true);
    end;

    local procedure ClearDeepScanCommercials(var DeepScanRun: Record "DH Deep Scan Run")
    begin
        DeepScanRun."Estimated Loss (EUR)" := 0;
        DeepScanRun."Potential Saving (EUR)" := 0;
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
