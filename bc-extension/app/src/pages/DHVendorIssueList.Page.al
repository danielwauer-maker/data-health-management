page 53157 "DH Vendor Issue List"
{
    PageType = List;
    SourceTable = Vendor;
    ApplicationArea = All;
    UsageCategory = None;
    Caption = 'DH Vendor Issue List';
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
                field("Preferred Bank Account Code"; Rec."Preferred Bank Account Code") { ApplicationArea = All; }
                field(Blocked; Rec.Blocked) { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(OpenVendorCard)
            {
                Caption = 'Daten korrigieren';
                ApplicationArea = All;
                Image = EditLines;
                trigger OnAction()
                begin
                    Page.Run(Page::"Vendor Card", Rec);
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
                    ExceptionMgt.AddVendorException(Rec, CurrentIssueCode, StrSubstNo('Manuell aus %1 ausgenommen.', CurrentIssueCode));
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
                    ExceptionMgt.MarkVendorCorrected(Rec, CurrentIssueCode, 'Datensatz manuell als korrigiert markiert.');
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
            'VENDORS_MISSING_NAME':
                Rec.SetRange(Name, '');
            'VENDORS_MISSING_SEARCH_NAME':
                Rec.SetRange("Search Name", '');
            'VENDORS_MISSING_ADDRESS':
                Rec.SetRange(Address, '');
            'VENDORS_MISSING_CITY':
                Rec.SetRange(City, '');
            'VENDORS_MISSING_POST_CODE':
                Rec.SetRange("Post Code", '');
            'VENDORS_MISSING_COUNTRY':
                Rec.SetRange("Country/Region Code", '');
            'VENDORS_MISSING_EMAIL':
                Rec.SetRange("E-Mail", '');
            'VENDORS_MISSING_PHONE':
                Rec.SetRange("Phone No.", '');
            'VENDORS_MISSING_PAYMENT_TERMS':
                Rec.SetRange("Payment Terms Code", '');
            'VENDORS_MISSING_PAYMENT_METHOD':
                Rec.SetRange("Payment Method Code", '');
            'VENDORS_MISSING_POSTING_GROUP':
                Rec.SetRange("Vendor Posting Group", '');
            'VENDORS_MISSING_GEN_BUS_POSTING':
                Rec.SetRange("Gen. Bus. Posting Group", '');
            'VENDORS_MISSING_VAT_BUS_POSTING':
                Rec.SetRange("VAT Bus. Posting Group", '');
            'VENDORS_MISSING_BANK_ACCOUNT':
                Rec.SetRange("Preferred Bank Account Code", '');
        end;
    end;
}
