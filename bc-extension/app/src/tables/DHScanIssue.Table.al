table 53121 "DH Scan Issue"
{
    Caption = 'DH Scan Issue';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(2; "Scan Entry No."; Integer)
        {
            Caption = 'Scan Entry No.';
        }
        field(3; "Issue Code"; Code[50])
        {
            Caption = 'Issue Code';
        }
        field(4; "Title"; Text[150])
        {
            Caption = 'Title';
        }
        field(5; "Severity"; Code[20])
        {
            Caption = 'Severity';
        }
        field(6; "Affected Count"; Integer)
        {
            Caption = 'Affected Count';
        }
        field(7; "Recommendation Preview"; Text[250])
        {
            Caption = 'Recommendation Preview';
        }
        field(8; "Premium Only"; Boolean)
        {
            Caption = 'Premium';
        }
        field(9; "Severity Sort Order"; Integer)
        {
            Caption = 'Severity Sort Order';
        }
        field(10; "Affected Count Sort Value"; Integer)
        {
            Caption = 'Affected Count Sort Value';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }

        key(Key2; "Scan Entry No.")
        {
        }

        key(Key3; "Scan Entry No.", "Severity Sort Order", "Affected Count Sort Value")
        {
        }
    }
}