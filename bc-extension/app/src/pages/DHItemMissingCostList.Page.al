page 53137 "DH Item Missing Cost List"
{
    PageType = List;
    SourceTable = Item;
    ApplicationArea = All;
    UsageCategory = None;
    Caption = 'DH Item Missing Cost List';
    SourceTableView = where("Unit Cost" = const(0));

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    Caption = 'Item No.';
                    Editable = false;
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Unit Cost"; Rec."Unit Cost")
                {
                    ApplicationArea = All;
                }
                field("Unit Price"; Rec."Unit Price")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field(Inventory; Rec.Inventory)
                {
                    ApplicationArea = All;
                    Editable = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ExcludeFromIssue)
            {
                Caption = 'Von Analyse ausnehmen';
                ApplicationArea = All;
                Image = Cancel;

                trigger OnAction()
                var
                    ExceptionMgt: Codeunit "DH Exception Mgt.";
                begin
                    ExceptionMgt.AddItemException(Rec, 'ITEMS_WITHOUT_UNIT_COST', StrSubstNo('Manuell aus ITEMS_WITHOUT_UNIT_COST ausgenommen.', 'ITEMS_WITHOUT_UNIT_COST'));
                    CurrPage.Update(false);
                end;
            }
            action(MarkCorrected)
            {
                Caption = 'Als korrigiert markieren';
                ApplicationArea = All;
                Image = EditLines;

                trigger OnAction()
                var
                    ExceptionMgt: Codeunit "DH Exception Mgt.";
                begin
                    ExceptionMgt.MarkItemCorrected(Rec, 'ITEMS_WITHOUT_UNIT_COST', 'Datensatz manuell als korrigiert markiert.');
                    CurrPage.Update(false);
                end;
            }

            action(OpenItemCard)
            {
                Caption = 'Zur Liste';
                ApplicationArea = All;
                Image = Card;

                trigger OnAction()
                begin
                    Page.Run(Page::"Item Card", Rec);
                end;
            }
        }
    }
}
