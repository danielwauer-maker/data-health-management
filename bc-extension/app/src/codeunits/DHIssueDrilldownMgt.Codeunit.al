codeunit 53142 "DH Issue Drilldown Mgt."
{
    procedure OpenDashboardIssue(var DashboardIssue: Record "DH Dashboard Issue")
    begin
        EnsurePremiumAccess();
        OpenByIssueCode(DashboardIssue."Issue Code");
    end;

    procedure OpenScanIssue(var ScanIssue: Record "DH Scan Issue")
    begin
        EnsurePremiumAccess();
        OpenByIssueCode(ScanIssue."Issue Code");
    end;

    procedure OpenDeepScanFinding(var DeepFinding: Record "DH Deep Scan Finding")
    begin
        EnsurePremiumAccess();
        OpenByIssueCode(DeepFinding."Issue Code");
    end;

    procedure OpenByIssueCode(IssueCode: Code[50])
    var
        IssueDrilldownDispatcher: Codeunit "DH Issue Drilldown Dispatcher";
    begin
        IssueDrilldownDispatcher.OpenByIssueCode(IssueCode);
    end;

    local procedure EnsurePremiumAccess()
    var
        Setup: Record "DH Setup";
    begin
        if not Setup.Get('SETUP') then
            Error('Setup not found.');

        if not Setup."Premium Enabled" then
            Error('This tenant already uses the full DeepScan data basis. Upgrade to Premium to unlock recommendations, drilldowns, and correction worklists.');
    end;
}
