table 53133 "DH Dashboard Issue"
{
    Caption = 'DH Dashboard Issue';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(2; "Dashboard Scan Entry No."; Integer)
        {
            Caption = 'Dashboard Scan Entry No.';
        }
        field(3; "Source Type"; Option)
        {
            Caption = 'Source Type';
            OptionMembers = Quick,Deep;
        }
        field(4; "Source Entry No."; Integer)
        {
            Caption = 'Source Entry No.';
        }
        field(5; "Issue Code"; Code[50])
        {
            Caption = 'Issue Code';
        }
        field(6; Title; Text[150])
        {
            Caption = 'Title';
        }
        field(7; Severity; Code[20])
        {
            Caption = 'Severity';
        }
        field(8; "Affected Count"; Integer)
        {
            Caption = 'Affected Count';
        }
        field(9; "Recommendation Preview"; Text[250])
        {
            Caption = 'Recommendation Preview';
        }
        field(10; "Premium Only"; Boolean)
        {
            Caption = 'Premium';
        }
        field(11; "Severity Sort Order"; Integer)
        {
            Caption = 'Severity Sort Order';
        }
        field(12; "Affected Count Sort Value"; Integer)
        {
            Caption = 'Affected Count Sort Value';
        }
        field(13; "Estimated Impact (EUR)"; Decimal)
        {
            Caption = 'Estimated Impact (EUR)';
            DecimalPlaces = 0 : 2;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(Key2; "Dashboard Scan Entry No.")
        {
        }
        key(Key3; "Dashboard Scan Entry No.", "Source Type")
        {
        }
        key(Key4; "Dashboard Scan Entry No.", "Affected Count")
        {
        }
        key(Key5; "Dashboard Scan Entry No.", "Severity Sort Order", "Affected Count Sort Value")
        {
        }
    }
}
