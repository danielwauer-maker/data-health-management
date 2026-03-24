page 53120 "DH Dashboard"
{
    PageType = Card;
    SourceTable = "DH Scan Header";
    ApplicationArea = All;
    UsageCategory = None;
    Caption = 'BCSentinel Dashboard';
    DataCaptionExpression = Rec.GetDisplayRunId();

    layout
    {
        area(Content)
        {
            group(ScanResults)
            {
                Caption = 'Scan Results';

                group(Header)
                {
                    ShowCaption = false;

                    field(DisplayRunId; Rec.GetDisplayRunId())
                    {
                        ApplicationArea = All;
                        Caption = 'Run ID';
                        Style = Strong;
                        ToolTip = 'Eindeutige Run ID des Scans.';
                    }

                    field("Scan DateTime"; Rec."Scan DateTime")
                    {
                        ApplicationArea = All;
                        Caption = 'Scan Time';
                        ToolTip = 'Zeitpunkt des Scans.';
                    }

                    field("Scan Type"; Rec."Scan Type")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Typ des Scans.';
                    }

                    field("Headline"; Rec."Headline")
                    {
                        ApplicationArea = All;
                        MultiLine = true;
                        ToolTip = 'Zusammenfassung des Scan-Ergebnisses.';
                    }

                    field("Total Records"; Rec."Total Records")
                    {
                        ApplicationArea = All;
                        Caption = 'Datensätze';
                        ToolTip = 'Anzahl der berücksichtigten Datensätze.';
                    }

                    field("Rating"; Rec."Rating")
                    {
                        ApplicationArea = All;
                        StyleExpr = RatingStyle;
                        ToolTip = 'Bewertung des Gesamtergebnisses.';
                    }
                }

                part(KpiTiles; "DH Dashboard KPI Part")
                {
                    ApplicationArea = All;
                    Caption = 'Key Metrics';
                    SubPageLink = "Entry No." = field("Entry No.");
                }
            }

            part(Issues; "DH Dashboard Issues")
            {
                ApplicationArea = All;
                SubPageLink = "Dashboard Scan Entry No." = field("Entry No.");
                UpdatePropagation = Both;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(StartScan)
            {
                Caption = 'Start Scan';
                ApplicationArea = All;
                Image = Calculate;

                trigger OnAction()
                begin
                    StartScanForCurrentTenant();
                end;
            }

            action(OpenAnalyticsDashboard)
            {
                Caption = 'Analytics Dashboard öffnen';
                ApplicationArea = All;
                Image = View;
                ToolTip = 'Öffnet das externe Data Health Management Analytics Dashboard für den aktuellen Scan.';

                trigger OnAction()
                begin
                    OpenAnalyticsDashboardForCurrentScan();
                end;
            }

            action(RefreshDashboard)
            {
                Caption = 'Refresh Dashboard';
                ApplicationArea = All;
                Image = Refresh;

                trigger OnAction()
                var
                    DashboardMgt: Codeunit "DH Dashboard Mgt.";
                begin
                    DashboardMgt.RefreshDashboardIssueCache(Rec);
                    CurrPage.Update(false);
                end;
            }

            action(OpenAllIssues)
            {
                Caption = 'Open All Issues';
                ApplicationArea = All;
                Image = List;

                trigger OnAction()
                var
                    DashboardIssue: Record "DH Dashboard Issue";
                    DashboardMgt: Codeunit "DH Dashboard Mgt.";
                begin
                    DashboardMgt.RefreshDashboardIssueCache(Rec);
                    DashboardIssue.SetRange("Dashboard Scan Entry No.", Rec."Entry No.");
                    Page.Run(Page::"DH Dashboard Issues", DashboardIssue);
                end;
            }

            action(OpenSetup)
            {
                Caption = 'Open Setup';
                ApplicationArea = All;
                Image = Setup;
                RunObject = page "DH Setup";
            }
        }
    }

    trigger OnOpenPage()
    var
        DashboardMgt: Codeunit "DH Dashboard Mgt.";
    begin
        DashboardMgt.RefreshDashboardIssueCache(Rec);
        UpdateStyles();
    end;

    trigger OnAfterGetRecord()
    var
        DashboardMgt: Codeunit "DH Dashboard Mgt.";
    begin
        DashboardMgt.RefreshDashboardIssueCache(Rec);
        UpdateStyles();
    end;

    var
        RatingStyle: Text[30];

    local procedure UpdateStyles()
    begin
        RatingStyle := GetRatingStyle();
    end;

    local procedure GetRatingStyle(): Text[30]
    var
        RatingTxt: Text;
    begin
        RatingTxt := UpperCase(Rec."Rating");

        if (RatingTxt = 'CRITICAL') or (RatingTxt = 'HIGH') then
            exit('Unfavorable');

        if (RatingTxt = 'MEDIUM') or (RatingTxt = 'WARNING') then
            exit('Ambiguous');

        if (RatingTxt = 'GOOD') or (RatingTxt = 'LOW') or (RatingTxt = 'OK') then
            exit('Favorable');

        exit('Standard');
    end;

    local procedure StartScanForCurrentTenant()
    var
        Setup: Record "DH Setup";
        QuickScanMgt: Codeunit "DH QuickScan Mgt.";
        DeepScanMgt: Codeunit "DH Deep Scan Mgt.";
    begin
        if not Setup.Get('SETUP') then
            Error('Setup not found.');

        if Setup."Premium Enabled" then begin
            DeepScanMgt.QueueDeepScan(Setup);
            CurrPage.Update(false);
        end else
            QuickScanMgt.RunQuickScanAndOpenDashboard(Setup);
    end;

    local procedure OpenAnalyticsDashboardForCurrentScan()
    var
        Setup: Record "DH Setup";
        Client: HttpClient;
        Response: HttpResponseMessage;
        ResponseText: Text;
        Token: Text;
    begin
        LoadSetupOrError(Setup);

        if not Client.Get(GetTokenUrl(Setup), Response) then
            Error('Der Token-Service konnte nicht erreicht werden.');

        if not Response.IsSuccessStatusCode() then begin
            Response.Content().ReadAs(ResponseText);
            Error(
                'Der Token-Service hat einen Fehler zurückgegeben. Status: %1. Antwort: %2',
                Response.HttpStatusCode(),
                CopyStr(ResponseText, 1, 1024));
        end;

        Response.Content().ReadAs(ResponseText);
        Token := ExtractTokenFromJson(ResponseText);

        if Token = '' then
            Error('In der Antwort des Token-Services wurde kein gültiger Token gefunden.');

        Hyperlink(GetDashboardUrl(Setup, Token));
    end;

    local procedure LoadSetupOrError(var Setup: Record "DH Setup")
    begin
        if not Setup.Get('SETUP') then
            Error('DH Setup wurde nicht gefunden.');

        if Setup."API Base URL" = '' then
            Error('Bitte hinterlegen Sie zuerst die API Base URL im DH Setup.');

        if Setup."Tenant ID" = '' then
            Error('Bitte registrieren Sie zuerst den Tenant im DH Setup.');
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
        case Rec."Scan Type" of
            Rec."Scan Type"::Deep:
                exit('premium_deep');
            else
                exit('quick');
        end;
    end;

    local procedure ExtractTokenFromJson(JsonText: Text): Text
    var
        JsonObj: JsonObject;
        JsonToken: JsonToken;
    begin
        if not JsonObj.ReadFrom(JsonText) then
            Error('Die Antwort des Token-Services ist kein gültiges JSON.');

        if not JsonObj.Get('token', JsonToken) then
            Error('Das Feld "token" fehlt in der Antwort des Token-Services.');

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