page 53156 "DH Customer Issue List"
{
    PageType = List;
    SourceTable = Customer;
    ApplicationArea = All;
    UsageCategory = None;
    Caption = 'DH Customer Issue List';
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("No."; Rec."No.") { ApplicationArea = All; }
                field(Name; Rec.Name) { ApplicationArea = All; }
                field(Address; Rec.Address) { ApplicationArea = All; }
                field(City; Rec.City) { ApplicationArea = All; }
                field("Post Code"; Rec."Post Code") { ApplicationArea = All; }
                field("Country/Region Code"; Rec."Country/Region Code") { ApplicationArea = All; }
                field("E-Mail"; Rec."E-Mail") { ApplicationArea = All; }
                field("Phone No."; Rec."Phone No.") { ApplicationArea = All; }
                field("Payment Terms Code"; Rec."Payment Terms Code") { ApplicationArea = All; }
                field("Payment Method Code"; Rec."Payment Method Code") { ApplicationArea = All; }
                field("Credit Limit (LCY)"; Rec."Credit Limit (LCY)") { ApplicationArea = All; }
                field(Blocked; Rec.Blocked) { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(OpenCustomerCard)
            {
                Caption = 'Daten korrigieren';
                ApplicationArea = All;
                Image = EditLines;
                trigger OnAction()
                begin
                    Page.Run(Page::"Customer Card", Rec);
                end;
            }
            action(ExcludeFromIssue)
            {
                Caption = 'Von Analyse ausnehmen';
                ApplicationArea = All;
                Image = Cancel;
                trigger OnAction()
                var
                    ExceptionMgt: Codeunit "DH Exception Mgt.";
                begin
                    if CurrentIssueCode = '' then
                        exit;
                    ExceptionMgt.AddCustomerException(Rec, CurrentIssueCode, StrSubstNo('Manuell aus %1 ausgenommen.', CurrentIssueCode));
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
                    if CurrentIssueCode = '' then
                        exit;
                    ExceptionMgt.MarkCustomerCorrected(Rec, CurrentIssueCode, 'Datensatz manuell als korrigiert markiert.');
                    CurrPage.Update(false);
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
        case CurrentIssueCode of
            'CUSTOMERS_MISSING_NAME':
                Rec.SetRange(Name, '');
            'CUSTOMERS_MISSING_SEARCH_NAME':
                Rec.SetRange("Search Name", '');
            'CUSTOMERS_MISSING_ADDRESS':
                Rec.SetRange(Address, '');
            'CUSTOMERS_MISSING_CITY':
                Rec.SetRange(City, '');
            'CUSTOMERS_MISSING_POST_CODE':
                Rec.SetRange("Post Code", '');
            'CUSTOMERS_MISSING_COUNTRY':
                Rec.SetRange("Country/Region Code", '');
            'CUSTOMERS_MISSING_EMAIL':
                Rec.SetRange("E-Mail", '');
            'CUSTOMERS_MISSING_PHONE':
                Rec.SetRange("Phone No.", '');
            'CUSTOMERS_MISSING_PAYMENT_TERMS':
                Rec.SetRange("Payment Terms Code", '');
            'CUSTOMERS_MISSING_PAYMENT_METHOD':
                Rec.SetRange("Payment Method Code", '');
            'CUSTOMERS_MISSING_POSTING_GROUP':
                Rec.SetRange("Customer Posting Group", '');
            'CUSTOMERS_MISSING_GEN_BUS_POSTING':
                Rec.SetRange("Gen. Bus. Posting Group", '');
            'CUSTOMERS_MISSING_VAT_BUS_POSTING':
                Rec.SetRange("VAT Bus. Posting Group", '');
            'CUSTOMERS_MISSING_CREDIT_LIMIT':
                Rec.SetRange("Credit Limit (LCY)", 0);
        end;
    end;
}
