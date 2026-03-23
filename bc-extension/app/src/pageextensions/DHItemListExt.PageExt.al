pageextension 53163 "DH Item List Ext" extends "Item List"
{
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
                    ExceptionMgt.OpenItemExceptions(Rec);
                end;
            }
        }
    }
}
