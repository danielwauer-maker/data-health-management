page 53124 "DH Dashboard List"
{
    PageType = List;
    SourceTable = "DH Scan Header";
    ApplicationArea = All;
    UsageCategory = None;
    Caption = 'Data Health Dashboards';
    CardPageId = "DH Dashboard";
    Editable = false;
    DeleteAllowed = true;
    InsertAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Scan DateTime"; Rec."Scan DateTime")
                {
                    ApplicationArea = All;
                }
                field("Data Score"; Rec."Data Score")
                {
                    ApplicationArea = All;
                }
                field("Rating"; Rec."Rating")
                {
                    ApplicationArea = All;
                }
                field("Headline"; Rec."Headline")
                {
                    ApplicationArea = All;
                }
                field("Checks Count"; Rec."Checks Count")
                {
                    ApplicationArea = All;
                }
                field("Issues Count"; Rec."Issues Count")
                {
                    ApplicationArea = All;
                }
                field("Scan Type"; Rec."Scan Type")
                {
                    ApplicationArea = All;
                }
                field("Backend Scan Id"; Rec."Backend Scan Id")
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
                Image = View;

                trigger OnAction()
                begin
                    Page.Run(Page::"DH Dashboard", Rec);
                end;
            }

            action(RunQuickScan)
            {
                Caption = 'Run Quick Scan';
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
                begin
                    if Rec."Entry No." = 0 then
                        Error('Please select a dashboard entry first.');

                    if Confirm(
                        'Do you want to delete the selected dashboard from %1?',
                        false,
                        Format(Rec."Scan DateTime"))
                    then begin
                        if Setup.Get('SETUP') then
                            if Rec."Backend Scan Id" <> '' then
                                ApiClient.DeleteScanFromBackend(Setup, Rec."Backend Scan Id");

                        Rec.Delete(true);
                        CurrPage.Update(false);
                    end;
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
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.SetCurrentKey("Scan DateTime");
        Rec.Ascending(false);
    end;
}