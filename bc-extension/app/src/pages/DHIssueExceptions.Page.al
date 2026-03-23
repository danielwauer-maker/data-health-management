page 53153 "DH Issue Exceptions"
{
    PageType = List;
    SourceTable = "DH Issue Exception";
    ApplicationArea = All;
    UsageCategory = Lists;
    Caption = 'BCSentinel Issue Exceptions';
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field(Active; Rec.Active)
                {
                    ApplicationArea = All;
                }
                field("Issue Code"; Rec."Issue Code")
                {
                    ApplicationArea = All;
                }
                field(Reason; Rec.Reason)
                {
                    ApplicationArea = All;
                }
                field("Created By User"; Rec."Created By User")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Created At"; Rec."Created At")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Deactivated By User"; Rec."Deactivated By User")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Deactivated At"; Rec."Deactivated At")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(DeactivateException)
            {
                Caption = 'Prüfung wieder aktivieren';
                ApplicationArea = All;
                Image = Cancel;

                trigger OnAction()
                var
                    ExceptionMgt: Codeunit "DH Exception Mgt.";
                begin
                    ExceptionMgt.DeactivateExceptionEntry(Rec);
                end;
            }
        }
    }

    var
        ContextTableId: Integer;
        ContextSystemId: Guid;
        ContextRecordNo: Code[20];
        ContextRecordCaption: Text[100];

    trigger OnOpenPage()
    begin
        if ContextTableId <> 0 then begin
            Rec.SetRange("Table ID", ContextTableId);
            Rec.SetRange("Record SystemId", ContextSystemId);
        end;
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        Rec."Table ID" := ContextTableId;
        Rec."Record SystemId" := ContextSystemId;
        Rec."Record No." := ContextRecordNo;
        Rec."Record Caption" := ContextRecordCaption;
        Rec.Active := true;
    end;

    procedure SetContext(TableId: Integer; RecordSystemId: Guid; RecordNo: Code[20]; RecordCaption: Text[100])
    begin
        ContextTableId := TableId;
        ContextSystemId := RecordSystemId;
        ContextRecordNo := RecordNo;
        ContextRecordCaption := RecordCaption;
    end;
}
