codeunit 53129 "DH Deep Scan Failure"
{
    TableNo = "DH Deep Scan Run";

    trigger OnRun()
    begin
        MarkRunAsFailed(Rec);
    end;

    local procedure MarkRunAsFailed(var DeepScanRun: Record "DH Deep Scan Run")
    begin
        if not DeepScanRun.Get(DeepScanRun."Entry No.") then
            exit;

        DeepScanRun.Status := DeepScanRun.Status::Failed;
        DeepScanRun."Finished At" := CurrentDateTime();
        DeepScanRun."Headline" := 'Deep scan failed';
        DeepScanRun."Error Message" := CopyStr(GetLastErrorText(), 1, MaxStrLen(DeepScanRun."Error Message"));
        DeepScanRun.Modify(true);
    end;
}