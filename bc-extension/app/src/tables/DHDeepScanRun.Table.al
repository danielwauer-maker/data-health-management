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
        field(17; "Estimated Loss (EUR)"; Decimal)
        {
            Caption = 'Estimated Loss (EUR)';
            DecimalPlaces = 0 : 2;
        }
        field(18; "Potential Saving (EUR)"; Decimal)
        {
            Caption = 'Potential Saving (EUR)';
            DecimalPlaces = 0 : 2;
        }
        field(19; "Current Module"; Text[50])
        {
            Caption = 'Current Module';
        }
        field(20; "Progress %"; Integer)
        {
            Caption = 'Progress %';
        }
        field(21; "Completed Modules"; Integer)
        {
            Caption = 'Completed Modules';
        }
        field(22; "Total Modules"; Integer)
        {
            Caption = 'Total Modules';
        }
        field(23; "ETA Text"; Text[100])
        {
            Caption = 'ETA';
        }
        field(24; "System Progress %"; Integer)
        {
            Caption = 'System Progress %';
        }
        field(25; "Finance Progress %"; Integer)
        {
            Caption = 'Finance Progress %';
        }
        field(26; "Sales Progress %"; Integer)
        {
            Caption = 'Sales Progress %';
        }
        field(27; "Purchasing Progress %"; Integer)
        {
            Caption = 'Purchasing Progress %';
        }
        field(28; "Inventory Progress %"; Integer)
        {
            Caption = 'Inventory Progress %';
        }
        field(29; "CRM Progress %"; Integer)
        {
            Caption = 'CRM Progress %';
        }
        field(30; "Manufacturing Progress %"; Integer)
        {
            Caption = 'Manufacturing Progress %';
        }
        field(31; "Service Progress %"; Integer)
        {
            Caption = 'Service Progress %';
        }
        field(32; "Jobs Progress %"; Integer)
        {
            Caption = 'Jobs Progress %';
        }
        field(33; "HR Progress %"; Integer)
        {
            Caption = 'HR Progress %';
        }
        field(34; "Affected Records"; Integer)
        {
            Caption = 'Affected Records';
        }
        field(35; "System Score"; Integer)
        {
            Caption = 'System Score';
        }
        field(36; "Finance Score"; Integer)
        {
            Caption = 'Finance Score';
        }
        field(37; "Sales Score"; Integer)
        {
            Caption = 'Sales Score';
        }
        field(38; "Purchasing Score"; Integer)
        {
            Caption = 'Purchasing Score';
        }
        field(39; "Inventory Score"; Integer)
        {
            Caption = 'Inventory Score';
        }
        field(40; "CRM Score"; Integer)
        {
            Caption = 'CRM Score';
        }
        field(41; "Manufacturing Score"; Integer)
        {
            Caption = 'Manufacturing Score';
        }
        field(42; "Service Score"; Integer)
        {
            Caption = 'Service Score';
        }
        field(43; "Jobs Score"; Integer)
        {
            Caption = 'Jobs Score';
        }
        field(44; "HR Score"; Integer)
        {
            Caption = 'HR Score';
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
