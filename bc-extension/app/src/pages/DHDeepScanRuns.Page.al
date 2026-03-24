page 53130 "DH Deep Scan Runs"
{
    PageType = List;
    SourceTable = "DH Scan Header";
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'BCSentinel Scan History';
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Runs)
            {
                field(DisplayRunId; Rec.GetDisplayRunId())
                {
                    ApplicationArea = All;
                    Caption = 'Run ID';
                    StyleExpr = RunIdStyle;

                    trigger OnDrillDown()
                    begin
                        OpenDashboard();
                    end;
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
                    StyleExpr = ScoreStyle;
                }

                field("Checks Count"; Rec."Checks Count")
                {
                    ApplicationArea = All;
                }

                field("Issues Count"; Rec."Issues Count")
                {
                    ApplicationArea = All;
                }

                field("Est. Loss"; Rec."Est. Loss")
                {
                    ApplicationArea = All;
                    Caption = 'Loss €';
                }

                field("Rating"; Rec."Rating")
                {
                    ApplicationArea = All;
                }

                field("Headline"; Rec."Headline")
                {
                    ApplicationArea = All;
                }

                field("Premium"; GetIsPremiumRun())
                {
                    ApplicationArea = All;
                    Caption = 'Premium';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(OpenDashboardAction)
            {
                Caption = 'Open Dashboard';
                ApplicationArea = All;
                Image = Navigate;

                trigger OnAction()
                begin
                    OpenDashboard();
                end;
            }

            action(OpenAllIssues)
            {
                Caption = 'Open Issues';
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

            action(DeleteSelectedScan)
            {
                Caption = 'Delete Selected Scan';
                ApplicationArea = All;
                Image = Delete;

                trigger OnAction()
                var
                    Setup: Record "DH Setup";
                    ApiClient: Codeunit "DH API Client";
                begin
                    if Rec."Entry No." = 0 then
                        Error('Please select a scan first.');

                    if not Confirm('Do you want to delete scan %1?', false, Rec.GetDisplayRunId()) then
                        exit;

                    if Setup.Get('SETUP') then
                        if (Setup."Tenant ID" <> '') and (Setup."API Token" <> '') and (Rec."Backend Scan Id" <> '') then
                            ApiClient.DeleteScanFromBackend(Setup, Rec."Backend Scan Id");

                    DeleteLinkedDeepRunIfNeeded();

                    Rec.Delete(true);
                    CurrPage.Update(false);
                end;
            }

            action(Refresh)
            {
                Caption = 'Refresh';
                ApplicationArea = All;
                Image = Refresh;

                trigger OnAction()
                begin
                    CurrPage.Update(false);
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.SetCurrentKey("Scan DateTime");
        Rec.Ascending(false);
    end;

    trigger OnAfterGetRecord()
    begin
        ScoreStyle := GetScoreStyle();
        RunIdStyle := 'Strong';
    end;

    var
        ScoreStyle: Text[30];
        RunIdStyle: Text[30];

    local procedure OpenDashboard()
    var
        DashboardMgt: Codeunit "DH Dashboard Mgt.";
    begin
        DashboardMgt.RefreshDashboardIssueCache(Rec);
        Page.Run(Page::"DH Dashboard", Rec);
    end;

    local procedure DeleteLinkedDeepRunIfNeeded()
    var
        DeepScanRun: Record "DH Deep Scan Run";
    begin
        if Rec."Scan Type" <> Rec."Scan Type"::Deep then
            exit;

        if Rec.GetDisplayRunId() = '' then
            exit;

        DeepScanRun.SetRange("Run ID", Rec.GetDisplayRunId());
        if DeepScanRun.FindFirst() then
            DeepScanRun.Delete(true);
    end;

    local procedure GetScoreStyle(): Text
    begin
        if Rec."Data Score" >= 86 then
            exit('Favorable');

        if Rec."Data Score" >= 61 then
            exit('Ambiguous');

        if Rec."Data Score" > 0 then
            exit('Unfavorable');

        exit('Standard');
    end;

    local procedure GetIsPremiumRun(): Boolean
    begin
        exit(Rec."Scan Type" = Rec."Scan Type"::Deep);
    end;
}
