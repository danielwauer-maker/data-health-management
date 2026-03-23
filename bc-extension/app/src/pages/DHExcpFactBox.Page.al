page 53154 "DH Excp. FactBox"
{
    PageType = ListPart;
    SourceTable = "DH Issue Exception";
    ApplicationArea = All;
    Caption = 'DH Exceptions';
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Issue Code"; Rec."Issue Code")
                {
                    ApplicationArea = All;
                }
                field(Reason; Rec.Reason)
                {
                    ApplicationArea = All;
                }
                field("Created By User"; Rec."Created By User")
                {
                    ApplicationArea = All;
                }
            }
        }
    }
}
