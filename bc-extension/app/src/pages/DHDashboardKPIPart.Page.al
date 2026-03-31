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

                field("Affected Records"; Rec."Affected Records")
                {
                    ApplicationArea = All;
                    Caption = 'Affected';
                    StyleExpr = IssuesStyle;
                    ToolTip = 'Summe aller betroffenen Datensätze über alle Findings.';
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

        if Rec."Data Score" >= 1 then
            exit('Unfavorable');

        exit('Unfavorable');
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
        if (Rec."Issues Count" > 0) or (Rec."Affected Records" > 0) then
            exit('Attention');

        exit('Standard');
    end;


    procedure SetScanHeaderEntryNo(ScanHeaderEntryNo: Integer)
    begin
        if ScanHeaderEntryNo <= 0 then begin
            Rec.Reset();
            Rec.SetRange("Entry No.", -1);
            if Rec.FindFirst() then;
            CurrPage.Update(false);
            exit;
        end;

        Rec.Reset();
        Rec.SetRange("Entry No.", ScanHeaderEntryNo);
        if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;
}