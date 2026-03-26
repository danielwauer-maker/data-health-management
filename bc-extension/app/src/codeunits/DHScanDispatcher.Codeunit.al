codeunit 53135 "DH Scan Dispatcher"
{
    procedure StartScan(var Setup: Record "DH Setup")
    var
        DeepScanMgt: Codeunit "DH Deep Scan Mgt.";
    begin
        EnsureSetupReady(Setup);
        DeepScanMgt.QueueDeepScan(Setup);
        Page.Run(Page::"DH Deep Scan Runs");
    end;

    local procedure EnsureSetupReady(var Setup: Record "DH Setup")
    begin
        if Setup."API Base URL" = '' then
            Error('Please configure API Base URL first.');

        if Setup."Tenant ID" = '' then
            Error('Please register the tenant first.');
    end;
}