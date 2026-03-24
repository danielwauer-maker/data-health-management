page 53121 "DH Issues Part"
{
    PageType = ListPart;
    SourceTable = "DH Dashboard Issue";
    ApplicationArea = All;
    Caption = 'Issues';
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    UsageCategory = None;

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

                field(Severity; Rec.Severity)
                {
                    ApplicationArea = All;
                    StyleExpr = SeverityStyle;
                }

                field("Affected Count"; Rec."Affected Count")
                {
                    ApplicationArea = All;

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
                    Caption = 'Impact €';
                }

                field("Recommendation Preview"; Rec."Recommendation Preview")
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
            action(OpenAllIssues)
            {
                Caption = 'Show All Issues';
                ApplicationArea = All;
                Image = List;

                trigger OnAction()
                var
                    DashboardIssue: Record "DH Dashboard Issue";
                begin
                    DashboardIssue.SetRange("Dashboard Scan Entry No.", Rec."Dashboard Scan Entry No.");
                    Page.Run(Page::"DH Dashboard Issues", DashboardIssue);
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        SeverityStyle := GetSeverityStyle();
    end;

    trigger OnOpenPage()
    begin
        EnsureSortFields();
        Rec.SetCurrentKey("Dashboard Scan Entry No.", "Severity Sort Order", "Affected Count Sort Value");
        Rec.Ascending(true);
    end;

    var
        SeverityStyle: Text[30];

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
}
