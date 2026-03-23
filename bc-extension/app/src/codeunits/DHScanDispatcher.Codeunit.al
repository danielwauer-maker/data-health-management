codeunit 53135 "DH Scan Dispatcher"
{
    procedure StartScan(var Setup: Record "DH Setup")
    var
        QuickScanMgt: Codeunit "DH QuickScan Mgt.";
        DeepScanMgt: Codeunit "DH Deep Scan Mgt.";
        DeepScanRun: Record "DH Deep Scan Run";
        EntryNo: Integer;
    begin
        EnsureSetupReady(Setup);

        if Setup."Premium Enabled" then begin
            EntryNo := DeepScanMgt.QueueDeepScan(Setup);

            if DeepScanRun.Get(EntryNo) then
                Page.Run(Page::"DH Deep Scan Runs", DeepScanRun);

            exit;
        end;

        QuickScanMgt.RunQuickScanAndOpenDashboard(Setup);
    end;

    local procedure EnsureSetupReady(var Setup: Record "DH Setup")
    begin
        if Setup."API Base URL" = '' then
            Error('Please configure API Base URL first.');

        if Setup."Tenant ID" = '' then
            Error('Please register the tenant first.');
    end;
}
