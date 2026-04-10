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
                "API Base URL" := NormalizeApiBaseUrl("API Base URL");
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

        field(14; "Last Run ID Date"; Date)
        {
            Caption = 'Last Run ID Date';
            DataClassification = SystemMetadata;
        }

        field(15; "Last Run ID Counter"; Integer)
        {
            Caption = 'Last Run ID Counter';
            DataClassification = SystemMetadata;
        }

        field(16; "Scan System Module"; Boolean)
        {
            Caption = 'Scan System';
            DataClassification = SystemMetadata;
            InitValue = true;
        }

        field(17; "Scan Finance Module"; Boolean)
        {
            Caption = 'Scan Finance';
            DataClassification = SystemMetadata;
            InitValue = true;
        }

        field(18; "Scan Sales Module"; Boolean)
        {
            Caption = 'Scan Sales';
            DataClassification = SystemMetadata;
            InitValue = true;
        }

        field(19; "Scan Purchasing Module"; Boolean)
        {
            Caption = 'Scan Purchasing';
            DataClassification = SystemMetadata;
            InitValue = true;
        }

        field(20; "Scan Inventory Module"; Boolean)
        {
            Caption = 'Scan Inventory';
            DataClassification = SystemMetadata;
            InitValue = true;
        }

        field(21; "Scan CRM Module"; Boolean)
        {
            Caption = 'Scan CRM';
            DataClassification = SystemMetadata;
            InitValue = true;
        }

        field(22; "Scan Manufacturing Module"; Boolean)
        {
            Caption = 'Scan Manufacturing';
            DataClassification = SystemMetadata;
            InitValue = true;
        }

        field(23; "Scan Service Module"; Boolean)
        {
            Caption = 'Scan Service';
            DataClassification = SystemMetadata;
            InitValue = true;
        }

        field(24; "Scan Jobs Module"; Boolean)
        {
            Caption = 'Scan Jobs';
            DataClassification = SystemMetadata;
            InitValue = true;
        }

        field(25; "Scan HR Module"; Boolean)
        {
            Caption = 'Scan HR';
            DataClassification = SystemMetadata;
            InitValue = true;
        }
        field(26; "Issue Drilldown Code"; Code[50])
        {
            Caption = 'Issue Drilldown Code';
            DataClassification = SystemMetadata;
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
        if "API Base URL" = '' then
            "API Base URL" := GetDefaultApiBaseUrl()
        else
            "API Base URL" := NormalizeApiBaseUrl("API Base URL");

        EnsureModuleDefaults();
    end;

    procedure GetDefaultApiBaseUrl(): Text[250]
    begin
        exit('https://api.bcsentinel.com');
    end;

    procedure GetFixedApiBaseUrl(): Text[250]
    begin
        // Backward-compatible alias used by existing codeunits.
        exit(GetDefaultApiBaseUrl());
    end;

    procedure NormalizeApiBaseUrl(Value: Text): Text[250]
    var
        NormalizedValue: Text;
    begin
        NormalizedValue := DelChr(Value, '<>', ' ');

        if NormalizedValue = '' then
            exit(GetDefaultApiBaseUrl());

        NormalizedValue := RemoveTrailingSlash(NormalizedValue);

        if StrPos(LowerCase(NormalizedValue), 'http://') <> 1 then
            if StrPos(LowerCase(NormalizedValue), 'https://') <> 1 then
                Error('API Base URL must start with http:// or https://');

        if StrLen(NormalizedValue) > MaxStrLen("API Base URL") then
            Error('API Base URL is too long.');

        exit(CopyStr(NormalizedValue, 1, MaxStrLen("API Base URL")));
    end;

    local procedure RemoveTrailingSlash(Value: Text): Text
    begin
        while (StrLen(Value) > 0) and (CopyStr(Value, StrLen(Value), 1) = '/') do
            Value := CopyStr(Value, 1, StrLen(Value) - 1);

        exit(Value);
    end;

    procedure IsPremiumLicenseActive(): Boolean
    begin
        exit(("Current Plan" = "Current Plan"::Premium) and (("License Status" = "License Status"::Active) or ("License Status" = "License Status"::Trial)));
    end;

    procedure GetFeatureAccessText(): Text[100]
    begin
        if "Premium Enabled" then
            exit('Premium actions unlocked');

        exit('Deep scan basis available, premium actions locked');
    end;

    procedure GetUpgradeHintText(): Text[250]
    begin
        if "Premium Enabled" then
            exit('Premium recommendations and correction actions are available for this tenant.');

        exit('This scan already uses the full DeepScan data basis. Upgrade to Premium to unlock recommendations, drilldowns, and correction worklists.');
    end;

    procedure EnsureModuleDefaults()
    begin
        if not HasAnyModuleEnabled() then begin
            "Scan System Module" := true;
            "Scan Finance Module" := true;
            "Scan Sales Module" := true;
            "Scan Purchasing Module" := true;
            "Scan Inventory Module" := true;
            "Scan CRM Module" := true;
            "Scan Manufacturing Module" := true;
            "Scan Service Module" := true;
            "Scan Jobs Module" := true;
            "Scan HR Module" := true;
        end;
    end;

    procedure HasAnyModuleEnabled(): Boolean
    begin
        exit(
          "Scan System Module" or
          "Scan Finance Module" or
          "Scan Sales Module" or
          "Scan Purchasing Module" or
          "Scan Inventory Module" or
          "Scan CRM Module" or
          "Scan Manufacturing Module" or
          "Scan Service Module" or
          "Scan Jobs Module" or
          "Scan HR Module");
    end;

    procedure GetEnabledDeepScanModuleCount(): Integer
    var
        EnabledCount: Integer;
    begin
        if "Scan System Module" then
            EnabledCount += 1;
        if "Scan Finance Module" then
            EnabledCount += 1;
        if "Scan Sales Module" then
            EnabledCount += 1;
        if "Scan Purchasing Module" then
            EnabledCount += 1;
        if "Scan Inventory Module" then
            EnabledCount += 1;
        if "Scan CRM Module" then
            EnabledCount += 1;
        if "Scan Manufacturing Module" then
            EnabledCount += 1;
        if "Scan Service Module" then
            EnabledCount += 1;
        if "Scan Jobs Module" then
            EnabledCount += 1;
        if "Scan HR Module" then
            EnabledCount += 1;

        exit(EnabledCount);
    end;

}
