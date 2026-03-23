table 53100 "DH Setup"
{
    Caption = 'DH Setup';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            DataClassification = SystemMetadata;
        }

        field(2; "Tenant ID"; Text[100])
        {
            Caption = 'Tenant ID';
        }

        field(3; "API Base URL"; Text[250])
        {
            Caption = 'API Base URL';
        }

        field(4; "API Token"; Text[250])
        {
            Caption = 'API Token';
        }

        field(5; "Last Score"; Integer)
        {
            Caption = 'Last Score';
        }

        field(6; "Last Scan Date"; DateTime)
        {
            Caption = 'Last Scan Date';
        }

        field(7; "Premium Enabled"; Boolean)
        {
            Caption = 'Premium Enabled';
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
}