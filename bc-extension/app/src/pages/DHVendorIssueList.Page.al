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
                field("Purchaser Code"; Rec."Purchaser Code") { ApplicationArea = All; }
                field(Contact; Rec.Contact) { ApplicationArea = All; }
                field("Home Page"; Rec."Home Page") { ApplicationArea = All; }
                field("VAT Registration No."; Rec."VAT Registration No.") { ApplicationArea = All; }
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
        if CurrentIssueCode = '' then
            CurrentIssueCode := InferIssueCodeFromFilters();
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
            'VENDORS_MISSING_GEN_BUS_POSTING',
            'SYSTEM_VENDORS_MISSING_GEN_BUS_POSTING':
                Rec.SetRange("Gen. Bus. Posting Group", '');
            'VENDORS_MISSING_VAT_BUS_POSTING',
            'SYSTEM_VENDORS_MISSING_VAT_BUS_POSTING':
                Rec.SetRange("VAT Bus. Posting Group", '');
            'VENDORS_MISSING_BANK_ACCOUNT':
                Rec.SetRange("Preferred Bank Account Code", '');
            'VENDORS_MISSING_VAT_REG_NO':
                Rec.SetRange("VAT Registration No.", '');
            'VENDORS_MISSING_PURCHASER':
                Rec.SetRange("Purchaser Code", '');
            'VENDORS_MISSING_CONTACT':
                Rec.SetRange(Contact, '');
            'VENDORS_MISSING_HOME_PAGE':
                Rec.SetRange("Home Page", '');
        end;
    end;

    local procedure InferIssueCodeFromFilters(): Code[50]
    begin
        if Rec.GetFilter(Name) <> '' then
            exit('VENDORS_MISSING_NAME');
        if Rec.GetFilter("Search Name") <> '' then
            exit('VENDORS_MISSING_SEARCH_NAME');
        if Rec.GetFilter(Address) <> '' then
            exit('VENDORS_MISSING_ADDRESS');
        if Rec.GetFilter(City) <> '' then
            exit('VENDORS_MISSING_CITY');
        if Rec.GetFilter("Post Code") <> '' then
            exit('VENDORS_MISSING_POST_CODE');
        if Rec.GetFilter("Country/Region Code") <> '' then
            exit('VENDORS_MISSING_COUNTRY');
        if Rec.GetFilter("E-Mail") <> '' then
            exit('VENDORS_MISSING_EMAIL');
        if Rec.GetFilter("Phone No.") <> '' then
            exit('VENDORS_MISSING_PHONE');
        if Rec.GetFilter("Payment Terms Code") <> '' then
            exit('VENDORS_MISSING_PAYMENT_TERMS');
        if Rec.GetFilter("Payment Method Code") <> '' then
            exit('VENDORS_MISSING_PAYMENT_METHOD');
        if Rec.GetFilter("Vendor Posting Group") <> '' then
            exit('VENDORS_MISSING_POSTING_GROUP');
        if Rec.GetFilter("Gen. Bus. Posting Group") <> '' then
            exit('VENDORS_MISSING_GEN_BUS_POSTING');
        if Rec.GetFilter("VAT Bus. Posting Group") <> '' then
            exit('VENDORS_MISSING_VAT_BUS_POSTING');
        if Rec.GetFilter("VAT Registration No.") <> '' then
            exit('VENDORS_MISSING_VAT_REG_NO');
        if Rec.GetFilter("Purchaser Code") <> '' then
            exit('VENDORS_MISSING_PURCHASER');
        if Rec.GetFilter(Contact) <> '' then
            exit('VENDORS_MISSING_CONTACT');
        if Rec.GetFilter("Home Page") <> '' then
            exit('VENDORS_MISSING_HOME_PAGE');
        if Rec.GetFilter("Preferred Bank Account Code") <> '' then
            exit('VENDORS_MISSING_BANK_ACCOUNT');

        exit('');
    end;
}
