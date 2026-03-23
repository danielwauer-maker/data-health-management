page 53110 "BCSentinel Home"
{
    PageType = Card;
    Caption = 'BCSentinel Home';
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

                field("Premium Enabled"; Rec."Premium Enabled")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Indicates whether Premium features are enabled.';
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
                        ResponseText: Text;
                        ScanId: Code[50];
                        DataScore: Integer;
                        IssuesCount: Integer;
                        UsedPremiumLicense: Boolean;
                    begin
                        EnsureSetup(Setup);

                        ResponseText := ApiClient.ExecuteScan(Setup, ScanId, DataScore, IssuesCount, UsedPremiumLicense);
                        CurrPage.Update(false);

                        if UsedPremiumLicense then
                            Message(
                                'BCSentinel Premium license detected. Scan completed.\' +
                                'Scan ID: %1\Score: %2\Issues: %3',
                                ScanId,
                                DataScore,
                                IssuesCount)
                        else
                            Message(
                                'BCSentinel Quick Scan completed.\' +
                                'Scan ID: %1\Score: %2\Issues: %3',
                                ScanId,
                                DataScore,
                                IssuesCount);
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
                        Url: Text;
                    begin
                        EnsureSetup(Setup);

                        if Setup."Tenant ID" = '' then
                            Error('Tenant is not registered yet.');

                        Url := 'https://admin.bcsentinel.com/admin/tenants/' + Setup."Tenant ID";
                        Hyperlink(Url);
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
}