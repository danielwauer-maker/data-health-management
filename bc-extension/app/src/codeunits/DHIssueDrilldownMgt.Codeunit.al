codeunit 53142 "DH Issue Drilldown Mgt."
{
    procedure OpenDashboardIssue(var DashboardIssue: Record "DH Dashboard Issue")
    begin
        if not EnsurePremiumAccess() then
            exit;
        OpenByIssueCode(DashboardIssue."Issue Code");
    end;

    procedure OpenScanIssue(var ScanIssue: Record "DH Scan Issue")
    begin
        if not EnsurePremiumAccess() then
            exit;
        OpenByIssueCode(ScanIssue."Issue Code");
    end;

    procedure OpenDeepScanFinding(var DeepFinding: Record "DH Deep Scan Finding")
    begin
        if not EnsurePremiumAccess() then
            exit;
        OpenByIssueCode(DeepFinding."Issue Code");
    end;

    procedure OpenByIssueCode(IssueCode: Code[50])
    var
        IssueDrilldownDispatcher: Codeunit "DH Issue Drilldown Dispatcher";
    begin
        IssueDrilldownDispatcher.OpenByIssueCode(IssueCode);
    end;

    local procedure EnsurePremiumAccess(): Boolean
    var
        Setup: Record "DH Setup";
    begin
        if not Setup.Get('SETUP') then
            Error('Setup not found.');

        if not Setup."Premium Enabled" then begin
            Message('Premium access is required.');
            exit(false);
        end;

        exit(true);
    end;
}
