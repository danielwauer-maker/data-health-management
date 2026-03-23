codeunit 53124 "DH Deep Scan Mgt."
{
    procedure QueueDeepScan(var Setup: Record "DH Setup"): Integer
    var
        DeepScanRun: Record "DH Deep Scan Run";
        TaskId: Guid;
        EntryNo: Integer;
    begin
        EnsureDeepScanAllowed(Setup);

        EntryNo := GetNextRunEntryNo();

        DeepScanRun.Init();
        DeepScanRun."Entry No." := EntryNo;
        DeepScanRun."Run ID" := BuildRunId(EntryNo);
        DeepScanRun.Status := DeepScanRun.Status::Queued;
        DeepScanRun."Requested At" := CurrentDateTime();
        DeepScanRun."Requested By" := CopyStr(UserId(), 1, MaxStrLen(DeepScanRun."Requested By"));
        DeepScanRun."Company Name" := CopyStr(CompanyName(), 1, MaxStrLen(DeepScanRun."Company Name"));
        DeepScanRun."Headline" := 'Deep scan queued';
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

        Message('Deep scan %1 was queued and scheduled in the background.', DeepScanRun."Run ID");

        exit(EntryNo);
    end;

    local procedure EnsureDeepScanAllowed(var Setup: Record "DH Setup")
    begin
        if Setup."API Base URL" = '' then
            Error('Please configure API Base URL first.');

        if Setup."Tenant ID" = '' then
            Error('Please register the tenant first.');

        if not Setup."Premium Enabled" then
            Error('Deep scan is currently blocked. Enable Premium Enabled in setup for your test tenant.');
    end;

    local procedure GetNextRunEntryNo(): Integer
    var
        DeepScanRun: Record "DH Deep Scan Run";
    begin
        if DeepScanRun.FindLast() then
            exit(DeepScanRun."Entry No." + 1);

        exit(1);
    end;

    local procedure BuildRunId(EntryNo: Integer): Code[50]
    var
        TimeText: Text;
    begin
        TimeText := DelChr(Format(CurrentDateTime()), '=', ' ./:-');
        exit(CopyStr('DEEP' + TimeText + Format(EntryNo), 1, 50));
    end;
}