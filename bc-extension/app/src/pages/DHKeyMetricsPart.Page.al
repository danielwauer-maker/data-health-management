page 53127 "DH Key Metrics Part"
{
    PageType = CardPart;
    SourceTable = "DH Scan Header";
    ApplicationArea = All;
    Caption = 'Key Metrics';
    Editable = false;

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
                    Caption = 'Score';
                    StyleExpr = DataScoreStyle;
                }

                field(DeltaCue; DeltaValue)
                {
                    ApplicationArea = All;
                    Caption = 'Delta';
                    StyleExpr = DeltaStyle;
                }

                field(ChecksCue; Rec."Checks Count")
                {
                    ApplicationArea = All;
                    Caption = 'Checks';
                    StyleExpr = ChecksStyle;
                }

                field(IssuesCue; Rec."Issues Count")
                {
                    ApplicationArea = All;
                    Caption = 'Issues';
                    StyleExpr = IssuesStyle;

                    trigger OnDrillDown()
                    var
                        ScanIssue: Record "DH Scan Issue";
                        DeepScanRun: Record "DH Deep Scan Run";
                        DeepFinding: Record "DH Deep Scan Finding";
                    begin
                        case Rec."Scan Type" of
                            Rec."Scan Type"::Quick:
                                begin
                                    ScanIssue.SetRange("Scan Entry No.", Rec."Entry No.");
                                    Page.Run(Page::"DH Scan Issues", ScanIssue);
                                end;
                            Rec."Scan Type"::Deep:
                                begin
                                    DeepScanRun.SetRange("Run ID", Rec."Backend Scan Id");
                                    DeepScanRun.SetRange(Status, DeepScanRun.Status::Completed);

                                    if not DeepScanRun.FindFirst() then
                                        Error('No completed deep scan run is linked to this dashboard.');

                                    DeepFinding.SetRange("Deep Scan Entry No.", DeepScanRun."Entry No.");
                                    Page.Run(Page::"DH Deep Scan Findings", DeepFinding);
                                end;
                        end;
                    end;
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
        DeltaValue: Integer;
        DataScoreStyle: Text[30];
        DeltaStyle: Text[30];
        ChecksStyle: Text[30];
        IssuesStyle: Text[30];

    local procedure BuildStyles()
    var
        PreviousHeader: Record "DH Scan Header";
    begin
        DeltaValue := 0;

        PreviousHeader.Reset();
        PreviousHeader.SetCurrentKey("Scan DateTime");
        PreviousHeader.SetFilter("Entry No.", '<>%1', Rec."Entry No.");
        PreviousHeader.SetFilter("Scan DateTime", '<%1', Rec."Scan DateTime");
        PreviousHeader.SetRange("Scan Type", Rec."Scan Type");

        if PreviousHeader.FindLast() then
            DeltaValue := Rec."Data Score" - PreviousHeader."Data Score";

        DataScoreStyle := GetScoreStyle(Rec."Data Score");
        DeltaStyle := GetDeltaStyle(DeltaValue);
        ChecksStyle := 'StrongAccent';
        IssuesStyle := GetIssuesStyle(Rec."Issues Count");
    end;

    local procedure GetScoreStyle(ScoreValue: Integer): Text
    begin
        if ScoreValue >= 86 then
            exit('Favorable');

        if ScoreValue >= 61 then
            exit('Ambiguous');

        exit('Unfavorable');
    end;

    local procedure GetDeltaStyle(Delta: Integer): Text
    begin
        if Delta > 0 then
            exit('Favorable');

        if Delta < 0 then
            exit('Unfavorable');

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