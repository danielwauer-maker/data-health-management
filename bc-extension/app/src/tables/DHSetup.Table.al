table 53100 "DH Setup"
{
    Caption = 'DH Setup';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
        }

        field(2; "Tenant ID"; Text[100])
        {
            Caption = 'Tenant ID';
            DataClassification = SystemMetadata;
        }

        field(3; "API Base URL"; Text[250])
        {
            Caption = 'API Base URL';
            DataClassification = SystemMetadata;

            trigger OnValidate()
            begin
                "API Base URL" := GetFixedApiBaseUrl();
            end;
        }

        field(4; "API Token"; Text[250])
        {
            Caption = 'API Token';
            DataClassification = SystemMetadata;
        }

        field(5; "Last Score"; Integer)
        {
            Caption = 'Last Score';
            DataClassification = SystemMetadata;
        }

        field(6; "Last Scan Date"; DateTime)
        {
            Caption = 'Last Scan Date';
            DataClassification = SystemMetadata;
        }

        field(7; "Premium Enabled"; Boolean)
        {
            Caption = 'Premium Enabled';
            DataClassification = SystemMetadata;
        }

        field(8; Registered; Boolean)
        {
            Caption = 'Registered';
            DataClassification = SystemMetadata;
        }

        field(9; "Registration Date"; DateTime)
        {
            Caption = 'Registration Date';
            DataClassification = SystemMetadata;
        }

        field(10; "Current Plan"; Enum "DH License Plan")
        {
            Caption = 'Current Plan';
            DataClassification = SystemMetadata;
        }

        field(11; "License Status"; Enum "DH License Status")
        {
            Caption = 'License Status';
            DataClassification = SystemMetadata;
        }

        field(12; "Last License Check"; DateTime)
        {
            Caption = 'Last License Check';
            DataClassification = SystemMetadata;
        }

        field(13; "Data Processing Consent"; Boolean)
        {
            Caption = 'Data Processing Consent';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    trigger OnInsert()
    begin
        if "Primary Key" = '' then
            "Primary Key" := 'SETUP';

        ApplyDefaults();
    end;

    trigger OnModify()
    begin
        ApplyDefaults();
    end;

    procedure ApplyDefaults()
    begin
        if "API Base URL" <> GetFixedApiBaseUrl() then
            "API Base URL" := GetFixedApiBaseUrl();
    end;

    procedure GetFixedApiBaseUrl(): Text[250]
    begin
        exit('https://api.bcsentinel.com');
    end;
}