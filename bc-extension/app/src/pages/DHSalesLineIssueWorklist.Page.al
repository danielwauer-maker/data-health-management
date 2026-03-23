page 53139 "DH Sales Line Issue Worklist"
{
    PageType = List;
    SourceTable = "Sales Line";
    ApplicationArea = All;
    UsageCategory = Lists;
    Caption = 'DH Sales Line Issue Worklist';
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Document Type"; Rec."Document Type")
                {
                    ApplicationArea = All;
                }
                field("Document No."; Rec."Document No.")
                {
                    ApplicationArea = All;
                }
                field("Line No."; Rec."Line No.")
                {
                    ApplicationArea = All;
                }
                field(Type; Rec.Type)
                {
                    ApplicationArea = All;
                }
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                }
                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                }
                field("Unit Price"; Rec."Unit Price")
                {
                    ApplicationArea = All;
                }
                field("Shipment Date"; Rec."Shipment Date")
                {
                    ApplicationArea = All;
                }
                field("Shortcut Dimension 1 Code"; Rec."Shortcut Dimension 1 Code")
                {
                    ApplicationArea = All;
                }
                field("Shortcut Dimension 2 Code"; Rec."Shortcut Dimension 2 Code")
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(MarkIssueCorrected)
            {
                Caption = 'Als korrigiert markieren';
                ApplicationArea = All;
                Image = EditLines;

                trigger OnAction()
                begin
                    MarkLinkedMasterRecordCorrected();
                end;
            }

            action(OpenDocument)
            {
                Caption = 'Daten korrigieren';
                ApplicationArea = All;
                Image = EditLines;

                trigger OnAction()
                var
                    SalesHeader: Record "Sales Header";
                begin
                    if SalesHeader.Get(Rec."Document Type", Rec."Document No.") then
                        Page.Run(Page::"Sales Order", SalesHeader);
                end;
            }
        }
    }

    var
        CurrentIssueCode: Code[50];

    trigger OnOpenPage()
    begin
        ApplyIssueFilter();
    end;

    procedure SetIssueCode(IssueCode: Code[50])
    begin
        CurrentIssueCode := IssueCode;
    end;

    local procedure ApplyIssueFilter()
    begin
        Rec.FilterGroup(2);
        Rec.SetRange("Document Type", Rec."Document Type"::Order);

        case CurrentIssueCode of
            'SALES_LINES_ZERO_QUANTITY':
                Rec.SetRange(Quantity, 0);
            'SALES_LINES_ZERO_PRICE':
                Rec.SetRange("Unit Price", 0);
            'SALES_LINES_MISSING_NO':
                Rec.SetRange("No.", '');
            'SALES_LINES_MISSING_DIMENSIONS':
                begin
                    Rec.SetRange("Shortcut Dimension 1 Code", '');
                    Rec.SetRange("Shortcut Dimension 2 Code", '');
                end;
            'SALES_LINES_WITH_BLOCKED_ITEMS':
                MarkBlockedItemLines();
        end;

        Rec.FilterGroup(0);
    end;


    local procedure MarkBlockedItemLines()
    var
        Item: Record Item;
    begin
        Rec.SetRange(Type, Rec.Type::Item);
        Rec.MarkedOnly(false);
        if Rec.FindSet() then
            repeat
                if (Rec."No." <> '') and Item.Get(Rec."No.") then
                    if Item.Blocked then
                        Rec.Mark(true);
            until Rec.Next() = 0;
        Rec.MarkedOnly(true);
    end;

    local procedure MarkLinkedMasterRecordCorrected()
    var
        Item: Record Item;
        ExceptionMgt: Codeunit "DH Exception Mgt.";
    begin
        if (Rec.Type = Rec.Type::Item) and (Rec."No." <> '') and Item.Get(Rec."No.") then begin
            ExceptionMgt.MarkItemCorrected(Item, CurrentIssueCode, 'Korrektur aus Verkaufszeilen-Worklist dokumentiert.');
            exit;
        end;

        Message('Korrektur wurde nicht protokolliert, da kein Stammdatensatz zugeordnet werden konnte.');
    end;

}
