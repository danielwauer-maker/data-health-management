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
                        OpenMonitorForCurrentScan();
                    end;
                }

                /*field("Scan Type"; Rec."Scan Type")
                {
                    ApplicationArea = All;
                }*/

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

                field("Est. Loss"; Rec."Estimated Loss (EUR)")
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

                /*field("Premium"; GetIsPremiumRun())
                {
                    ApplicationArea = All;
                    Caption = 'Premium';
                }*/
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(OpenDashboardAction)
            {
                Caption = 'Open Scan';
                ApplicationArea = All;
                Image = Navigate;

                trigger OnAction()
                begin
                    OpenMonitorForCurrentScan();
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

            action(OpenMonitor)
            {
                Caption = 'Open Deep Scan Monitor';
                ApplicationArea = All;
                Image = ViewDetails;

                trigger OnAction()
                var
                    DeepScanRun: Record "DH Deep Scan Run";
                begin
                    if Rec."Scan Type" <> Rec."Scan Type"::Deep then
                        Error('The monitor is only available for deep scans.');

                    DeepScanRun.SetRange("Run ID", Rec.GetDisplayRunId());
                    if not DeepScanRun.FindFirst() then
                        Error('No deep scan run was found for %1.', Rec.GetDisplayRunId());

                    Page.Run(Page::"DH Deep Scan Monitor", DeepScanRun);
                end;
            }

            action(DeleteSelectedScan)
            {
                Caption = 'Delete Selected Scan(s)';
                ApplicationArea = All;
                Image = Delete;
                Scope = Repeater;

                trigger OnAction()
                begin
                    DeleteSelectedScans();
                end;
            }

            action(DeleteCurrentScan)
            {
                Caption = 'Delete This Scan';
                ApplicationArea = All;
                Image = Delete;
                Scope = Repeater;

                trigger OnAction()
                var
                    Setup: Record "DH Setup";
                    ApiClient: Codeunit "DH API Client";
                begin
                    if Rec."Entry No." = 0 then
                        Error('Please select a scan first.');

                    if not Confirm('Do you want to delete scan %1?', false, Rec.GetDisplayRunId()) then
                        exit;

                    DeleteSingleScan(Rec, Setup, ApiClient);
                    CurrPage.Update(false);
                    Message('Scan deleted.');
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
                    Message('Scan history successfully synchronized with the backend.');
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

    local procedure OpenMonitorForCurrentScan()
    var
        DeepScanRun: Record "DH Deep Scan Run";
    begin
        if Rec."Scan Type" <> Rec."Scan Type"::Deep then
            Error('The monitor is only available for deep scans.');

        DeepScanRun.SetRange("Run ID", Rec.GetDisplayRunId());
        if not DeepScanRun.FindFirst() then
            Error('No deep scan run was found for %1.', Rec.GetDisplayRunId());

        Page.Run(Page::"DH Deep Scan Monitor", DeepScanRun);
    end;

    local procedure DeleteSingleScan(var ScanHeader: Record "DH Scan Header"; var Setup: Record "DH Setup"; var ApiClient: Codeunit "DH API Client")
    var
        BackendDeleteId: Code[50];
    begin
        BackendDeleteId := GetBackendDeleteIdFor(ScanHeader);

        if Setup.Get('SETUP') then
            if (Setup."Tenant ID" <> '') and (Setup."API Token" <> '') and (BackendDeleteId <> '') then
                ApiClient.DeleteScanFromBackend(Setup, BackendDeleteId);

        DeleteLinkedDeepRunIfNeededFor(ScanHeader);
        ScanHeader.Delete(true);
    end;

    local procedure DeleteSelectedScans()
    var
        Setup: Record "DH Setup";
        ApiClient: Codeunit "DH API Client";
        SelectedScans: Record "DH Scan Header";
        TotalToDelete: Integer;
        DeletedCount: Integer;
    begin
        CurrPage.SetSelectionFilter(SelectedScans);
        if SelectedScans.IsEmpty() then
            Error('Please select at least one scan.');

        TotalToDelete := SelectedScans.Count();
        if TotalToDelete = 1 then begin
            if not SelectedScans.FindFirst() then
                exit;

            if not Confirm('Do you want to delete scan %1?', false, SelectedScans.GetDisplayRunId()) then
                exit;
        end else
            if not Confirm('Do you want to delete %1 selected scans?', false, TotalToDelete) then
                exit;

        if SelectedScans.FindSet() then
            repeat
                DeleteSingleScan(SelectedScans, Setup, ApiClient);
                DeletedCount += 1;
            until SelectedScans.Next() = 0;

        CurrPage.Update(false);
        Message('%1 scan(s) deleted.', DeletedCount);
    end;

    local procedure DeleteLinkedDeepRunIfNeededFor(var ScanHeader: Record "DH Scan Header")
    var
        DeepScanRun: Record "DH Deep Scan Run";
    begin
        if ScanHeader."Scan Type" <> ScanHeader."Scan Type"::Deep then
            exit;

        if ScanHeader.GetDisplayRunId() = '' then
            exit;

        DeepScanRun.SetRange("Run ID", ScanHeader.GetDisplayRunId());
        if DeepScanRun.FindFirst() then
            DeepScanRun.Delete(true);
    end;

    local procedure GetBackendDeleteIdFor(var ScanHeader: Record "DH Scan Header"): Code[50]
    begin
        if ScanHeader."Backend Scan Id" <> '' then
            exit(ScanHeader."Backend Scan Id");

        exit(ScanHeader.GetDisplayRunId());
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