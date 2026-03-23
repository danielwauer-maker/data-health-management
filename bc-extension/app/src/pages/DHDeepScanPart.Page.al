page 53132 "DH Deep Scan Part"
{
    PageType = CardPart;
    SourceTable = "DH Setup";
    ApplicationArea = All;
    Caption = 'Deep Scan';
    Editable = false;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            group(DeepScanOverview)
            {
                Caption = 'Latest Deep Scan';

                field(LatestRunStatus; LatestRunStatus)
                {
                    ApplicationArea = All;
                    Caption = 'Status';
                    StyleExpr = StatusStyle;
                }

                field(LatestDeepScore; LatestDeepScore)
                {
                    ApplicationArea = All;
                    Caption = 'Deep Score';
                    StyleExpr = ScoreStyle;
                }

                field(LatestRating; LatestRating)
                {
                    ApplicationArea = All;
                    Caption = 'Rating';
                    StyleExpr = RatingStyle;
                }

                field(LatestChecksCount; LatestChecksCount)
                {
                    ApplicationArea = All;
                    Caption = 'Checks';
                }

                field(LatestIssuesCount; LatestIssuesCount)
                {
                    ApplicationArea = All;
                    Caption = 'Issues';
                    StyleExpr = IssuesStyle;
                }

                field(LatestRequestedAt; LatestRequestedAt)
                {
                    ApplicationArea = All;
                    Caption = 'Requested At';
                }

                field(LatestFinishedAt; LatestFinishedAt)
                {
                    ApplicationArea = All;
                    Caption = 'Finished At';
                }

                field(LatestHeadline; LatestHeadline)
                {
                    ApplicationArea = All;
                    Caption = 'Headline';
                    MultiLine = true;
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        LoadLatestDeepScan();
    end;

    trigger OnAfterGetRecord()
    begin
        LoadLatestDeepScan();
    end;

    var
        LatestRunStatus: Text[30];
        LatestDeepScore: Integer;
        LatestRating: Text[30];
        LatestChecksCount: Integer;
        LatestIssuesCount: Integer;
        LatestRequestedAt: DateTime;
        LatestFinishedAt: DateTime;
        LatestHeadline: Text[250];
        StatusStyle: Text[30];
        ScoreStyle: Text[30];
        RatingStyle: Text[30];
        IssuesStyle: Text[30];

    local procedure LoadLatestDeepScan()
    var
        DeepScanRun: Record "DH Deep Scan Run";
    begin
        ClearViewModel();

        DeepScanRun.Reset();
        DeepScanRun.SetCurrentKey("Requested At");
        if not DeepScanRun.FindLast() then begin
            LatestRunStatus := 'No deep scan yet';
            LatestHeadline := 'No deep scan has been requested yet.';
            StatusStyle := 'Subordinate';
            exit;
        end;

        LatestRunStatus := Format(DeepScanRun.Status);
        LatestDeepScore := DeepScanRun."Deep Score";
        LatestRating := DeepScanRun."Rating";
        LatestChecksCount := DeepScanRun."Checks Count";
        LatestIssuesCount := DeepScanRun."Issues Count";
        LatestRequestedAt := DeepScanRun."Requested At";
        LatestFinishedAt := DeepScanRun."Finished At";
        LatestHeadline := DeepScanRun."Headline";

        StatusStyle := GetStatusStyle(DeepScanRun);
        ScoreStyle := GetScoreStyle(DeepScanRun."Deep Score");
        RatingStyle := GetRatingStyle(DeepScanRun."Rating");
        IssuesStyle := GetIssuesStyle(DeepScanRun."Issues Count");
    end;

    local procedure ClearViewModel()
    begin
        Clear(LatestRunStatus);
        Clear(LatestDeepScore);
        Clear(LatestRating);
        Clear(LatestChecksCount);
        Clear(LatestIssuesCount);
        Clear(LatestRequestedAt);
        Clear(LatestFinishedAt);
        Clear(LatestHeadline);
        Clear(StatusStyle);
        Clear(ScoreStyle);
        Clear(RatingStyle);
        Clear(IssuesStyle);
    end;

    local procedure GetStatusStyle(var DeepScanRun: Record "DH Deep Scan Run"): Text
    begin
        case DeepScanRun.Status of
            DeepScanRun.Status::Queued:
                exit('Ambiguous');
            DeepScanRun.Status::Running:
                exit('StrongAccent');
            DeepScanRun.Status::Completed:
                exit('Favorable');
            DeepScanRun.Status::Failed:
                exit('Unfavorable');
            DeepScanRun.Status::Canceled:
                exit('Subordinate');
        end;

        exit('Standard');
    end;

    local procedure GetScoreStyle(DeepScore: Integer): Text
    begin
        if DeepScore >= 86 then
            exit('Favorable');

        if DeepScore >= 61 then
            exit('Ambiguous');

        if DeepScore > 0 then
            exit('Unfavorable');

        exit('Standard');
    end;

    local procedure GetRatingStyle(RatingValue: Text): Text
    begin
        case LowerCase(RatingValue) of
            'good':
                exit('Favorable');
            'fair':
                exit('Ambiguous');
            'critical':
                exit('Unfavorable');
        end;

        exit('Standard');
    end;

    local procedure GetIssuesStyle(IssuesCount: Integer): Text
    begin
        if IssuesCount = 0 then
            exit('Favorable');

        if IssuesCount <= 5 then
            exit('Ambiguous');

        exit('Unfavorable');
    end;
}