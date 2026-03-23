table 53150 "DH Issue Exception"
{
    Caption = 'DH Issue Exception';
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
        field(7; Active; Boolean)
        {
            Caption = 'Active';
        }
        field(8; Reason; Text[250])
        {
            Caption = 'Reason';
        }
        field(9; "Created By User"; Code[50])
        {
            Caption = 'Created By User';
        }
        field(10; "Created At"; DateTime)
        {
            Caption = 'Created At';
        }
        field(11; "Deactivated By User"; Code[50])
        {
            Caption = 'Deactivated By User';
        }
        field(12; "Deactivated At"; DateTime)
        {
            Caption = 'Deactivated At';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(Key2; "Table ID", "Record SystemId", "Issue Code", Active)
        {
        }
        key(Key3; "Table ID", "Record SystemId", Active)
        {
        }
    }

    trigger OnInsert()
    begin
        if "Entry No." = 0 then
            "Entry No." := GetNextEntryNo();

        if "Created At" = 0DT then
            "Created At" := CurrentDateTime();

        if "Created By User" = '' then
            "Created By User" := CopyStr(UserId(), 1, MaxStrLen("Created By User"));

        if not Active then
            Active := true;
    end;

    local procedure GetNextEntryNo(): Integer
    var
        IssueException: Record "DH Issue Exception";
    begin
        if IssueException.FindLast() then
            exit(IssueException."Entry No." + 1);

        exit(1);
    end;
}
