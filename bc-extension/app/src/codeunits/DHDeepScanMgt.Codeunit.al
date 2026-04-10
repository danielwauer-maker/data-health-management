codeunit 53124 "DH Deep Scan Mgt."
{
    procedure QueueDeepScan(var Setup: Record "DH Setup"): Integer
    var
        DeepScanRun: Record "DH Deep Scan Run";
        RunIdMgt: Codeunit "DH Run ID Mgt.";
        TaskId: Guid;
        EntryNo: Integer;
        TotalModules: Integer;
    begin
        EnsureDeepScanAllowed(Setup);
        TotalModules := Setup.GetEnabledDeepScanModuleCount();
        if TotalModules <= 0 then
            Error('Please enable at least one scan module on the BCSentinel setup page.');

        EntryNo := GetNextRunEntryNo();

        DeepScanRun.Init();
        DeepScanRun."Entry No." := EntryNo;
        DeepScanRun."Run ID" := RunIdMgt.GetNextRunId(Setup);
        DeepScanRun.Status := DeepScanRun.Status::Queued;
        DeepScanRun."Requested At" := CurrentDateTime();
        DeepScanRun."Requested By" := CopyStr(UserId(), 1, MaxStrLen(DeepScanRun."Requested By"));
        DeepScanRun."Company Name" := CopyStr(CompanyName(), 1, MaxStrLen(DeepScanRun."Company Name"));
        DeepScanRun."Headline" := 'Deep scan queued';
        DeepScanRun."Current Module" := 'Queued';
        DeepScanRun."Progress %" := 0;
        DeepScanRun."Completed Modules" := 0;
        DeepScanRun."Total Modules" := TotalModules;
        DeepScanRun."ETA Text" := 'Pending';
        DeepScanRun.Insert(true);

        TaskId :=
            TaskScheduler.CreateTask(
                Codeunit::"DH Deep Scan Runner",
                Codeunit::"DH Deep Scan Failure",
                true,
                CompanyName(),
                CurrentDateTime(),
                DeepScanRun.RecordId);

        DeepScanRun."Task ID" := TaskId;
        DeepScanRun.Modify(true);

        Page.Run(Page::"DH Deep Scan Monitor", DeepScanRun);

        exit(EntryNo);
    end;

    local procedure EnsureDeepScanAllowed(var Setup: Record "DH Setup")
    begin
        if Setup."API Base URL" = '' then
            Error('Please configure API Base URL first.');

        if Setup."Tenant ID" = '' then
            Error('Please register the tenant first.');

    end;

    local procedure GetNextRunEntryNo(): Integer
    var
        DeepScanRun: Record "DH Deep Scan Run";
    begin
        if DeepScanRun.FindLast() then
            exit(DeepScanRun."Entry No." + 1);

        exit(1);
    end;

}
