page 53130 "DH Deep Scan Runs"
{
    PageType = List;
    SourceTable = "DH Deep Scan Run";
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'BCSentinel Scan History';
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = true;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Runs)
            {
                field("Run ID"; Rec."Run ID")
                {
                    ApplicationArea = All;
                }

                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    StyleExpr = StatusStyle;
                }

                field("Requested At"; Rec."Requested At")
                {
                    ApplicationArea = All;
                }

                field("Started At"; Rec."Started At")
                {
                    ApplicationArea = All;
                }

                field("Finished At"; Rec."Finished At")
                {
                    ApplicationArea = All;
                }

                field("Deep Score"; Rec."Deep Score")
                {
                    ApplicationArea = All;
                    StyleExpr = ScoreStyle;
                }

                field("Checks Count"; Rec."Checks Count")
                {
                    ApplicationArea = All;
                }

                field("Issues Count"; Rec."Issues Count")
                {
                    ApplicationArea = All;
                }

                field("Rating"; Rec."Rating")
                {
                    ApplicationArea = All;
                }

                field("Headline"; Rec."Headline")
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
            action(OpenFindings)
            {
                Caption = 'Open Findings';
                ApplicationArea = All;
                Image = List;

                trigger OnAction()
                var
                    Finding: Record "DH Deep Scan Finding";
                begin
                    Finding.SetRange("Deep Scan Entry No.", Rec."Entry No.");
                    Page.Run(Page::"DH Deep Scan Findings", Finding);
                end;
            }

            action(DeleteSelectedRun)
            {
                Caption = 'Delete Selected Run';
                ApplicationArea = All;
                Image = Delete;

                trigger OnAction()
                begin
                    if Rec."Entry No." = 0 then
                        Error('Please select a deep scan run first.');

                    if Confirm(
                        'Do you want to delete deep scan run %1?',
                        false,
                        Rec."Run ID")
                    then begin
                        Rec.Delete(true);
                        CurrPage.Update(false);
                    end;
                end;
            }

            action(Refresh)
            {
                Caption = 'Refresh';
                ApplicationArea = All;
                Image = Refresh;

                trigger OnAction()
                begin
                    CurrPage.Update(false);
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.SetCurrentKey("Requested At");
        Rec.Ascending(false);
    end;

    trigger OnAfterGetRecord()
    begin
        StatusStyle := GetStatusStyle();
        ScoreStyle := GetScoreStyle();
    end;

    var
        StatusStyle: Text[30];
        ScoreStyle: Text[30];

    local procedure GetStatusStyle(): Text
    begin
        case Rec.Status of
            Rec.Status::Queued:
                exit('Ambiguous');
            Rec.Status::Running:
                exit('StrongAccent');
            Rec.Status::Completed:
                exit('Favorable');
            Rec.Status::Failed:
                exit('Unfavorable');
            Rec.Status::Canceled:
                exit('Subordinate');
        end;

        exit('Standard');
    end;

    local procedure GetScoreStyle(): Text
    begin
        if Rec."Deep Score" >= 86 then
            exit('Favorable');

        if Rec."Deep Score" >= 61 then
            exit('Ambiguous');

        if Rec."Deep Score" > 0 then
            exit('Unfavorable');

        exit('Standard');
    end;
}