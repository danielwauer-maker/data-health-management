table 53129 "DH Deep Scan Finding"
{
    Caption = 'DH Deep Scan Finding';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(2; "Deep Scan Entry No."; Integer)
        {
            Caption = 'Deep Scan Entry No.';
        }
        field(3; Category; Code[30])
        {
            Caption = 'Category';
        }
        field(4; "Issue Code"; Code[50])
        {
            Caption = 'Issue Code';
        }
        field(5; Title; Text[150])
        {
            Caption = 'Title';
        }
        field(6; Severity; Code[20])
        {
            Caption = 'Severity';
        }
        field(7; "Affected Count"; Integer)
        {
            Caption = 'Affected Count';
        }
        field(8; "Recommendation Preview"; Text[250])
        {
            Caption = 'Recommendation Preview';
        }
        field(9; "Premium Only"; Boolean)
        {
            Caption = 'Premium';
        }
        field(10; "Severity Sort Order"; Integer)
        {
            Caption = 'Severity Sort Order';
        }
        field(11; "Affected Count Sort Value"; Integer)
        {
            Caption = 'Affected Count Sort Value';
        }
        field(12; "Estimated Impact (EUR)"; Decimal)
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
        key(Key2; "Deep Scan Entry No.")
        {
        }
        key(Key3; "Deep Scan Entry No.", Category)
        {
        }
        key(Key4; "Deep Scan Entry No.", "Affected Count")
        {
        }
        key(Key5; "Deep Scan Entry No.", "Severity Sort Order", "Affected Count Sort Value")
        {
        }
    }
}
