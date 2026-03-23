table 53104 "DH Scan Trend"
{
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Tenant ID"; Code[50])
        {
            DataClassification = CustomerContent;
        }
        field(2; "Latest Scan ID"; Code[50])
        {
            DataClassification = CustomerContent;
        }
        field(3; "Previous Scan ID"; Code[50])
        {
            DataClassification = CustomerContent;
        }
        field(4; "Latest Score"; Integer)
        {
            DataClassification = CustomerContent;
        }
        field(5; "Previous Score"; Integer)
        {
            DataClassification = CustomerContent;
        }
        field(6; "Delta"; Integer)
        {
            DataClassification = CustomerContent;
        }
        field(7; "Trend"; Text[10])
        {
            DataClassification = CustomerContent;
        }
        field(8; "Last Updated At"; DateTime)
        {
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Tenant ID")
        {
            Clustered = true;
        }
    }
}