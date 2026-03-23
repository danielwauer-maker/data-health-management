page 53122 "DH Score Part"
{
    PageType = CardPart;
    SourceTable = "DH Scan Header";
    ApplicationArea = All;
    Caption = 'Score Health';
    Editable = false;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            group(HealthOverview)
            {
                Caption = 'Health Overview';

                field(QuickScoreText; QuickScoreText)
                {
                    ApplicationArea = All;
                    Caption = 'Quick Score';
                    StyleExpr = QuickScoreStyle;
                }

                field(DeepScoreText; DeepScoreText)
                {
                    ApplicationArea = All;
                    Caption = 'Deep Score';
                    StyleExpr = DeepScoreStyle;
                }

                field(OverallHealthScoreText; OverallHealthScoreText)
                {
                    ApplicationArea = All;
                    Caption = 'Overall Health Score';
                    StyleExpr = OverallHealthScoreStyle;
                }

                field(HealthStatusText; HealthStatusText)
                {
                    ApplicationArea = All;
                    Caption = 'Status';
                    Style = Strong;
                    StyleExpr = true;
                }

                field(BackendRatingText; BackendRatingText)
                {
                    ApplicationArea = All;
                    Caption = 'Backend Rating';
                    StyleExpr = BackendRatingStyle;
                }

                field(TrendText; TrendText)
                {
                    ApplicationArea = All;
                    Caption = 'Trend';
                    StyleExpr = TrendStyle;
                }
            }

            group(Gauge)
            {
                Caption = 'Quick Score Gauge';

                field(GaugeBarRed; GaugeBarText)
                {
                    ApplicationArea = All;
                    Caption = 'Gauge';
                    MultiLine = true;
                    Style = Unfavorable;
                    StyleExpr = ShowRed;
                    Visible = ShowRed;
                }

                field(GaugeBarOrange; GaugeBarText)
                {
                    ApplicationArea = All;
                    Caption = 'Gauge';
                    MultiLine = true;
                    Style = Ambiguous;
                    StyleExpr = ShowOrange;
                    Visible = ShowOrange;
                }

                field(GaugeBarGreen; GaugeBarText)
                {
                    ApplicationArea = All;
                    Caption = 'Gauge';
                    MultiLine = true;
                    Style = Favorable;
                    StyleExpr = ShowGreen;
                    Visible = ShowGreen;
                }

                field(GaugeScaleText; GaugeScaleText)
                {
                    ApplicationArea = All;
                    Caption = 'Scale';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        BuildViewModel();
    end;

    trigger OnOpenPage()
    begin
        BuildViewModel();
    end;

    var
        QuickScoreText: Text[30];
        DeepScoreText: Text[30];
        OverallHealthScoreText: Text[30];
        QuickScoreStyle: Text[30];
        DeepScoreStyle: Text[30];
        OverallHealthScoreStyle: Text[30];
        GaugeBarText: Text[100];
        GaugeScaleText: Text[50];
        HealthStatusText: Text[80];
        BackendRatingText: Text[30];
        BackendRatingStyle: Text[30];
        TrendText: Text[30];
        TrendStyle: Text[30];
        ShowGreen: Boolean;
        ShowOrange: Boolean;
        ShowRed: Boolean;

    local procedure BuildViewModel()
    var
        PreviousHeader: Record "DH Scan Header";
        DeepScanRun: Record "DH Deep Scan Run";
        Setup: Record "DH Setup";
        DeltaValue: Integer;
        OverallScore: Decimal;
        DisplayScore: Integer;
    begin
        ClearViewModel();

        DisplayScore := Rec."Data Score";
        GaugeScaleText := '0 | 60 | 85 | 100';
        BackendRatingText := GetBackendRatingText(Rec."Rating");
        BackendRatingStyle := GetBackendRatingStyle(Rec."Rating");

        case Rec."Scan Type" of
            Rec."Scan Type"::Quick:
                begin
                    QuickScoreText := Format(Rec."Data Score");
                    QuickScoreStyle := GetScoreStyle(Rec."Data Score");

                    DeepScoreText := 'n/a';
                    OverallHealthScoreText := 'n/a';
                    DeepScoreStyle := 'Subordinate';
                    OverallHealthScoreStyle := 'Subordinate';

                    if Setup.Get('SETUP') then
                        if Setup."Premium Enabled" then begin
                            DeepScanRun.Reset();
                            DeepScanRun.SetCurrentKey("Requested At");
                            DeepScanRun.SetRange(Status, DeepScanRun.Status::Completed);

                            if DeepScanRun.FindLast() then begin
                                DeepScoreText := Format(DeepScanRun."Deep Score");
                                DeepScoreStyle := GetScoreStyle(DeepScanRun."Deep Score");

                                OverallScore := Round((Rec."Data Score" * 0.4) + (DeepScanRun."Deep Score" * 0.6), 1, '=');
                                OverallHealthScoreText := Format(OverallScore, 0, '<Integer>');
                                OverallHealthScoreStyle := GetScoreStyle(Round(OverallScore, 1, '='));
                            end;
                        end;
                end;
            Rec."Scan Type"::Deep:
                begin
                    QuickScoreText := 'n/a';
                    QuickScoreStyle := 'Subordinate';
                    DeepScoreText := Format(Rec."Data Score");
                    DeepScoreStyle := GetScoreStyle(Rec."Data Score");
                    OverallHealthScoreText := Format(Rec."Data Score");
                    OverallHealthScoreStyle := GetScoreStyle(Rec."Data Score");
                    HealthStatusText := 'Deep scan snapshot';
                end;
        end;

        GaugeBarText := BuildGaugeBar(DisplayScore);

        if Rec."Scan Type" = Rec."Scan Type"::Quick then begin
            if Rec."Data Score" >= 86 then begin
                ShowGreen := true;
                HealthStatusText := 'Very good';
            end else
                if Rec."Data Score" >= 61 then begin
                    ShowOrange := true;
                    HealthStatusText := 'Okay - improvements recommended';
                end else begin
                    ShowRed := true;
                    HealthStatusText := 'Critical - action needed';
                end;
        end else begin
            if Rec."Data Score" >= 86 then
                ShowGreen := true
            else
                if Rec."Data Score" >= 61 then
                    ShowOrange := true
                else
                    ShowRed := true;
        end;

        PreviousHeader.Reset();
        PreviousHeader.SetCurrentKey("Scan DateTime");
        PreviousHeader.SetFilter("Entry No.", '<>%1', Rec."Entry No.");
        PreviousHeader.SetFilter("Scan DateTime", '<%1', Rec."Scan DateTime");
        PreviousHeader.SetRange("Scan Type", Rec."Scan Type");

        if PreviousHeader.FindLast() then begin
            DeltaValue := Rec."Data Score" - PreviousHeader."Data Score";
            TrendText := GetTrendText(DeltaValue);
            TrendStyle := GetTrendStyle(DeltaValue);
        end else begin
            TrendText := 'First recorded scan';
            TrendStyle := 'Subordinate';
        end;
    end;

    local procedure ClearViewModel()
    begin
        Clear(QuickScoreText);
        Clear(DeepScoreText);
        Clear(OverallHealthScoreText);
        Clear(QuickScoreStyle);
        Clear(DeepScoreStyle);
        Clear(OverallHealthScoreStyle);
        Clear(GaugeBarText);
        Clear(GaugeScaleText);
        Clear(HealthStatusText);
        Clear(BackendRatingText);
        Clear(BackendRatingStyle);
        Clear(TrendText);
        Clear(TrendStyle);
        Clear(ShowGreen);
        Clear(ShowOrange);
        Clear(ShowRed);
    end;

    local procedure BuildGaugeBar(ScoreValue: Integer): Text
    var
        FilledSegments: Integer;
        EmptySegments: Integer;
        i: Integer;
        ResultText: Text;
    begin
        FilledSegments := Round(ScoreValue / 10, 1, '=');

        if FilledSegments < 0 then
            FilledSegments := 0;

        if FilledSegments > 10 then
            FilledSegments := 10;

        EmptySegments := 10 - FilledSegments;

        for i := 1 to FilledSegments do
            ResultText += '■';

        for i := 1 to EmptySegments do
            ResultText += '□';

        exit(ResultText + '  ' + Format(ScoreValue) + '/100');
    end;

    local procedure GetBackendRatingText(RatingValue: Text): Text
    begin
        case LowerCase(RatingValue) of
            'good':
                exit('Good');
            'fair':
                exit('Fair');
            'critical':
                exit('Critical');
        end;

        if RatingValue = '' then
            exit('n/a');

        exit(RatingValue);
    end;

    local procedure GetBackendRatingStyle(RatingValue: Text): Text
    begin
        case LowerCase(RatingValue) of
            'good':
                exit('Favorable');
            'fair':
                exit('Ambiguous');
            'critical':
                exit('Unfavorable');
        end;

        exit('Subordinate');
    end;

    local procedure GetTrendText(DeltaValue: Integer): Text
    begin
        if DeltaValue > 0 then
            exit('Improving');

        if DeltaValue < 0 then
            exit('Declining');

        exit('Stable');
    end;

    local procedure GetTrendStyle(DeltaValue: Integer): Text
    begin
        if DeltaValue > 0 then
            exit('Favorable');

        if DeltaValue < 0 then
            exit('Unfavorable');

        exit('Subordinate');
    end;

    local procedure GetScoreStyle(ScoreValue: Integer): Text
    begin
        if ScoreValue >= 86 then
            exit('Favorable');

        if ScoreValue >= 61 then
            exit('Ambiguous');

        if ScoreValue >= 0 then
            exit('Unfavorable');

        exit('Subordinate');
    end;
}