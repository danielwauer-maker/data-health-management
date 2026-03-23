codeunit 53145 "DH Run ID Mgt."
{
    procedure GetNextRunId(var Setup: Record "DH Setup"): Code[50]
    var
        RunDate: Date;
        NextCounter: Integer;
        CounterText: Text;
    begin
        RunDate := Today();

        if Setup."Primary Key" = '' then begin
            Setup.Init();
            Setup."Primary Key" := 'SETUP';
            Setup.Insert(true);
        end else
            if not Setup.Get(Setup."Primary Key") then
                Setup.Get('SETUP');

        if Setup."Last Run ID Date" <> RunDate then begin
            Setup."Last Run ID Date" := RunDate;
            Setup."Last Run ID Counter" := 0;
        end;

        NextCounter := Setup."Last Run ID Counter" + 1;
        Setup."Last Run ID Counter" := NextCounter;
        Setup.Modify(true);

        CounterText := PadLeft(Format(NextCounter), 6, '0');
        exit(CopyStr('RUN_' + Format(RunDate, 0, '<Year4><Month,2><Day,2>') + '_' + CounterText, 1, 50));
    end;

    local procedure PadLeft(Value: Text; TargetLength: Integer; PadChar: Text[1]): Text
    begin
        while StrLen(Value) < TargetLength do
            Value := PadChar + Value;

        exit(Value);
    end;
}
