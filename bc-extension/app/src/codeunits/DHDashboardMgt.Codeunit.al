codeunit 53134 "DH Dashboard Mgt."
{
    procedure RefreshDashboardIssueCache(var ScanHeader: Record "DH Scan Header")
    begin
        if ScanHeader."Entry No." = 0 then
            exit;

        DeleteDashboardIssues(ScanHeader."Entry No.");

        case ScanHeader."Scan Type" of
            ScanHeader."Scan Type"::Quick:
                begin
                    LoadQuickIssuesForDashboard(ScanHeader);
                    LoadLatestDeepIssuesForQuickDashboard(ScanHeader);
                end;
            ScanHeader."Scan Type"::Deep:
                LoadDeepIssuesForDeepDashboard(ScanHeader);
        end;
    end;

    local procedure DeleteDashboardIssues(DashboardScanEntryNo: Integer)
    var
        DashboardIssue: Record "DH Dashboard Issue";
    begin
        DashboardIssue.SetRange("Dashboard Scan Entry No.", DashboardScanEntryNo);
        if not DashboardIssue.IsEmpty() then
            DashboardIssue.DeleteAll(true);
    end;

    local procedure LoadQuickIssuesForDashboard(var ScanHeader: Record "DH Scan Header")
    var
        ScanIssue: Record "DH Scan Issue";
    begin
        ScanIssue.SetRange("Scan Entry No.", ScanHeader."Entry No.");
        if ScanIssue.FindSet() then
            repeat
                InsertDashboardIssue(
                    ScanHeader."Entry No.",
                    EnumToSourceTypeQuick(),
                    ScanHeader."Entry No.",
                    ScanIssue."Issue Code",
                    ScanIssue.Title,
                    ScanIssue.Severity,
                    ScanIssue."Affected Count",
                    ScanIssue."Recommendation Preview",
                    ScanIssue."Premium Only");
            until ScanIssue.Next() = 0;
    end;

    local procedure LoadLatestDeepIssuesForQuickDashboard(var ScanHeader: Record "DH Scan Header")
    var
        DeepScanRun: Record "DH Deep Scan Run";
        Setup: Record "DH Setup";
    begin
        if not Setup.Get('SETUP') then
            exit;

        if not Setup."Premium Enabled" then
            exit;

        DeepScanRun.Reset();
        DeepScanRun.SetCurrentKey("Requested At");
        DeepScanRun.SetRange(Status, DeepScanRun.Status::Completed);

        if not DeepScanRun.FindLast() then
            exit;

        LoadDeepFindingsIntoDashboard(ScanHeader."Entry No.", DeepScanRun);
    end;

    local procedure LoadDeepIssuesForDeepDashboard(var ScanHeader: Record "DH Scan Header")
    var
        DeepScanRun: Record "DH Deep Scan Run";
    begin
        DeepScanRun.Reset();
        DeepScanRun.SetRange("Run ID", ScanHeader."Backend Scan Id");
        DeepScanRun.SetRange(Status, DeepScanRun.Status::Completed);

        if not DeepScanRun.FindFirst() then
            exit;

        LoadDeepFindingsIntoDashboard(ScanHeader."Entry No.", DeepScanRun);
    end;

    local procedure LoadDeepFindingsIntoDashboard(DashboardScanEntryNo: Integer; var DeepScanRun: Record "DH Deep Scan Run")
    var
        DeepFinding: Record "DH Deep Scan Finding";
    begin
        DeepFinding.SetRange("Deep Scan Entry No.", DeepScanRun."Entry No.");
        if DeepFinding.FindSet() then
            repeat
                InsertDashboardIssue(
                    DashboardScanEntryNo,
                    EnumToSourceTypeDeep(),
                    DeepScanRun."Entry No.",
                    DeepFinding."Issue Code",
                    DeepFinding.Title,
                    DeepFinding.Severity,
                    DeepFinding."Affected Count",
                    DeepFinding."Recommendation Preview",
                    true);
            until DeepFinding.Next() = 0;
    end;

    local procedure InsertDashboardIssue(DashboardScanEntryNo: Integer; SourceType: Option Quick,Deep; SourceEntryNo: Integer; IssueCode: Code[50]; Title: Text[150]; Severity: Code[20]; AffectedCount: Integer; RecommendationPreview: Text[250]; PremiumOnly: Boolean)
    var
        DashboardIssue: Record "DH Dashboard Issue";
    begin
        DashboardIssue.Init();
        DashboardIssue."Entry No." := GetNextEntryNo();
        DashboardIssue."Dashboard Scan Entry No." := DashboardScanEntryNo;
        DashboardIssue."Source Type" := SourceType;
        DashboardIssue."Source Entry No." := SourceEntryNo;
        DashboardIssue."Issue Code" := IssueCode;
        DashboardIssue.Title := CopyStr(Title, 1, MaxStrLen(DashboardIssue.Title));
        DashboardIssue.Severity := Severity;
        DashboardIssue."Severity Sort Order" := GetSeveritySortOrder(DashboardIssue.Severity);
        DashboardIssue."Affected Count" := AffectedCount;
        DashboardIssue."Affected Count Sort Value" := -AffectedCount;
        DashboardIssue."Recommendation Preview" := CopyStr(RecommendationPreview, 1, MaxStrLen(DashboardIssue."Recommendation Preview"));
        DashboardIssue."Premium Only" := PremiumOnly;
        DashboardIssue.Insert(true);
    end;

    local procedure GetNextEntryNo(): Integer
    var
        DashboardIssue: Record "DH Dashboard Issue";
    begin
        if DashboardIssue.FindLast() then
            exit(DashboardIssue."Entry No." + 1);

        exit(1);
    end;

    local procedure EnumToSourceTypeQuick(): Option Quick,Deep
    var
        DashboardIssue: Record "DH Dashboard Issue";
    begin
        exit(DashboardIssue."Source Type"::Quick);
    end;

    local procedure EnumToSourceTypeDeep(): Option Quick,Deep
    var
        DashboardIssue: Record "DH Dashboard Issue";
    begin
        exit(DashboardIssue."Source Type"::Deep);
    end;


    local procedure GetSeveritySortOrder(SeverityValue: Code[20]): Integer
    begin
        case LowerCase(SeverityValue) of
            'high':
                exit(1);
            'medium':
                exit(2);
            'low':
                exit(3);
        end;

        exit(99);
    end;
}
