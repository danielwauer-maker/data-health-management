codeunit 53160 "DH Monitor Refresh Task"
{
    trigger OnRun()
    var
        Parameters: Dictionary of [Text, Text];
        Results: Dictionary of [Text, Text];
        DeepScanRun: Record "DH Deep Scan Run";
        EntryNoText: Text;
        WaitMsText: Text;
        EntryNo: Integer;
        WaitMs: Integer;
    begin
        Parameters := Page.GetBackgroundParameters();

        if not Parameters.Get('EntryNo', EntryNoText) then
            Error('EntryNo parameter is missing.');
        if not Evaluate(EntryNo, EntryNoText) then
            Error('EntryNo parameter is invalid.');

        if Parameters.Get('WaitMs', WaitMsText) then
            if not Evaluate(WaitMs, WaitMsText) then
                WaitMs := 1500
            else begin end
        else
            WaitMs := 1500;

        if WaitMs < 250 then
            WaitMs := 250;
        if WaitMs > 5000 then
            WaitMs := 5000;

        Sleep(WaitMs);

        if DeepScanRun.Get(EntryNo) then begin
            Results.Add('EntryNo', Format(DeepScanRun."Entry No."));
            Results.Add('Status', Format(DeepScanRun.Status));
            Results.Add('ProgressPct', Format(DeepScanRun."Progress %"));
            Results.Add('CurrentModule', DeepScanRun."Current Module");
        end else begin
            Results.Add('EntryNo', Format(EntryNo));
            Results.Add('Status', 'Missing');
            Results.Add('ProgressPct', '0');
            Results.Add('CurrentModule', '');
        end;

        Page.SetBackgroundTaskResult(Results);
    end;
}
