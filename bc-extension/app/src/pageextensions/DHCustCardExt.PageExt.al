pageextension 53158 "DH Cust Card Ext" extends "Customer Card"
{
    layout
    {
        addlast(FactBoxes)
        {
            part(DHExceptions; "DH Excp. FactBox")
            {
                ApplicationArea = All;
                SubPageLink = "Table ID" = const(18), "Record SystemId" = field(SystemId), Active = const(true);
            }
            part(DHActivity; "DH Action Log FB")
            {
                ApplicationArea = All;
                SubPageLink = "Table ID" = const(18), "Record SystemId" = field(SystemId);
            }
        }
    }

    actions
    {
        addlast(Processing)
        {
            action(DHOpenExceptions)
            {
                Caption = 'DH-Ausnahmen';
                ApplicationArea = All;
                Image = View;
                trigger OnAction()
                var
                    ExceptionMgt: Codeunit "DH Exception Mgt.";
                begin
                    ExceptionMgt.OpenCustomerExceptions(Rec);
                end;
            }
        }
    }
}
