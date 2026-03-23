page 53125 "DH Score Trend Chart"
{
    PageType = CardPart;
    SourceTable = "DH Scan Header";
    ApplicationArea = All;
    Caption = 'Score Trend';
    Editable = false;

    layout
    {
        area(Content)
        {
            usercontrol(ScoreTrendChart; BusinessChart)
            {
                ApplicationArea = All;

                trigger AddInReady()
                begin
                    ChartReady := true;
                    RenderChart();
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        ChartReady := false;
    end;

    trigger OnAfterGetCurrRecord()
    begin
        RenderChart();
    end;

    var
        BusinessChartMgt: Codeunit "Business Chart";
        ChartReady: Boolean;

    local procedure RenderChart()
    var
        ScanHeader: Record "DH Scan Header";
        RowIndex: Integer;
        ScoreValue: Decimal;
    begin
        if not ChartReady then
            exit;

        BusinessChartMgt.Initialize();
        BusinessChartMgt.SetXDimension('Scan', Enum::"Business Chart Data Type"::String);
        BusinessChartMgt.SetShowChartCondensed(true);

        BusinessChartMgt.AddMeasure(
            'Critical (0-60)',
            0,
            Enum::"Business Chart Data Type"::Decimal,
            Enum::"Business Chart Type"::Line);

        BusinessChartMgt.AddMeasure(
            'Warning (61-85)',
            1,
            Enum::"Business Chart Data Type"::Decimal,
            Enum::"Business Chart Type"::Line);

        BusinessChartMgt.AddMeasure(
            'Healthy (86+)',
            2,
            Enum::"Business Chart Data Type"::Decimal,
            Enum::"Business Chart Type"::Line);

        ScanHeader.Reset();
        ScanHeader.SetCurrentKey("Scan DateTime");

        if ScanHeader.FindSet() then begin
            RowIndex := 0;

            repeat
                BusinessChartMgt.AddDataRowWithXDimension(GetScanCaption(ScanHeader));
                ScoreValue := ScanHeader."Data Score";

                if ScoreValue <= 60 then
                    BusinessChartMgt.SetValue('Critical (0-60)', RowIndex, ScoreValue);

                if (ScoreValue >= 61) and (ScoreValue <= 85) then
                    BusinessChartMgt.SetValue('Warning (61-85)', RowIndex, ScoreValue);

                if ScoreValue >= 86 then
                    BusinessChartMgt.SetValue('Healthy (86+)', RowIndex, ScoreValue);

                RowIndex += 1;
            until ScanHeader.Next() = 0;
        end else begin
            BusinessChartMgt.AddDataRowWithXDimension('No scans yet');
            BusinessChartMgt.SetValue('Critical (0-60)', 0, 0);
        end;

        BusinessChartMgt.Update(CurrPage.ScoreTrendChart);
    end;

    local procedure GetScanCaption(var ScanHeader: Record "DH Scan Header"): Text
    begin
        exit(Format(ScanHeader."Scan DateTime"));
    end;
}