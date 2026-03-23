table 53120 "DH Scan Header"
{
    Caption = 'DH Scan Header';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(2; "Scan Type"; Option)
        {
            Caption = 'Scan Type';
            OptionMembers = Quick,Deep;
        }
        field(3; "Scan DateTime"; DateTime)
        {
            Caption = 'Scan DateTime';
        }
        field(4; "Data Score"; Integer)
        {
            Caption = 'Data Score';
        }
        field(5; "Checks Count"; Integer)
        {
            Caption = 'Checks Count';
        }
        field(6; "Issues Count"; Integer)
        {
            Caption = 'Issues Count';
        }
        field(7; "Backend Scan Id"; Code[50])
        {
            Caption = 'Backend Scan Id';
        }
        field(8; "Headline"; Text[250])
        {
            Caption = 'Headline';
        }
        field(9; "Rating"; Code[20])
        {
            Caption = 'Rating';
        }
        field(10; "Premium Available"; Boolean)
        {
            Caption = 'Premium Available';
        }

        field(11; "Run ID"; Code[50])
        {
            Caption = 'Run ID';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }

        key(Key2; "Scan DateTime")
        {
        }

        key(Key3; "Run ID")
        {
        }
    }

    trigger OnDelete()
    var
        ScanIssue: Record "DH Scan Issue";
        DashboardIssue: Record "DH Dashboard Issue";
    begin
        ScanIssue.SetRange("Scan Entry No.", "Entry No.");
        if not ScanIssue.IsEmpty() then
            ScanIssue.DeleteAll(true);

        DashboardIssue.SetRange("Dashboard Scan Entry No.", "Entry No.");
        if not DashboardIssue.IsEmpty() then
            DashboardIssue.DeleteAll(true);
    end;
    procedure GetDisplayRunId(): Code[50]
    begin
        if "Run ID" <> '' then
            exit("Run ID");

        exit("Backend Scan Id");
    end;
}
