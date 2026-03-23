codeunit 53152 "DH Exception Mgt."
{
    procedure IsCustomerIssueExcluded(var Customer: Record Customer; IssueCode: Code[50]): Boolean
    begin
        exit(IsIssueExcluded(Database::Customer, Customer.SystemId, IssueCode));
    end;

    procedure IsVendorIssueExcluded(var Vendor: Record Vendor; IssueCode: Code[50]): Boolean
    begin
        exit(IsIssueExcluded(Database::Vendor, Vendor.SystemId, IssueCode));
    end;

    procedure IsItemIssueExcluded(var Item: Record Item; IssueCode: Code[50]): Boolean
    begin
        exit(IsIssueExcluded(Database::Item, Item.SystemId, IssueCode));
    end;

    procedure IsIssueExcluded(TableId: Integer; RecordSystemId: Guid; IssueCode: Code[50]): Boolean
    var
        IssueException: Record "DH Issue Exception";
    begin
        IssueException.SetRange("Table ID", TableId);
        IssueException.SetRange("Record SystemId", RecordSystemId);
        IssueException.SetRange("Issue Code", IssueCode);
        IssueException.SetRange(Active, true);
        exit(not IssueException.IsEmpty());
    end;

    procedure AddCustomerException(var Customer: Record Customer; IssueCode: Code[50]; Reason: Text[250])
    begin
        AddOrActivateException(Database::Customer, Customer.SystemId, Customer."No.", Customer.Name, IssueCode, Reason);
    end;

    procedure AddVendorException(var Vendor: Record Vendor; IssueCode: Code[50]; Reason: Text[250])
    begin
        AddOrActivateException(Database::Vendor, Vendor.SystemId, Vendor."No.", Vendor.Name, IssueCode, Reason);
    end;

    procedure AddItemException(var Item: Record Item; IssueCode: Code[50]; Reason: Text[250])
    begin
        AddOrActivateException(Database::Item, Item.SystemId, Item."No.", Item.Description, IssueCode, Reason);
    end;

    procedure DeactivateCustomerException(var Customer: Record Customer; IssueCode: Code[50]; Comment: Text[250])
    begin
        DeactivateException(Database::Customer, Customer.SystemId, IssueCode, Comment);
    end;

    procedure DeactivateVendorException(var Vendor: Record Vendor; IssueCode: Code[50]; Comment: Text[250])
    begin
        DeactivateException(Database::Vendor, Vendor.SystemId, IssueCode, Comment);
    end;

    procedure DeactivateItemException(var Item: Record Item; IssueCode: Code[50]; Comment: Text[250])
    begin
        DeactivateException(Database::Item, Item.SystemId, IssueCode, Comment);
    end;

    procedure MarkCustomerCorrected(var Customer: Record Customer; IssueCode: Code[50]; Comment: Text[250])
    begin
        InsertActionLog(Database::Customer, Customer.SystemId, Customer."No.", Customer.Name, IssueCode, 'CORRECTED', Comment);
    end;

    procedure MarkVendorCorrected(var Vendor: Record Vendor; IssueCode: Code[50]; Comment: Text[250])
    begin
        InsertActionLog(Database::Vendor, Vendor.SystemId, Vendor."No.", Vendor.Name, IssueCode, 'CORRECTED', Comment);
    end;

    procedure MarkItemCorrected(var Item: Record Item; IssueCode: Code[50]; Comment: Text[250])
    begin
        InsertActionLog(Database::Item, Item.SystemId, Item."No.", Item.Description, IssueCode, 'CORRECTED', Comment);
    end;

    procedure OpenCustomerExceptions(var Customer: Record Customer)
    var
        ExceptionsPage: Page "DH Issue Exceptions";
        RecordCaption: Text[100];
    begin
        RecordCaption := CopyStr(Customer.Name, 1, 100);
        ExceptionsPage.SetContext(Database::Customer, Customer.SystemId, Customer."No.", RecordCaption);
        ExceptionsPage.Run();
    end;

    procedure OpenVendorExceptions(var Vendor: Record Vendor)
    var
        ExceptionsPage: Page "DH Issue Exceptions";
        RecordCaption: Text[100];
    begin
        RecordCaption := CopyStr(Vendor.Name, 1, 100);
        ExceptionsPage.SetContext(Database::Vendor, Vendor.SystemId, Vendor."No.", RecordCaption);
        ExceptionsPage.Run();
    end;

    procedure OpenItemExceptions(var Item: Record Item)
    var
        ExceptionsPage: Page "DH Issue Exceptions";
        RecordCaption: Text[100];
    begin
        RecordCaption := CopyStr(Item.Description, 1, 100);
        ExceptionsPage.SetContext(Database::Item, Item.SystemId, Item."No.", RecordCaption);
        ExceptionsPage.Run();
    end;


    procedure DeactivateExceptionEntry(var IssueException: Record "DH Issue Exception")
    begin
        if not IssueException.Active then
            exit;

        IssueException.Active := false;
        IssueException."Deactivated By User" := CopyStr(UserId(), 1, MaxStrLen(IssueException."Deactivated By User"));
        IssueException."Deactivated At" := CurrentDateTime();
        IssueException.Modify(true);
        InsertActionLog(IssueException."Table ID", IssueException."Record SystemId", IssueException."Record No.", IssueException."Record Caption", IssueException."Issue Code", 'INCLUDED', 'Prüfung manuell wieder aktiviert.');
    end;

    local procedure AddOrActivateException(TableId: Integer; RecordSystemId: Guid; RecordNo: Code[20]; RecordCaption: Text[100]; IssueCode: Code[50]; Reason: Text[250])
    var
        IssueException: Record "DH Issue Exception";
    begin
        IssueException.SetRange("Table ID", TableId);
        IssueException.SetRange("Record SystemId", RecordSystemId);
        IssueException.SetRange("Issue Code", IssueCode);
        if IssueException.FindFirst() then begin
            if not IssueException.Active then begin
                IssueException.Active := true;
                IssueException.Reason := CopyStr(Reason, 1, MaxStrLen(IssueException.Reason));
                IssueException."Deactivated By User" := '';
                IssueException."Deactivated At" := 0DT;
                IssueException.Modify(true);
            end;
        end else begin
            IssueException.Init();
            IssueException."Table ID" := TableId;
            IssueException."Record SystemId" := RecordSystemId;
            IssueException."Record No." := RecordNo;
            IssueException."Record Caption" := CopyStr(RecordCaption, 1, MaxStrLen(IssueException."Record Caption"));
            IssueException."Issue Code" := IssueCode;
            IssueException.Reason := CopyStr(Reason, 1, MaxStrLen(IssueException.Reason));
            IssueException.Active := true;
            IssueException.Insert(true);
        end;

        InsertActionLog(TableId, RecordSystemId, RecordNo, RecordCaption, IssueCode, 'EXCLUDED', Reason);
    end;

    local procedure DeactivateException(TableId: Integer; RecordSystemId: Guid; IssueCode: Code[50]; Comment: Text[250])
    var
        IssueException: Record "DH Issue Exception";
    begin
        IssueException.SetRange("Table ID", TableId);
        IssueException.SetRange("Record SystemId", RecordSystemId);
        IssueException.SetRange("Issue Code", IssueCode);
        IssueException.SetRange(Active, true);
        if IssueException.FindFirst() then begin
            IssueException.Active := false;
            IssueException."Deactivated By User" := CopyStr(UserId(), 1, MaxStrLen(IssueException."Deactivated By User"));
            IssueException."Deactivated At" := CurrentDateTime();
            IssueException.Modify(true);
            InsertActionLog(TableId, RecordSystemId, IssueException."Record No.", IssueException."Record Caption", IssueCode, 'INCLUDED', Comment);
        end;
    end;

    local procedure InsertActionLog(TableId: Integer; RecordSystemId: Guid; RecordNo: Code[20]; RecordCaption: Text[100]; IssueCode: Code[50]; ActionType: Code[20]; Comment: Text[250])
    var
        IssueActionLog: Record "DH Issue Action Log";
    begin
        IssueActionLog.Init();
        IssueActionLog."Table ID" := TableId;
        IssueActionLog."Record SystemId" := RecordSystemId;
        IssueActionLog."Record No." := RecordNo;
        IssueActionLog."Record Caption" := CopyStr(RecordCaption, 1, MaxStrLen(IssueActionLog."Record Caption"));
        IssueActionLog."Issue Code" := IssueCode;
        IssueActionLog."Action Type" := ActionType;
        IssueActionLog.Comment := CopyStr(Comment, 1, MaxStrLen(IssueActionLog.Comment));
        IssueActionLog.Insert(true);
    end;
}
