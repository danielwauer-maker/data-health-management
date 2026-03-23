enum 53146 "DH Duplicate Source Type"
{
    Extensible = false;

    value(0; Customer)
    {
        Caption = 'Customer';
    }
    value(1; Vendor)
    {
        Caption = 'Vendor';
    }
}

table 53149 "DH Duplicate Buffer"
{
    Caption = 'DH Duplicate Buffer';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            DataClassification = SystemMetadata;
        }
        field(2; "Source Type"; Enum "DH Duplicate Source Type")
        {
            DataClassification = CustomerContent;
        }
        field(3; "Source No."; Code[20])
        {
            DataClassification = CustomerContent;
        }
        field(4; Name; Text[100])
        {
            DataClassification = CustomerContent;
        }
        field(5; City; Text[30])
        {
            DataClassification = CustomerContent;
        }
        field(6; "Post Code"; Code[20])
        {
            DataClassification = CustomerContent;
        }
        field(7; "E-Mail"; Text[80])
        {
            DataClassification = CustomerContent;
        }
        field(8; "VAT Registration No."; Text[20])
        {
            DataClassification = CustomerContent;
        }
        field(9; "Group Key"; Text[250])
        {
            DataClassification = CustomerContent;
        }
        field(10; Reason; Text[100])
        {
            DataClassification = CustomerContent;
        }
        field(11; "Duplicate Count"; Integer)
        {
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(GroupByKey; "Group Key", "Source Type")
        {
        }
    }
}
