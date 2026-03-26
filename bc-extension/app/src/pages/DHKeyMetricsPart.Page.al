page 53127 "DH Key Metrics Part"
{
    PageType = CardPart;
    SourceTable = "DH Scan Header";
    ApplicationArea = All;
    Caption = 'Key Metrics';
    Editable = false;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            cuegroup(KeyMetrics)
            {
                ShowCaption = false;

                field(DataScoreCue; Rec."Data Score")
                {
                    ApplicationArea = All;
                    Caption = 'Data Score';
                    StyleExpr = DataScoreStyle;
                }

                field(TotalRecordsCue; Rec."Total Records")
                {
                    ApplicationArea = All;
                    Caption = 'Datensätze';
                    StyleExpr = RecordsStyle;
                }

                field(PremiumPriceCue; Rec."Est. Premium Price")
                {
                    ApplicationArea = All;
                    Caption = 'Premium / Monat';
                    AutoFormatType = 1;
                    StyleExpr = PremiumPriceStyle;
                }

                field(EstimatedLossCue; Rec."Estimated Loss (EUR)")
                {
                    ApplicationArea = All;
                    Caption = 'Potenzieller Verlust';
                    AutoFormatType = 1;
                    StyleExpr = LossStyle;
                }

                field(ROICue; Rec."ROI")
                {
                    ApplicationArea = All;
                    Caption = 'ROI';
                    AutoFormatType = 1;
                    StyleExpr = ROIStyle;
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        BuildStyles();
    end;

    trigger OnOpenPage()
    begin
        BuildStyles();
    end;

    var
        DataScoreStyle: Text[30];
        RecordsStyle: Text[30];
        PremiumPriceStyle: Text[30];
        LossStyle: Text[30];
        ROIStyle: Text[30];

    local procedure BuildStyles()
    begin
        DataScoreStyle := GetScoreStyle(Rec."Data Score");
        RecordsStyle := 'StrongAccent';
        PremiumPriceStyle := 'Ambiguous';
        LossStyle := 'Unfavorable';
        ROIStyle := GetROIStyle(Rec."ROI");
    end;

    local procedure GetScoreStyle(ScoreValue: Integer): Text
    begin
        if ScoreValue >= 86 then
            exit('Favorable');
        if ScoreValue >= 61 then
            exit('Ambiguous');
        exit('Unfavorable');
    end;

    local procedure GetROIStyle(ROIValue: Decimal): Text
    begin
        if ROIValue > 0 then
            exit('Favorable');
        if ROIValue < 0 then
            exit('Unfavorable');
        exit('Standard');
    end;
}
