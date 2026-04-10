page 53131 "DH Deep Scan Findings"
{
    PageType = ListPart;
    SourceTable = "DH Deep Scan Finding";
    ApplicationArea = All;
    UsageCategory = None;
    Caption = 'Deep Scan Findings';
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Findings)
            {
                field(Category; Rec.Category)
                {
                    ApplicationArea = All;
                }

                field("Issue Code"; Rec."Issue Code")
                {
                    ApplicationArea = All;
                    Visible = ShowPremiumDetails;
                }

                field(Title; Rec.Title)
                {
                    ApplicationArea = All;
                }

                field(Severity; Rec.Severity)
                {
                    ApplicationArea = All;
                    StyleExpr = SeverityStyle;
                }

                field("Affected Count"; Rec."Affected Count")
                {
                    ApplicationArea = All;
                }

                field("Estimated Impact (EUR)"; Rec."Estimated Impact (EUR)")
                {
                    ApplicationArea = All;
                    Caption = 'Impact €';
                }

                field("Recommendation Preview"; Rec."Recommendation Preview")
                {
                    ApplicationArea = All;
                    Visible = ShowPremiumDetails;
                }

                field(Access; AccessText)
                {
                    ApplicationArea = All;
                    Caption = 'Access';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        UpdateAccessState();
        SeverityStyle := GetSeverityStyle();
    end;

    trigger OnOpenPage()
    begin
        EnsureSortFields();
        UpdateAccessState();
        Rec.SetCurrentKey("Deep Scan Entry No.", "Severity Sort Order", "Affected Count Sort Value");
        Rec.Ascending(true);
    end;

    var
        SeverityStyle: Text[30];
        ShowPremiumDetails: Boolean;
        AccessText: Text[80];

    local procedure EnsureSortFields()
    var
        Issue: Record "DH Deep Scan Finding";
        NeedsUpdate: Boolean;
    begin
        Issue.CopyFilters(Rec);
        if Issue.FindSet() then
            repeat
                NeedsUpdate := false;

                if Issue."Severity Sort Order" <> GetSeveritySortOrder(Issue.Severity) then begin
                    Issue."Severity Sort Order" := GetSeveritySortOrder(Issue.Severity);
                    NeedsUpdate := true;
                end;

                if Issue."Affected Count Sort Value" <> -Issue."Affected Count" then begin
                    Issue."Affected Count Sort Value" := -Issue."Affected Count";
                    NeedsUpdate := true;
                end;

                if NeedsUpdate then
                    Issue.Modify(true);
            until Issue.Next() = 0;
    end;

    local procedure GetSeveritySortOrder(SeverityValue: Code[20]): Integer
    begin
        case LowerCase(SeverityValue) of
            'high':
                exit(1);
            'medium':
                exit(2);
            'low':
                exit(3);
        end;

        exit(99);
    end;

    local procedure GetSeverityStyle(): Text
    begin
        case LowerCase(Rec.Severity) of
            'high':
                exit('Unfavorable');
            'medium':
                exit('Ambiguous');
            'low':
                exit('Favorable');
        end;

        exit('Standard');
    end;

    local procedure UpdateAccessState()
    var
        Setup: Record "DH Setup";
    begin
        ShowPremiumDetails := false;
        AccessText := 'Upgrade to Premium';

        if Setup.Get('SETUP') then
            if Setup."Premium Enabled" then begin
                ShowPremiumDetails := true;
                AccessText := 'Unlocked';
            end;
    end;


    procedure SetDeepScanEntryNo(DeepScanEntryNo: Integer)
    begin
        Rec.Reset();
        Rec.SetRange("Deep Scan Entry No.", DeepScanEntryNo);
        EnsureSortFields();
        Rec.SetCurrentKey("Deep Scan Entry No.", "Severity Sort Order", "Affected Count Sort Value");
        Rec.Ascending(true);
        CurrPage.Update(false);
    end;
}
