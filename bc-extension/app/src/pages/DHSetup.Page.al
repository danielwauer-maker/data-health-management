page 53100 "DH Setup"
{
    PageType = Card;
    SourceTable = "DH Setup";
    Caption = 'BCSentinel Setup';
    ApplicationArea = All;
    UsageCategory = Administration;

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

                field(FeatureAccess; Rec.GetFeatureAccessText())
                {
                    ApplicationArea = All;
                    Caption = 'Feature access';
                    Editable = false;
                    ToolTip = 'Shows whether premium actions are unlocked.';
                }
            }

            group(General)
            {
                Caption = 'General';

                field("API Base URL"; Rec."API Base URL")
                {
                    ApplicationArea = All;
                    Editable = true;
                    ToolTip = 'Base URL of the BCSentinel API. Default is production.';
                }

                field("Tenant ID"; Rec."Tenant ID")
                {
                    ApplicationArea = All;
                    Editable = false;
                }

                field("API Token"; Rec."API Token")
                {
                    ApplicationArea = All;
                    Editable = false;
                }

                field(Registered; Rec.Registered)
                {
                    ApplicationArea = All;
                    Editable = false;
                }

                field("Registration Date"; Rec."Registration Date")
                {
                    ApplicationArea = All;
                    Editable = false;
                }

                field("Data Processing Consent"; Rec."Data Processing Consent")
                {
                    ApplicationArea = All;
                    ToolTip = 'Must be enabled before tenant registration and scan synchronization.';
                }
            }

            group(License)
            {
                Caption = 'License';

                field("Last License Check"; Rec."Last License Check")
                {
                    ApplicationArea = All;
                    Editable = false;
                }

                field("Premium Enabled"; Rec."Premium Enabled")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Shows whether premium recommendations, drilldowns, worklists, and related premium details are unlocked.';
                }
            }

            group("Enabled Scan Modules")
            {
                Caption = 'Enabled Scan Modules';

                field("Scan System Module"; Rec."Scan System Module")
                {
                    ApplicationArea = All;
                    ToolTip = 'Include system and setup checks in the deep scan.';
                }

                field("Scan Finance Module"; Rec."Scan Finance Module")
                {
                    ApplicationArea = All;
                    ToolTip = 'Include finance-related checks in the deep scan.';
                }

                field("Scan Sales Module"; Rec."Scan Sales Module")
                {
                    ApplicationArea = All;
                    ToolTip = 'Include sales-related checks in the deep scan.';
                }

                field("Scan Purchasing Module"; Rec."Scan Purchasing Module")
                {
                    ApplicationArea = All;
                    ToolTip = 'Include purchasing-related checks in the deep scan.';
                }

                field("Scan Inventory Module"; Rec."Scan Inventory Module")
                {
                    ApplicationArea = All;
                    ToolTip = 'Include inventory-related checks in the deep scan.';
                }

                field("Scan CRM Module"; Rec."Scan CRM Module")
                {
                    ApplicationArea = All;
                    ToolTip = 'Include CRM/contact-related checks in the deep scan.';
                }

                field("Scan Manufacturing Module"; Rec."Scan Manufacturing Module")
                {
                    ApplicationArea = All;
                    ToolTip = 'Include manufacturing and production master data checks in the deep scan.';
                }

                field("Scan Service Module"; Rec."Scan Service Module")
                {
                    ApplicationArea = All;
                    ToolTip = 'Include service-related checks in the deep scan.';
                }

                field("Scan Jobs Module"; Rec."Scan Jobs Module")
                {
                    ApplicationArea = All;
                    ToolTip = 'Include jobs and project-related checks in the deep scan.';
                }

                field("Scan HR Module"; Rec."Scan HR Module")
                {
                    ApplicationArea = All;
                    ToolTip = 'Include employee and resource-related checks in the deep scan.';
                }
            }

            group(Scan)
            {
                Caption = 'Last Scan';

                field("Last Scan Date 2"; Rec."Last Scan Date")
                {
                    ApplicationArea = All;
                    Caption = 'Last Scan Date';
                    Editable = false;
                    Visible = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(TestConnection)
            {
                Caption = 'Test BCSentinel Connection';
                ApplicationArea = All;
                Image = TestFile;

                trigger OnAction()
                var
                    ApiClient: Codeunit "DH API Client";
                begin
                    ApiClient.TestConnection(Rec);
                end;
            }

            /*action(RegisterTenant)
            {
                Caption = 'Register with BCSentinel';
                ApplicationArea = All;
                Image = Web;

                trigger OnAction()
                var
                    ApiClient: Codeunit "DH API Client";
                begin
                    ApiClient.EnsureTenantRegistered(Rec);
                    //RefreshLicenseSilently();
                    CurrPage.Update(false);
                    Message('BCSentinel tenant registration completed.');
                end;
            }*/

            action(RegisterTenant)
            {
                Caption = 'Register with BCSentinel';
                ApplicationArea = All;
                Image = Web;

                trigger OnAction()
                var
                    ApiClient: Codeunit "DH API Client";
                begin
                    Message('BCSentinel tenant registration started.');
                    Rec."Tenant ID" := '';
                    Rec."API Token" := '';
                    Rec.Registered := false;
                    Rec."Registration Date" := 0DT;
                    Rec.Modify(true);

                    ApiClient.RegisterTenant(Rec);
                    CurrPage.Update(false);
                    Message('BCSentinel tenant registration completed.');
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
                    ApiClient: Codeunit "DH API Client";
                begin
                    if Rec."Premium Enabled" then begin
                        Message('Premium actions are already unlocked for this tenant.');
                        exit;
                    end;

                    ApiClient.OpenPremiumCheckout(Rec);
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
                    ApiClient: Codeunit "DH API Client";
                begin
                    if Rec."Tenant ID" = '' then
                        Error('Please register the tenant first.');

                    ApiClient.RefreshLicenseStatus(Rec);
                    CurrPage.Update(false);
                    Message('License status refreshed.');
                end;
            }

            group(ScanMenu)
            {
                Caption = 'Scan';
                Image = Start;

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
                    begin
                        EnsureSetupExists();
                        Setup := Rec;
                        ApiClient.EnsureReadyForScan(Setup);

                        DeepScanMgt.QueueDeepScan(Setup);
                        CurrPage.Update(false);
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
        }
    }

    trigger OnOpenPage()
    begin
        EnsureSetupExists();
        //RefreshLicenseSilently();
        CurrPage.Update(false);
    end;

    local procedure EnsureSetupExists()
    begin
        if not Rec.Get('SETUP') then begin
            Rec.Init();
            Rec."Primary Key" := 'SETUP';
            Rec.Insert(true);
        end;

        Rec.ApplyDefaults();
        Rec.Modify(true);
    end;

    local procedure RefreshLicenseSilently()
    var
        ApiClient: Codeunit "DH API Client";
    begin
        if Rec."Tenant ID" = '' then
            exit;

        ApiClient.RefreshLicenseStatus(Rec);
    end;

    local procedure GetTokenUrl(var Setup: Record "DH Setup"): Text
    begin
        if Setup."API Base URL" = '' then
            Error('Please configure the API Base URL first.');

        if Setup."Tenant ID" = '' then
            Error('Tenant is not registered yet.');

        exit(RemoveTrailingSlash(Setup."API Base URL") + '/analytics/get-token?company=' + EncodeUrlValue(CompanyName()) + '&environment=' + EncodeUrlValue('BC Cloud') + '&tenant_id=' + EncodeUrlValue(Setup."Tenant ID") + '&scan_mode=' + EncodeUrlValue(GetScanMode(Setup)) + '&bc_issue_launch_url=' + EncodeUrlValue(GetIssueDrilldownLaunchUrl()));
    end;

    local procedure GetScanMode(var Setup: Record "DH Setup"): Text
    begin
        if Setup."Premium Enabled" then
            exit('premium_deep');
        exit('free_deep');
    end;

    local procedure GetDashboardUrl(var Setup: Record "DH Setup"; Token: Text): Text
    begin
        exit(RemoveTrailingSlash(Setup."API Base URL") + '/analytics/embed?token=' + EncodeUrlValue(Token));
    end;

    local procedure GetIssueDrilldownLaunchUrl(): Text
    begin
        exit(GetUrl(ClientType::Web, CompanyName(), ObjectType::Page, Page::"DH Issue Drilldown Launch"));
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
