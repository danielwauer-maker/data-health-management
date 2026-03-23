table 53128 "DH Deep Scan Run"
{
    Caption = 'DH Deep Scan Run';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }

        field(2; "Run ID"; Code[50])
        {
            Caption = 'Run ID';
        }

        field(3; Status; Option)
        {
            Caption = 'Status';
            OptionMembers = Queued,Running,Completed,Failed,Canceled;
        }

        field(4; "Requested At"; DateTime)
        {
            Caption = 'Requested At';
        }

        field(5; "Requested By"; Text[100])
        {
            Caption = 'Requested By';
        }

        field(6; "Started At"; DateTime)
        {
            Caption = 'Started At';
        }

        field(7; "Finished At"; DateTime)
        {
            Caption = 'Finished At';
        }

        field(8; "Deep Score"; Integer)
        {
            Caption = 'Deep Score';
        }

        field(9; "Checks Count"; Integer)
        {
            Caption = 'Checks Count';
        }

        field(10; "Issues Count"; Integer)
        {
            Caption = 'Issues Count';
        }

        field(11; "Headline"; Text[250])
        {
            Caption = 'Headline';
        }

        field(12; "Rating"; Code[20])
        {
            Caption = 'Rating';
        }

        field(13; "Error Message"; Text[250])
        {
            Caption = 'Error Message';
        }

        field(14; "Company Name"; Text[100])
        {
            Caption = 'Company Name';
        }

        field(15; "Backend Run Id"; Code[50])
        {
            Caption = 'Backend Run Id';
        }

        field(16; "Task ID"; Guid)
        {
            Caption = 'Task ID';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }

        key(Key2; "Requested At")
        {
        }

        key(Key3; Status)
        {
        }

        key(Key4; "Run ID")
        {
        }
    }

    trigger OnDelete()
    var
        Finding: Record "DH Deep Scan Finding";
    begin
        Finding.SetRange("Deep Scan Entry No.", "Entry No.");
        if not Finding.IsEmpty() then
            Finding.DeleteAll(true);
    end;
}