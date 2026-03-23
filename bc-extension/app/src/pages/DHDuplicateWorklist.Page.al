page 53145 "DH Duplicate Worklist"
{
    PageType = List;
    SourceTable = "DH Duplicate Buffer";
    SourceTableTemporary = true;
    ApplicationArea = All;
    UsageCategory = None;
    Caption = 'DH Duplicate Worklist';
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Source Type"; Rec."Source Type")
                {
                    ApplicationArea = All;
                }
                field(Reason; Rec.Reason)
                {
                    ApplicationArea = All;
                }
                field("Duplicate Count"; Rec."Duplicate Count")
                {
                    ApplicationArea = All;
                }
                field("Source No."; Rec."Source No.")
                {
                    ApplicationArea = All;
                }
                field(Name; Rec.Name)
                {
                    ApplicationArea = All;
                }
                field("Post Code"; Rec."Post Code")
                {
                    ApplicationArea = All;
                }
                field(City; Rec.City)
                {
                    ApplicationArea = All;
                }
                field("E-Mail"; Rec."E-Mail")
                {
                    ApplicationArea = All;
                }
                field("VAT Registration No."; Rec."VAT Registration No.")
                {
                    ApplicationArea = All;
                }
                field("Group Key"; Rec."Group Key")
                {
                    ApplicationArea = All;
                    Visible = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(OpenMasterData)
            {
                Caption = 'Daten korrigieren';
                ApplicationArea = All;
                Image = EditLines;

                trigger OnAction()
                var
                    Customer: Record Customer;
                    Vendor: Record Vendor;
                begin
                    case Rec."Source Type" of
                        Rec."Source Type"::Customer:
                            if Customer.Get(Rec."Source No.") then
                                Page.Run(Page::"Customer Card", Customer);
                        Rec."Source Type"::Vendor:
                            if Vendor.Get(Rec."Source No.") then
                                Page.Run(Page::"Vendor Card", Vendor);
                    end;
                end;
            }
        }
    }

    trigger OnOpenPage()
    var
        DuplicateWorklistMgt: Codeunit "DH Duplicate Worklist Mgt.";
    begin
        DuplicateWorklistMgt.BuildWorklist(Rec);
    end;
}
