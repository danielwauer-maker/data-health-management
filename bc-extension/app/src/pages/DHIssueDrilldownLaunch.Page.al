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
        IssueCode := CopyStr(UpperCase(Format(IssueCodeField.GetFilter())), 1, MaxStrLen(IssueCode));
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

    var
        StatusTxt: Text[100];
}
