page 53110 "BCSentinel Home"
{
    PageType = Card;
    Caption = 'BCSentinel';
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "DH Setup";

    layout
    {
        area(Content)
        {
            group(Overview)
            {
                Caption = 'Overview';

                field("Current Plan"; Rec."Current Plan")
                {
                    ApplicationArea = All;
                    Editable = false;
                }

                field("License Status"; Rec."License Status")
                {
                    ApplicationArea = All;
                    Editable = false;
                }

                field("Last Scan Date"; Rec."Last Scan Date")
                {
                    ApplicationArea = All;
                    Editable = false;
                }

                field("Last Score"; Rec."Last Score")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
            }

            group(ScanInfo)
            {
                Caption = 'Scan';

                field(FeatureAccess; Rec.GetFeatureAccessText())
                {
                    ApplicationArea = All;
                    Caption = 'Feature access';
                    Editable = false;
                    ToolTip = 'Shows whether premium actions are unlocked.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            group(ScanActions)
            {
                Caption = 'Scan';

                action(StartScan)
                {
                    Caption = 'Start Scan';
                    Image = Start;
                    ApplicationArea = All;

                    trigger OnAction()
                    var
                        Setup: Record "DH Setup";
                        ApiClient: Codeunit "DH API Client";
                        DeepScanMgt: Codeunit "DH Deep Scan Mgt.";
                        DeepScanRun: Record "DH Deep Scan Run";
                        EntryNo: Integer;
                    begin
                        EnsureSetup(Setup);
                        ApiClient.EnsureReadyForScan(Setup);

                        EntryNo := DeepScanMgt.QueueDeepScan(Setup);
                        CurrPage.Update(false);

                        if DeepScanRun.Get(EntryNo) then
                            if Setup.IsPremiumLicenseActive() then
                                Message('BCSentinel Premium deep scan queued.\Run ID: %1\Status: %2', DeepScanRun."Run ID", Format(DeepScanRun.Status))
                            else
                                Message('BCSentinel deep scan queued in Free mode.\Run ID: %1\Status: %2\Premium unlocks recommendations and correction actions.', DeepScanRun."Run ID", Format(DeepScanRun.Status));
                    end;
                }

                action(ViewScanHistory)
                {
                    Caption = 'Scan History';
                    Image = List;
                    ApplicationArea = All;

                    trigger OnAction()
                    begin
                        Page.Run(Page::"DH Deep Scan Runs");
                    end;
                }
            }

            group(OnlineActions)
            {
                Caption = 'Online';

                action(OpenDashboard)
                {
                    Caption = 'Open BCSentinel Dashboard';
                    Image = Navigate;
                    ApplicationArea = All;

                    trigger OnAction()
                    var
                        Setup: Record "DH Setup";
                        Client: HttpClient;
                        Response: HttpResponseMessage;
                        ResponseText: Text;
                        Token: Text;
                    begin
                        EnsureSetup(Setup);

                        if not Client.Get(GetTokenUrl(Setup), Response) then
                            Error('The analytics token service could not be reached.');

                        if not Response.IsSuccessStatusCode() then begin
                            Response.Content().ReadAs(ResponseText);
                            Error('Token service failed. Status: %1. Response: %2', Response.HttpStatusCode(), CopyStr(ResponseText, 1, 1024));
                        end;

                        Response.Content().ReadAs(ResponseText);
                        Token := ExtractTokenFromJson(ResponseText);
                        Hyperlink(GetDashboardUrl(Setup, Token));
                    end;
                }
            }

            group(AdminActions)
            {
                Caption = 'Administration';

                action(OpenSetup)
                {
                    Caption = 'Open Setup';
                    Image = Setup;
                    ApplicationArea = All;

                    trigger OnAction()
                    begin
                        Page.Run(Page::"DH Setup");
                    end;
                }

                action(RefreshLicense)
                {
                    Caption = 'Refresh License';
                    Image = Refresh;
                    ApplicationArea = All;

                    trigger OnAction()
                    var
                        Setup: Record "DH Setup";
                        ApiClient: Codeunit "DH API Client";
                    begin
                        EnsureSetup(Setup);
                        ApiClient.RefreshLicenseStatus(Setup);
                        CurrPage.Update(false);
                        Message('BCSentinel license status refreshed.');
                    end;
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        EnsureSetup(Rec);
    end;

    local procedure EnsureSetup(var Setup: Record "DH Setup")
    begin
        if not Setup.Get('SETUP') then begin
            Setup.Init();
            Setup."Primary Key" := 'SETUP';
            Setup.Insert(true);
        end;
    end;

    local procedure GetTokenUrl(var Setup: Record "DH Setup"): Text
    begin
        if Setup."API Base URL" = '' then
            Error('Please configure the API Base URL first.');

        if Setup."Tenant ID" = '' then
            Error('Tenant is not registered yet.');

        exit(RemoveTrailingSlash(Setup."API Base URL") + '/analytics/get-token?company=' + EncodeUrlValue(CompanyName()) + '&environment=' + EncodeUrlValue('BC Cloud') + '&tenant_id=' + EncodeUrlValue(Setup."Tenant ID") + '&scan_mode=' + EncodeUrlValue(GetScanMode(Setup)));
    end;

    local procedure GetScanMode(var Setup: Record "DH Setup"): Text
    begin
        if Setup.IsPremiumLicenseActive() then
            exit('premium_deep');
        exit('free_deep');
    end;

    local procedure GetDashboardUrl(var Setup: Record "DH Setup"; Token: Text): Text
    begin
        exit(RemoveTrailingSlash(Setup."API Base URL") + '/analytics/embed?token=' + EncodeUrlValue(Token));
    end;

    local procedure ExtractTokenFromJson(JsonText: Text): Text
    var
        JsonObj: JsonObject;
        JsonToken: JsonToken;
    begin
        if not JsonObj.ReadFrom(JsonText) then
            Error('The token response is not valid JSON.');

        if not JsonObj.Get('token', JsonToken) then
            Error('The token field is missing in the response.');

        exit(JsonToken.AsValue().AsText());
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
