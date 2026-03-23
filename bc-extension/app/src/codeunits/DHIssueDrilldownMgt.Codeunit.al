codeunit 53142 "DH Issue Drilldown Mgt."
{
    procedure OpenDashboardIssue(var DashboardIssue: Record "DH Dashboard Issue")
    begin
        OpenByIssueCode(DashboardIssue."Issue Code");
    end;

    procedure OpenScanIssue(var ScanIssue: Record "DH Scan Issue")
    begin
        OpenByIssueCode(ScanIssue."Issue Code");
    end;

    procedure OpenDeepScanFinding(var DeepFinding: Record "DH Deep Scan Finding")
    begin
        OpenByIssueCode(DeepFinding."Issue Code");
    end;

    local procedure OpenByIssueCode(IssueCode: Code[50])
    var
        IssueDrilldownDispatcher: Codeunit "DH Issue Drilldown Dispatcher";
    begin
        IssueDrilldownDispatcher.OpenByIssueCode(IssueCode);
    end;
}
