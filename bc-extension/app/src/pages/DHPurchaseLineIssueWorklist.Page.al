page 53144 "DH Purch. Line Worklist"
{
    PageType = List;
    SourceTable = "Purchase Line";
    ApplicationArea = All;
    UsageCategory = Lists;
    Caption = 'DH Purchase Line Issue Worklist';
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
                field("Direct Unit Cost"; Rec."Direct Unit Cost")
                {
                    ApplicationArea = All;
                }
                field("Expected Receipt Date"; Rec."Expected Receipt Date")
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
                    PurchaseHeader: Record "Purchase Header";
                begin
                    if PurchaseHeader.Get(Rec."Document Type", Rec."Document No.") then
                        Page.Run(Page::"Purchase Order", PurchaseHeader);
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
            'PURCHASE_LINES_ZERO_QUANTITY':
                Rec.SetRange(Quantity, 0);
            'PURCHASE_LINES_ZERO_COST':
                Rec.SetRange("Direct Unit Cost", 0);
            'PURCHASE_LINES_MISSING_NO':
                Rec.SetRange("No.", '');
            'PURCHASE_LINES_MISSING_DIMENSIONS':
                begin
                    Rec.SetRange("Shortcut Dimension 1 Code", '');
                    Rec.SetRange("Shortcut Dimension 2 Code", '');
                end;
            'PURCHASE_LINES_WITH_BLOCKED_ITEMS':
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
            ExceptionMgt.MarkItemCorrected(Item, CurrentIssueCode, 'Korrektur aus Einkaufszeilen-Worklist dokumentiert.');
            exit;
        end;

        Message('Korrektur wurde nicht protokolliert, da kein Stammdatensatz zugeordnet werden konnte.');
    end;

}
