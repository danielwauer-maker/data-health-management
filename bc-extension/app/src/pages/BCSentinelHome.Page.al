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
                        QuickScanMgt: Codeunit "DH QuickScan Mgt.";
                        DeepScanMgt: Codeunit "DH Deep Scan Mgt.";
                        Header: Record "DH Scan Header";
                        DeepScanRun: Record "DH Deep Scan Run";
                        EntryNo: Integer;
                    begin
                        EnsureSetup(Setup);
                        ApiClient.EnsureReadyForScan(Setup);

                        if Setup."Premium Enabled" then begin
                            EntryNo := DeepScanMgt.QueueDeepScan(Setup);
                            CurrPage.Update(false);

                            if DeepScanRun.Get(EntryNo) then
                                Message(
                                    'BCSentinel Premium scan queued.\' +
                                    'Run ID: %1\Status: %2',
                                    DeepScanRun."Run ID",
                                    Format(DeepScanRun.Status));
                        end else begin
                            EntryNo := QuickScanMgt.RunQuickScan(Setup);
                            CurrPage.Update(false);

                            if Header.Get(EntryNo) then
                                Page.Run(Page::"DH Dashboard", Header);
                        end;
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