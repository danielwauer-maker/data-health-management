page 53158 "DH Deep Scan Monitor"
{
    PageType = Card;
    SourceTable = "DH Deep Scan Run";
    ApplicationArea = All;
    UsageCategory = None;
    Caption = 'BCSentinel Scan Monitor';
    DataCaptionExpression = Rec."Run ID";
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    RefreshOnActivate = true;

    layout
    {
        area(Content)
        {
            group(Overview)
            {
                Caption = 'Overview';

                field(ScanStatus; ScanStatusTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Scan Status';
                    StyleExpr = ScanStatusStyle;
                }
                field(Status; StatusTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Status';
                }
                field("Current Module"; CurrentModuleTxt)
                {
                    ApplicationArea = All;
                }
                field(OverallBar; OverallBarTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Overall Progress';
                    StyleExpr = ProgressStyle;
                }
                field(ETA; ETATxt)
                {
                    ApplicationArea = All;
                    Caption = 'ETA';
                }
                field("Started At"; StartedAtValue)
                {
                    ApplicationArea = All;
                }
                field("Finished At"; FinishedAtValue)
                {
                    ApplicationArea = All;
                }
                field(Headline; HeadlineTxt)
                {
                    ApplicationArea = All;
                    MultiLine = true;
                }
            }
            part(KpiTiles; "DH Dashboard KPI Part")
            {
                ApplicationArea = All;
                Caption = 'Key Metrics';
            }

            group(OnlineDashboard)
            {
                Caption = 'Online';

                field(OpenExternalDashboardLink; OpenDashboardLinkTxt)
                {
                    ApplicationArea = All;
                    Caption = 'External Dashboard';
                    Editable = false;
                    DrillDown = true;
                    StyleExpr = OpenDashboardLinkStyle;
                    ToolTip = 'Open the external BCSentinel dashboard for this scan.';

                    trigger OnDrillDown()
                    begin
                        OpenAnalyticsDashboardForCurrentScan();
                    end;
                }
            }

            group(ScanResults)
            {
                Caption = 'Scan Results';

                field("Scanned Records"; ScannedRecordsValue)
                {
                    ApplicationArea = All;
                    Caption = 'Scanned Records';
                }
                field("Affected Records Header"; AffectedRecordsValue)
                {
                    ApplicationArea = All;
                    Caption = 'Affected Records';
                }

                field("Estimated Loss"; EstimatedLossValue)
                {
                    ApplicationArea = All;
                    Caption = 'Estimated Loss';
                    StyleExpr = EstimatedLossStyle;
                }
                field("Potential Saving"; PotentialSavingValue)
                {
                    ApplicationArea = All;
                    Caption = 'Potential Saving';
                    StyleExpr = PotentialSavingStyle;
                }
            }



            group(ModuleProgress)
            {
                Caption = 'Module Progress';

                field(SystemProgress; SystemProgressTxt)
                {
                    ApplicationArea = All;
                    Caption = 'System';
                    Visible = ShowSystem;
                    StyleExpr = SystemProgressStyle;
                }
                field(FinanceProgress; FinanceProgressTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Finance';
                    Visible = ShowFinance;
                    StyleExpr = FinanceProgressStyle;
                }
                field(SalesProgress; SalesProgressTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Sales';
                    Visible = ShowSales;
                    StyleExpr = SalesProgressStyle;
                }
                field(PurchasingProgress; PurchasingProgressTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Purchasing';
                    Visible = ShowPurchasing;
                    StyleExpr = PurchasingProgressStyle;
                }
                field(InventoryProgress; InventoryProgressTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Inventory';
                    Visible = ShowInventory;
                    StyleExpr = InventoryProgressStyle;
                }
                field(CRMProgress; CRMProgressTxt)
                {
                    ApplicationArea = All;
                    Caption = 'CRM';
                    Visible = ShowCRM;
                    StyleExpr = CRMProgressStyle;
                }
                field(ManufacturingProgress; ManufacturingProgressTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Manufacturing';
                    Visible = ShowManufacturing;
                    StyleExpr = ManufacturingProgressStyle;
                }
                field(ServiceProgress; ServiceProgressTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Service';
                    Visible = ShowService;
                    StyleExpr = ServiceProgressStyle;
                }
                field(JobsProgress; JobsProgressTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Jobs';
                    Visible = ShowJobs;
                    StyleExpr = JobsProgressStyle;
                }
                field(HRProgress; HRProgressTxt)
                {
                    ApplicationArea = All;
                    Caption = 'HR';
                    Visible = ShowHR;
                    StyleExpr = HRProgressStyle;
                }
            }

            group(ModuleScores)
            {
                Caption = 'Module Scores';

                field("System Score"; SystemScoreValue)
                {
                    ApplicationArea = All;
                    Caption = 'System';
                    Visible = ShowSystem;
                    StyleExpr = SystemScoreStyle;
                }
                field("Finance Score"; FinanceScoreValue)
                {
                    ApplicationArea = All;
                    Caption = 'Finance';
                    Visible = ShowFinance;
                    StyleExpr = FinanceScoreStyle;
                }
                field("Sales Score"; SalesScoreValue)
                {
                    ApplicationArea = All;
                    Caption = 'Sales';
                    Visible = ShowSales;
                    StyleExpr = SalesScoreStyle;
                }
                field("Purchasing Score"; PurchasingScoreValue)
                {
                    ApplicationArea = All;
                    Caption = 'Purchasing';
                    Visible = ShowPurchasing;
                    StyleExpr = PurchasingScoreStyle;
                }
                field("Inventory Score"; InventoryScoreValue)
                {
                    ApplicationArea = All;
                    Caption = 'Inventory';
                    Visible = ShowInventory;
                    StyleExpr = InventoryScoreStyle;
                }
                field("CRM Score"; CRMScoreValue)
                {
                    ApplicationArea = All;
                    Caption = 'CRM';
                    Visible = ShowCRM;
                    StyleExpr = CRMScoreStyle;
                }
                field("Manufacturing Score"; ManufacturingScoreValue)
                {
                    ApplicationArea = All;
                    Caption = 'Manufacturing';
                    Visible = ShowManufacturing;
                    StyleExpr = ManufacturingScoreStyle;
                }
                field("Service Score"; ServiceScoreValue)
                {
                    ApplicationArea = All;
                    Caption = 'Service';
                    Visible = ShowService;
                    StyleExpr = ServiceScoreStyle;
                }
                field("Jobs Score"; JobsScoreValue)
                {
                    ApplicationArea = All;
                    Caption = 'Jobs';
                    Visible = ShowJobs;
                    StyleExpr = JobsScoreStyle;
                }
                field("HR Score"; HRScoreValue)
                {
                    ApplicationArea = All;
                    Caption = 'HR';
                    Visible = ShowHR;
                    StyleExpr = HRScoreStyle;
                }
            }

            part(Findings; "DH Deep Scan Findings")
            {
                ApplicationArea = All;
                Caption = 'Issues';
                UpdatePropagation = Both;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(RefreshProgress)
            {
                Caption = 'Refresh';
                ApplicationArea = All;
                Image = Refresh;

                trigger OnAction()
                begin
                    ReloadMonitor();
                end;
            }

            action(OpenAllIssues)
            {
                Caption = 'Open Issues';
                ApplicationArea = All;
                Image = List;

                trigger OnAction()
                var
                    Finding: Record "DH Deep Scan Finding";
                begin
                    if Rec."Entry No." = 0 then
                        Error('No deep scan run is available.');

                    Finding.SetRange("Deep Scan Entry No.", Rec."Entry No.");
                    Page.Run(Page::"DH Deep Scan Findings", Finding);
                end;
            }


            action(OpenExternalDashboard)
            {
                Caption = 'Open BCSentinel Dashboard';
                ApplicationArea = All;
                Image = View;
                ToolTip = 'Open the external BCSentinel dashboard for the current scan.';

                trigger OnAction()
                begin
                    OpenAnalyticsDashboardForCurrentScan();
                end;
            }

            action(UpgradeToPremium)
            {
                Caption = 'Upgrade to Premium';
                ApplicationArea = All;
                Image = Add;
                ToolTip = 'Open the secure BCSentinel checkout to activate Premium.';

                trigger OnAction()
                var
                    Setup: Record "DH Setup";
                    ApiClient: Codeunit "DH API Client";
                begin
                    LoadSetupOrError(Setup);

                    if Setup.IsPremiumLicenseActive() then begin
                        Message('Premium is already active for this tenant.');
                        exit;
                    end;

                    ApiClient.OpenPremiumCheckout(Setup);
                end;
            }

            action(RefreshLicenseStatus)
            {
                Caption = 'Refresh License Status';
                ApplicationArea = All;
                Image = Refresh;
                ToolTip = 'Refresh current plan and license status from BCSentinel.';

                trigger OnAction()
                var
                    Setup: Record "DH Setup";
                    ApiClient: Codeunit "DH API Client";
                begin
                    LoadSetupOrError(Setup);
                    ApiClient.RefreshLicenseStatus(Setup);
                    Message('License status refreshed.');
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        ReloadMonitor();
    end;

    trigger OnAfterGetRecord()
    begin
        ReloadDisplayValuesFromRec();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        ApplyIssuePartFilter();

        if not AutoRefreshStarted then begin
            AutoRefreshStarted := true;
            QueueAutoRefresh();
        end;
    end;

    trigger OnPageBackgroundTaskCompleted(TaskId: Integer; Results: Dictionary of [Text, Text])
    begin
        if TaskId <> RefreshTaskId then
            exit;

        RefreshTaskRunning := false;
        ReloadMonitor();

        if ShouldKeepRefreshing() then
            QueueAutoRefresh();
    end;

    trigger OnPageBackgroundTaskError(TaskId: Integer; ErrorCode: Text; ErrorText: Text; ErrorCallStack: Text; var IsHandled: Boolean)
    begin
        if TaskId <> RefreshTaskId then
            exit;

        RefreshTaskRunning := false;
        IsHandled := true;

        ReloadMonitor();

        if ShouldKeepRefreshing() then
            QueueAutoRefresh();
    end;

    var
        RefreshTaskId: Integer;
        RefreshTaskRunning: Boolean;
        AutoRefreshStarted: Boolean;
        DashboardScanEntryNo: Integer;
        ShowSystem: Boolean;
        ShowFinance: Boolean;
        ShowSales: Boolean;
        ShowPurchasing: Boolean;
        ShowInventory: Boolean;
        ShowCRM: Boolean;
        ShowManufacturing: Boolean;
        ShowService: Boolean;
        ShowJobs: Boolean;
        ShowHR: Boolean;

        RunIdTxt: Code[50];
        StatusTxt: Text[50];
        CurrentModuleTxt: Text[50];
        ProgressPct: Integer;
        OverallBarTxt: Text[50];
        ETATxt: Text[100];
        StartedAtValue: DateTime;
        FinishedAtValue: DateTime;
        HeadlineTxt: Text[250];
        ScanDateTimeValue: DateTime;
        ScanTypeTxt: Text[30];
        RatingTxt: Text[30];
        ScannedRecordsValue: Integer;
        EstimatedLossValue: Decimal;
        PotentialSavingValue: Decimal;
        EstimatedLossStyle: Text[30];
        PotentialSavingStyle: Text[30];
        OpenDashboardLinkTxt: Text[100];
        OpenDashboardLinkStyle: Text[30];
        DeepScoreValue: Integer;
        ChecksCountValue: Integer;
        IssuesCountValue: Integer;
        AffectedRecordsValue: Integer;
        SystemScoreValue: Integer;
        FinanceScoreValue: Integer;
        SalesScoreValue: Integer;
        PurchasingScoreValue: Integer;
        InventoryScoreValue: Integer;
        CRMScoreValue: Integer;
        ManufacturingScoreValue: Integer;
        ServiceScoreValue: Integer;
        JobsScoreValue: Integer;
        HRScoreValue: Integer;
        SystemProgressTxt: Text[60];
        FinanceProgressTxt: Text[60];
        SalesProgressTxt: Text[60];
        PurchasingProgressTxt: Text[60];
        InventoryProgressTxt: Text[60];
        CRMProgressTxt: Text[60];
        ManufacturingProgressTxt: Text[60];
        ServiceProgressTxt: Text[60];
        JobsProgressTxt: Text[60];
        HRProgressTxt: Text[60];
        ScanStatusTxt: Text[50];
        ScanStatusStyle: Text[30];
        ProgressStyle: Text[30];
        ScoreStyle: Text[30];
        IssuesStyle: Text[30];
        RatingStyle: Text[30];
        SystemScoreStyle: Text[30];
        FinanceScoreStyle: Text[30];
        SalesScoreStyle: Text[30];
        PurchasingScoreStyle: Text[30];
        InventoryScoreStyle: Text[30];
        CRMScoreStyle: Text[30];
        ManufacturingScoreStyle: Text[30];
        ServiceScoreStyle: Text[30];
        JobsScoreStyle: Text[30];
        HRScoreStyle: Text[30];
        SystemProgressStyle: Text[30];
        FinanceProgressStyle: Text[30];
        SalesProgressStyle: Text[30];
        PurchasingProgressStyle: Text[30];
        InventoryProgressStyle: Text[30];
        CRMProgressStyle: Text[30];
        ManufacturingProgressStyle: Text[30];
        ServiceProgressStyle: Text[30];
        JobsProgressStyle: Text[30];
        HRProgressStyle: Text[30];

    local procedure ReloadMonitor()
    var
        DeepScanRun: Record "DH Deep Scan Run";
    begin
        UpdateModuleVisibility();

        if DeepScanRun.Get(Rec."Entry No.") then begin
            Rec := DeepScanRun;
            ReloadDisplayValuesFromRec();
            LoadDashboardValues();
            ApplyIssuePartFilter();
            CurrPage.Update(false);
        end;
    end;

    local procedure ReloadDisplayValuesFromRec()
    begin
        RunIdTxt := Rec."Run ID";
        StatusTxt := Format(Rec.Status);
        CurrentModuleTxt := Rec."Current Module";
        ProgressPct := Rec."Progress %";
        OverallBarTxt := BuildBar(ProgressPct);
        ETATxt := Rec."ETA Text";
        StartedAtValue := Rec."Started At";
        FinishedAtValue := Rec."Finished At";
        HeadlineTxt := Rec.Headline;

        DeepScoreValue := Rec."Deep Score";
        ChecksCountValue := Rec."Checks Count";
        IssuesCountValue := Rec."Issues Count";
        AffectedRecordsValue := Rec."Affected Records";

        SystemScoreValue := Rec."System Score";
        FinanceScoreValue := Rec."Finance Score";
        SalesScoreValue := Rec."Sales Score";
        PurchasingScoreValue := Rec."Purchasing Score";
        InventoryScoreValue := Rec."Inventory Score";
        CRMScoreValue := Rec."CRM Score";
        ManufacturingScoreValue := Rec."Manufacturing Score";
        ServiceScoreValue := Rec."Service Score";
        JobsScoreValue := Rec."Jobs Score";
        HRScoreValue := Rec."HR Score";

        SystemProgressTxt := BuildModuleText('System', Rec."System Progress %");
        FinanceProgressTxt := BuildModuleText('Finance', Rec."Finance Progress %");
        SalesProgressTxt := BuildModuleText('Sales', Rec."Sales Progress %");
        PurchasingProgressTxt := BuildModuleText('Purchasing', Rec."Purchasing Progress %");
        InventoryProgressTxt := BuildModuleText('Inventory', Rec."Inventory Progress %");
        CRMProgressTxt := BuildModuleText('CRM', Rec."CRM Progress %");
        ManufacturingProgressTxt := BuildModuleText('Manufacturing', Rec."Manufacturing Progress %");
        ServiceProgressTxt := BuildModuleText('Service', Rec."Service Progress %");
        JobsProgressTxt := BuildModuleText('Jobs', Rec."Jobs Progress %");
        HRProgressTxt := BuildModuleText('HR', Rec."HR Progress %");

        ScanStatusTxt := GetScanStatusText();
        ScanStatusStyle := GetScanStatusStyle();
        ProgressStyle := GetProgressStyle(ProgressPct);
        ScoreStyle := GetScoreStyle(DeepScoreValue);
        IssuesStyle := GetIssuesStyle();
        EstimatedLossStyle := 'Unfavorable';
        PotentialSavingStyle := 'Strong';
        OpenDashboardLinkTxt := 'Open Analytics-Dashboard';
        OpenDashboardLinkStyle := 'Strong';

        SystemScoreStyle := GetScoreStyle(SystemScoreValue);
        FinanceScoreStyle := GetScoreStyle(FinanceScoreValue);
        SalesScoreStyle := GetScoreStyle(SalesScoreValue);
        PurchasingScoreStyle := GetScoreStyle(PurchasingScoreValue);
        InventoryScoreStyle := GetScoreStyle(InventoryScoreValue);
        CRMScoreStyle := GetScoreStyle(CRMScoreValue);
        ManufacturingScoreStyle := GetScoreStyle(ManufacturingScoreValue);
        ServiceScoreStyle := GetScoreStyle(ServiceScoreValue);
        JobsScoreStyle := GetScoreStyle(JobsScoreValue);
        HRScoreStyle := GetScoreStyle(HRScoreValue);

        SystemProgressStyle := GetProgressStyle(Rec."System Progress %");
        FinanceProgressStyle := GetProgressStyle(Rec."Finance Progress %");
        SalesProgressStyle := GetProgressStyle(Rec."Sales Progress %");
        PurchasingProgressStyle := GetProgressStyle(Rec."Purchasing Progress %");
        InventoryProgressStyle := GetProgressStyle(Rec."Inventory Progress %");
        CRMProgressStyle := GetProgressStyle(Rec."CRM Progress %");
        ManufacturingProgressStyle := GetProgressStyle(Rec."Manufacturing Progress %");
        ServiceProgressStyle := GetProgressStyle(Rec."Service Progress %");
        JobsProgressStyle := GetProgressStyle(Rec."Jobs Progress %");
        HRProgressStyle := GetProgressStyle(Rec."HR Progress %");
    end;

    local procedure LoadDashboardValues()
    var
        ScanHeader: Record "DH Scan Header";
    begin
        DashboardScanEntryNo := 0;
        ScanDateTimeValue := 0DT;
        ScanTypeTxt := '';
        RatingTxt := '';
        RatingStyle := 'Standard';
        ScannedRecordsValue := 0;
        EstimatedLossValue := 0;
        PotentialSavingValue := 0;

        if Rec."Run ID" = '' then
            exit;

        ScanDateTimeValue := Rec."Finished At";
        if ScanDateTimeValue = 0DT then
            ScanDateTimeValue := Rec."Requested At";

        ScanTypeTxt := 'Deep';
        RatingTxt := Rec.Rating;
        RatingStyle := GetRatingStyle(Rec.Rating);
        ScannedRecordsValue := Rec."Total Records";
        EstimatedLossValue := Rec."Estimated Loss (EUR)";
        PotentialSavingValue := Rec."Potential Saving (EUR)";

        if EstimatedLossValue < 0 then
            EstimatedLossValue := 0;

        if PotentialSavingValue < 0 then
            PotentialSavingValue := 0;

        if (EstimatedLossValue > 0) and (PotentialSavingValue > EstimatedLossValue) then
            PotentialSavingValue := EstimatedLossValue;

        if (DeepScoreValue = 0) and (Rec."Deep Score" <> 0) then
            DeepScoreValue := Rec."Deep Score";
        if (ChecksCountValue = 0) and (Rec."Checks Count" <> 0) then
            ChecksCountValue := Rec."Checks Count";
        if (IssuesCountValue = 0) and (Rec."Issues Count" <> 0) then
            IssuesCountValue := Rec."Issues Count";
        if (AffectedRecordsValue = 0) and (Rec."Affected Records" <> 0) then
            AffectedRecordsValue := Rec."Affected Records";

        ScanHeader.SetRange("Run ID", Rec."Run ID");
        if ScanHeader.FindFirst() then
            DashboardScanEntryNo := ScanHeader."Entry No.";
    end;

    local procedure ApplyIssuePartFilter()
    begin
        if DashboardScanEntryNo <> 0 then begin
            CurrPage.KpiTiles.Page.SetDeepScanRunEntryNo(Rec."Entry No.");
            CurrPage.Findings.Page.SetDeepScanEntryNo(Rec."Entry No.");
        end else begin
            CurrPage.KpiTiles.Page.SetDeepScanRunEntryNo(-1);
            CurrPage.Findings.Page.SetDeepScanEntryNo(-1);
        end;
    end;

    local procedure QueueAutoRefresh()
    var
        Parameters: Dictionary of [Text, Text];
    begin
        if RefreshTaskRunning then
            exit;

        if not ShouldKeepRefreshing() then
            exit;

        Parameters.Add('EntryNo', Format(Rec."Entry No."));
        Parameters.Add('WaitMs', '1500');
        CurrPage.EnqueueBackgroundTask(RefreshTaskId, Codeunit::"DH Monitor Refresh Task", Parameters, 4000, PageBackgroundTaskErrorLevel::Ignore);
        RefreshTaskRunning := true;
    end;

    local procedure ShouldKeepRefreshing(): Boolean
    begin
        exit((Rec.Status = Rec.Status::Queued) or (Rec.Status = Rec.Status::Running));
    end;

    local procedure UpdateModuleVisibility()
    var
        Setup: Record "DH Setup";
    begin
        ShowSystem := true;
        ShowFinance := true;
        ShowSales := true;
        ShowPurchasing := true;
        ShowInventory := true;
        ShowCRM := true;
        ShowManufacturing := true;
        ShowService := true;
        ShowJobs := true;
        ShowHR := true;

        if Setup.Get('SETUP') then begin
            Setup.ApplyDefaults();
            ShowSystem := Setup."Scan System Module";
            ShowFinance := Setup."Scan Finance Module";
            ShowSales := Setup."Scan Sales Module";
            ShowPurchasing := Setup."Scan Purchasing Module";
            ShowInventory := Setup."Scan Inventory Module";
            ShowCRM := Setup."Scan CRM Module";
            ShowManufacturing := Setup."Scan Manufacturing Module";
            ShowService := Setup."Scan Service Module";
            ShowJobs := Setup."Scan Jobs Module";
            ShowHR := Setup."Scan HR Module";
        end;
    end;

    local procedure BuildModuleText(ModuleName: Text; PercentValue: Integer): Text
    begin
        exit(StrSubstNo('%1  %2%  %3', ModuleName, PercentValue, BuildBar(PercentValue)));
    end;

    local procedure BuildBar(PercentValue: Integer): Text
    var
        Filled: Integer;
        i: Integer;
        BarTxt: Text;
    begin
        if PercentValue < 0 then
            PercentValue := 0;
        if PercentValue > 100 then
            PercentValue := 100;

        Filled := PercentValue div 10;
        if (PercentValue mod 10) > 0 then
            Filled += 1;

        for i := 1 to 10 do
            if i <= Filled then
                BarTxt += '█'
            else
                BarTxt += '░';

        exit(BarTxt);
    end;

    local procedure GetProgressStyle(Value: Integer): Text
    begin
        if Value <= 0 then
            exit('Standard');
        if Value < 30 then
            exit('Unfavorable');
        if Value < 70 then
            exit('Ambiguous');
        if Value < 100 then
            exit('Favorable');
        exit('Strong');
    end;

    local procedure GetScoreStyle(Value: Integer): Text
    begin
        if Value <= 60 then
            exit('Unfavorable');
        if Value <= 75 then
            exit('Ambiguous');
        if Value <= 95 then
            exit('Favorable');
        exit('Strong');
    end;

    local procedure GetIssuesStyle(): Text
    begin
        if IssuesCountValue > 0 then
            exit('Attention');
        exit('Standard');
    end;

    local procedure GetRatingStyle(RatingValue: Code[20]): Text
    begin
        case LowerCase(Format(RatingValue)) of
            'critical':
                exit('Unfavorable');
            'warning', 'moderate':
                exit('Ambiguous');
            'good':
                exit('Favorable');
            'excellent':
                exit('Strong');
        end;

        exit('Standard');
    end;

    local procedure GetScanStatusText(): Text
    begin
        case Rec.Status of
            Rec.Status::Queued:
                exit('Preparing scan...');
            Rec.Status::Running:
                exit('Scanning data...');
            Rec.Status::Completed:
                exit('Scan completed');
            Rec.Status::Failed:
                exit('Scan failed');
            Rec.Status::Canceled:
                exit('Scan canceled');
        end;
        exit('Unknown');
    end;

    local procedure GetScanStatusStyle(): Text
    begin
        case Rec.Status of
            Rec.Status::Queued:
                exit('Ambiguous');
            Rec.Status::Running:
                exit('Favorable');
            Rec.Status::Completed:
                exit('Strong');
            Rec.Status::Failed, Rec.Status::Canceled:
                exit('Unfavorable');
        end;
        exit('Standard');
    end;

    local procedure OpenAnalyticsDashboardForCurrentScan()
    var
        Setup: Record "DH Setup";
        ApiClient: Codeunit "DH API Client";
        Token: Text;
    begin
        LoadSetupOrError(Setup);

        Token := ApiClient.GetAnalyticsDashboardToken(Setup);

        if Token = '' then
            Error('No valid dashboard token was returned by the token service.');

        Hyperlink(GetDashboardUrl(Setup, Token));
    end;

    local procedure LoadSetupOrError(var Setup: Record "DH Setup")
    begin
        if not Setup.Get('SETUP') then
            Error('DH Setup was not found.');

        if Setup."API Base URL" = '' then
            Error('Please enter the API Base URL in DH Setup first.');

        if Setup."Tenant ID" = '' then
            Error('Please register the tenant in DH Setup first.');

        if Setup."API Token" = '' then
            Error('Please register the tenant in DH Setup first so that an API token is stored.');
    end;

    local procedure RequestDashboardToken(var Setup: Record "DH Setup"): Text
    var
        Client: HttpClient;
        Request: HttpRequestMessage;
        Headers: HttpHeaders;
        Response: HttpResponseMessage;
        ResponseText: Text;
    begin
        Request.Method := 'GET';
        Request.SetRequestUri(GetTokenUrl(Setup));
        Request.GetHeaders(Headers);
        Headers.Clear();
        Headers.Add('X-Tenant-Id', Setup."Tenant ID");
        Headers.Add('X-Api-Token', Setup."API Token");

        if not Client.Send(Request, Response) then
            Error('The dashboard token service could not be reached.');

        Response.Content().ReadAs(ResponseText);

        if not Response.IsSuccessStatusCode() then
            Error(
              'The dashboard token service returned an error. Status: %1. Response: %2',
              Response.HttpStatusCode(),
              CopyStr(ResponseText, 1, 1024));

        exit(ResponseText);
    end;


    local procedure GetTokenUrl(var Setup: Record "DH Setup"): Text
    var
        BaseUrl: Text;
        CompanyValue: Text;
        EnvironmentValue: Text;
        TenantValue: Text;
        ScanModeValue: Text;
    begin
        BaseUrl := BuildUrl(Setup."API Base URL", '/analytics/get-token');
        CompanyValue := EncodeUrlValue(CompanyName());
        EnvironmentValue := EncodeUrlValue('BC Cloud');
        TenantValue := EncodeUrlValue(Setup."Tenant ID");
        ScanModeValue := EncodeUrlValue(GetScanModeQueryValue());

        exit(
          BaseUrl +
          '?company=' + CompanyValue +
          '&environment=' + EnvironmentValue +
          '&tenant_id=' + TenantValue +
          '&scan_mode=' + ScanModeValue);
    end;

    local procedure GetDashboardUrl(var Setup: Record "DH Setup"; Token: Text): Text
    var
        BaseUrl: Text;
    begin
        BaseUrl := BuildUrl(Setup."API Base URL", '/analytics/embed');
        exit(BaseUrl + '?token=' + EncodeUrlValue(Token));
    end;

    local procedure GetScanModeQueryValue(): Text
    begin
        if ScanTypeTxt <> '' then
            exit(LowerCase(ScanTypeTxt));

        exit('deep');
    end;

    local procedure ExtractTokenFromJson(JsonText: Text): Text
    var
        JsonObj: JsonObject;
        JsonToken: JsonToken;
    begin
        if not JsonObj.ReadFrom(JsonText) then
            Error('The token service response is not valid JSON.');

        if not JsonObj.Get('token', JsonToken) then
            Error('The field "token" is missing in the token service response.');

        exit(JsonToken.AsValue().AsText());
    end;

    local procedure BuildUrl(BaseUrl: Text; RelativePath: Text): Text
    begin
        exit(RemoveTrailingSlash(BaseUrl) + RelativePath);
    end;

    local procedure RemoveTrailingSlash(Value: Text): Text
    begin
        while (StrLen(Value) > 0) and (CopyStr(Value, StrLen(Value), 1) = '/') do
            Value := CopyStr(Value, 1, StrLen(Value) - 1);

        exit(Value);
    end;

    local procedure EncodeUrlValue(Value: Text): Text
    begin
        Value := Value.Replace('%', '%25');
        Value := Value.Replace(' ', '%20');
        Value := Value.Replace('&', '%26');
        Value := Value.Replace('?', '%3F');
        Value := Value.Replace('=', '%3D');
        Value := Value.Replace('#', '%23');
        Value := Value.Replace('+', '%2B');
        Value := Value.Replace('/', '%2F');
        exit(Value);
    end;
}
