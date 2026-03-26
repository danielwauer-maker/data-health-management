page 53142 "DH Dashboard KPI Part"
{
    PageType = CardPart;
    SourceTable = "DH Scan Header";
    ApplicationArea = All;
    Caption = 'Key Metrics';
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            cuegroup(KPIs)
            {
                ShowCaption = false;

                field("Data Score"; Rec."Data Score")
                {
                    ApplicationArea = All;
                    Caption = 'Data Score';
                    StyleExpr = DataScoreStyle;
                    ToolTip = 'Bewertung der Datenqualität.';
                }

                /*field("Estimated Loss"; Rec."Estimated Loss (EUR)")
                {
                    ApplicationArea = All;
                    Caption = 'Potenzieller Verlust';
                    StyleExpr = EstimatedLossStyle;
                    ToolTip = 'Geschätzter potenzieller Verlust durch schlechte Datenqualität.';
                }*/

                field("Checks Count"; Rec."Checks Count")
                {
                    ApplicationArea = All;
                    Caption = 'Checks';
                    StyleExpr = ChecksStyle;
                    ToolTip = 'Anzahl ausgeführter Prüfungen.';
                }

                field("Issues Count"; Rec."Issues Count")
                {
                    ApplicationArea = All;
                    Caption = 'Issues';
                    StyleExpr = IssuesStyle;
                    ToolTip = 'Anzahl gefundener Probleme.';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        UpdateStyles();
    end;

    trigger OnOpenPage()
    begin
        UpdateStyles();
    end;

    var
        DataScoreStyle: Text[30];
        EstimatedLossStyle: Text[30];
        ChecksStyle: Text[30];
        IssuesStyle: Text[30];

    local procedure UpdateStyles()
    begin
        DataScoreStyle := GetDataScoreStyle();
        EstimatedLossStyle := GetEstimatedLossStyle();
        ChecksStyle := GetChecksStyle();
        IssuesStyle := GetIssuesStyle();
    end;

    local procedure GetDataScoreStyle(): Text[30]
    begin
        if Rec."Data Score" >= 86 then
            exit('Favorable');

        if Rec."Data Score" >= 61 then
            exit('Ambiguous');

        if Rec."Data Score" > 0 then
            exit('Unfavorable');

        exit('Standard');
    end;

    local procedure GetEstimatedLossStyle(): Text[30]
    begin
        if Rec."Estimated Loss (EUR)" > 0 then
            exit('Unfavorable');

        exit('Standard');
    end;

    local procedure GetChecksStyle(): Text[30]
    begin
        if Rec."Checks Count" > 0 then
            exit('Strong');

        exit('Standard');
    end;

    local procedure GetIssuesStyle(): Text[30]
    begin
        if Rec."Issues Count" > 0 then
            exit('Attention');

        exit('Standard');
    end;
}