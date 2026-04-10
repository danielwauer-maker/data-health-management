page 53159 "DH Issue Drilldown Launch"
{
    PageType = Card;
    SourceTable = "DH Setup";
    ApplicationArea = All;
    UsageCategory = None;
    Caption = 'DH Issue Drilldown Launch';
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            group(Launch)
            {
                field(StatusTxt; StatusTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Status';
                    Editable = false;
                }
            }
        }
    }

    trigger OnOpenPage()
    var
        IssueCode: Code[50];
        SetupRef: RecordRef;
        IssueCodeField: FieldRef;
        IssueDrilldownDispatcher: Codeunit "DH Issue Drilldown Dispatcher";
    begin
        SetupRef.GetTable(Rec);
        IssueCodeField := SetupRef.Field(26);
        IssueCode := GetNormalizedIssueCode(IssueCodeField);
        if IssueCode = '' then
            Error('Missing issue code for drilldown launch.');

        if not Rec.Get('SETUP') then
            Error('Setup not found.');

        if not Rec."Premium Enabled" then begin
            Message('Premium access is required.');
            CurrPage.Close();
            exit;
        end;

        StatusTxt := StrSubstNo('Opening Business Central worklist for %1 ...', IssueCode);
        IssueDrilldownDispatcher.OpenByIssueCode(IssueCode);
        CurrPage.Close();
    end;

    local procedure GetNormalizedIssueCode(IssueCodeField: FieldRef): Code[50]
    var
        FilterText: Text;
        NormalizedIssueCode: Code[50];
    begin
        FilterText := UpperCase(Format(IssueCodeField.GetFilter()));
        FilterText := DelChr(FilterText, '=', '@*''" ');
        NormalizedIssueCode := CopyStr(FilterText, 1, MaxStrLen(NormalizedIssueCode));
        exit(NormalizedIssueCode);
    end;

    var
        StatusTxt: Text[100];
}
