page 53124 "DH Dashboard List"
{
    PageType = List;
    SourceTable = "DH Scan Header";
    ApplicationArea = All;
    UsageCategory = Lists;
    Caption = 'BCSentinel Dashboards';
    CardPageId = "DH Deep Scan Monitor";
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Entries)
            {
                field(DisplayRunId; Rec.GetDisplayRunId())
                {
                    ApplicationArea = All;
                    Caption = 'Run ID';
                }

                field("Scan Type"; Rec."Scan Type")
                {
                    ApplicationArea = All;
                }

                field("Scan DateTime"; Rec."Scan DateTime")
                {
                    ApplicationArea = All;
                    Caption = 'Scan Date';
                }

                field("Data Score"; Rec."Data Score")
                {
                    ApplicationArea = All;
                    Caption = 'Score';
                }

                field("Checks Count"; Rec."Checks Count")
                {
                    ApplicationArea = All;
                }

                field("Issues Count"; Rec."Issues Count")
                {
                    ApplicationArea = All;
                }

                field("Est. Premium Price"; Rec."Est. Premium Price")
                {
                    ApplicationArea = All;
                    Caption = 'Premium €/Month';
                }

                field("Est. Loss"; Rec."Estimated Loss (EUR)")
                {
                    ApplicationArea = All;
                    Caption = 'Loss €';
                }

                field("ROI"; Rec."ROI")
                {
                    ApplicationArea = All;
                    Caption = 'ROI €';
                }

                field("Headline"; Rec."Headline")
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(OpenDashboardCard)
            {
                Caption = 'Open Dashboard';
                ApplicationArea = All;
                Image = Navigate;

                trigger OnAction()
                begin
                    Page.Run(Page::"DH Deep Scan Monitor", Rec);
                end;
            }

            action(RunQuickScan)
            {
                Caption = 'Run Scan';
                ApplicationArea = All;
                Image = Calculate;

                trigger OnAction()
                var
                    Setup: Record "DH Setup";
                    QuickScanMgt: Codeunit "DH QuickScan Mgt.";
                begin
                    if not Setup.Get('SETUP') then
                        Error('Setup not found.');

                    QuickScanMgt.RunQuickScanAndOpenDashboard(Setup);
                    CurrPage.Update(false);
                end;
            }

            action(DeleteSelectedDashboard)
            {
                Caption = 'Delete Selected Dashboard';
                ApplicationArea = All;
                Image = Delete;

                trigger OnAction()
                var
                    Setup: Record "DH Setup";
                    ApiClient: Codeunit "DH API Client";
                    BackendDeleteId: Code[50];
                begin
                    if Rec."Entry No." = 0 then
                        Error('Please select a dashboard entry first.');

                    if Confirm('Do you want to delete the selected dashboard from %1?', false, Format(Rec."Scan DateTime")) then begin
                        BackendDeleteId := GetBackendDeleteId();

                        if Setup.Get('SETUP') then
                            if (Setup."Tenant ID" <> '') and (Setup."API Token" <> '') and (BackendDeleteId <> '') then
                                ApiClient.DeleteScanFromBackend(Setup, BackendDeleteId);

                        Rec.Delete(true);
                        CurrPage.Update(false);
                    end;
                end;
            }

            action(ReconcileScanHistory)
            {
                Caption = 'Reconcile Scan History';
                ApplicationArea = All;
                Image = RefreshLines;

                trigger OnAction()
                var
                    Setup: Record "DH Setup";
                    ApiClient: Codeunit "DH API Client";
                begin
                    if not Setup.Get('SETUP') then
                        Error('Setup not found.');

                    if not Confirm('This will align the backend scan history with the current BC scan list and remove orphan backend scans. Continue?', false) then
                        exit;

                    ApiClient.ReconcileScansWithBackend(Setup);
                    Message('Scan history synchronized with backend.');
                    CurrPage.Update(false);
                end;
            }

            action(OpenSetup)
            {
                Caption = 'Open Setup';
                ApplicationArea = All;
                Image = Setup;
                RunObject = page "DH Setup";
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
                    if not Setup.Get('SETUP') then
                        Error('Setup not found.');

                    if Setup."Premium Enabled" then begin
                        Message('Premium actions are already unlocked for this tenant.');
                        exit;
                    end;

                    ApiClient.OpenPremiumCheckout(Setup);
                end;
            }
        }

        area(Promoted)
        {
            group(Process)
            {
                actionref(OpenDashboardCard_Promoted; OpenDashboardCard)
                {
                }
                actionref(RunQuickScan_Promoted; RunQuickScan)
                {
                }
                actionref(DeleteSelectedDashboard_Promoted; DeleteSelectedDashboard)
                {
                }
                actionref(ReconcileScanHistory_Promoted; ReconcileScanHistory)
                {
                }
                actionref(UpgradeToPremium_Promoted; UpgradeToPremium)
                {
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.SetCurrentKey("Scan DateTime");
        Rec.Ascending(false);
    end;

    local procedure GetBackendDeleteId(): Code[50]
    begin
        if Rec."Backend Scan Id" <> '' then
            exit(Rec."Backend Scan Id");

        exit(Rec.GetDisplayRunId());
    end;
}
