page 53155 "DH Action Log FB"
{
    PageType = ListPart;
    SourceTable = "DH Issue Action Log";
    ApplicationArea = All;
    Caption = 'DH Activity';
    Editable = false;
    SourceTableView = sorting("Table ID", "Record SystemId", "Action At") order(descending);

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Action At"; Rec."Action At")
                {
                    ApplicationArea = All;
                }
                field("Action Type"; Rec."Action Type")
                {
                    ApplicationArea = All;
                }
                field("Issue Code"; Rec."Issue Code")
                {
                    ApplicationArea = All;
                }
                field("Action User"; Rec."Action User")
                {
                    ApplicationArea = All;
                }
            }
        }
    }
}
