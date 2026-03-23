table 53151 "DH Issue Action Log"
{
    Caption = 'DH Issue Action Log';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(2; "Table ID"; Integer)
        {
            Caption = 'Table ID';
        }
        field(3; "Record SystemId"; Guid)
        {
            Caption = 'Record SystemId';
        }
        field(4; "Record No."; Code[20])
        {
            Caption = 'Record No.';
        }
        field(5; "Record Caption"; Text[100])
        {
            Caption = 'Record Caption';
        }
        field(6; "Issue Code"; Code[50])
        {
            Caption = 'Issue Code';
        }
        field(7; "Action Type"; Code[20])
        {
            Caption = 'Action Type';
        }
        field(8; Comment; Text[250])
        {
            Caption = 'Comment';
        }
        field(9; "Action User"; Code[50])
        {
            Caption = 'Action User';
        }
        field(10; "Action At"; DateTime)
        {
            Caption = 'Action At';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(Key2; "Table ID", "Record SystemId", "Action At")
        {
        }
    }

    trigger OnInsert()
    begin
        if "Entry No." = 0 then
            "Entry No." := GetNextEntryNo();

        if "Action At" = 0DT then
            "Action At" := CurrentDateTime();

        if "Action User" = '' then
            "Action User" := CopyStr(UserId(), 1, MaxStrLen("Action User"));
    end;

    local procedure GetNextEntryNo(): Integer
    var
        IssueActionLog: Record "DH Issue Action Log";
    begin
        if IssueActionLog.FindLast() then
            exit(IssueActionLog."Entry No." + 1);

        exit(1);
    end;
}
