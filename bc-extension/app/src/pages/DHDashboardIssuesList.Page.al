page 53161 "DH Dashboard Issues List"
{
    PageType = List;
    SourceTable = "DH Dashboard Issue";
    ApplicationArea = All;
    UsageCategory = Lists;
    Caption = 'BCSentinel Issues';
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Issues)
            {
                field(Severity; Rec.Severity)
                {
                    ApplicationArea = All;
                    StyleExpr = SeverityStyle;
                }

                field(Title; Rec.Title)
                {
                    ApplicationArea = All;

                    trigger OnDrillDown()
                    var
                        IssueDrilldownMgt: Codeunit "DH Issue Drilldown Mgt.";
                    begin
                        IssueDrilldownMgt.OpenDashboardIssue(Rec);
                    end;
                }

                field("Affected Count"; Rec."Affected Count")
                {
                    ApplicationArea = All;
                    Caption = 'Count';

                    trigger OnDrillDown()
                    var
                        IssueDrilldownMgt: Codeunit "DH Issue Drilldown Mgt.";
                    begin
                        IssueDrilldownMgt.OpenDashboardIssue(Rec);
                    end;
                }

                field("Estimated Impact (EUR)"; Rec."Estimated Impact (EUR)")
                {
                    ApplicationArea = All;
                    Caption = 'Impact â‚¬';
                }

                field("Recommendation Review"; Rec."Recommendation Preview")
                {
                    ApplicationArea = All;
                    Caption = 'Recommendation';
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
        Rec.SetCurrentKey("Dashboard Scan Entry No.", "Severity Sort Order", "Affected Count Sort Value");
        Rec.Ascending(true);
    end;

    var
        SeverityStyle: Text[30];
        ShowPremiumDetails: Boolean;
        AccessText: Text[80];

    local procedure EnsureSortFields()
    var
        Issue: Record "DH Dashboard Issue";
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
        AccessText := 'Upgrade to Premium for detailed insights';

        if Setup.Get('SETUP') then
            if Setup."Premium Enabled" then begin
                ShowPremiumDetails := true;
                AccessText := 'Unlocked';
            end;
    end;
}
