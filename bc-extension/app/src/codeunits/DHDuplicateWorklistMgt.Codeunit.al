codeunit 53147 "DH Duplicate Worklist Mgt."
{
    procedure BuildWorklist(var TempDuplicateBuffer: Record "DH Duplicate Buffer" temporary)
    begin
        TempDuplicateBuffer.Reset();
        TempDuplicateBuffer.DeleteAll();

        BuildCustomerDuplicates(TempDuplicateBuffer);
        BuildVendorDuplicates(TempDuplicateBuffer);
    end;

    local procedure BuildCustomerDuplicates(var TempDuplicateBuffer: Record "DH Duplicate Buffer" temporary)
    var
        Customer: Record Customer;
        DuplicateCountByKey: Dictionary of [Text, Integer];
    begin
        CollectCustomerKeys(DuplicateCountByKey);

        Customer.Reset();
        if Customer.FindSet() then
            repeat
                AddCustomerDuplicate(TempDuplicateBuffer, Customer, DuplicateCountByKey, 'EMAIL', Customer."E-Mail", 'Gleiche E-Mail');
                AddCustomerDuplicate(TempDuplicateBuffer, Customer, DuplicateCountByKey, 'VAT', Customer."VAT Registration No.", 'Gleiche USt-IdNr.');
                AddCustomerDuplicate(TempDuplicateBuffer, Customer, DuplicateCountByKey, 'NAMECITY', GetNameCityKey(Customer.Name, Customer."Post Code", Customer.City), 'Gleicher Name + PLZ + Ort');
            until Customer.Next() = 0;
    end;

    local procedure BuildVendorDuplicates(var TempDuplicateBuffer: Record "DH Duplicate Buffer" temporary)
    var
        Vendor: Record Vendor;
        DuplicateCountByKey: Dictionary of [Text, Integer];
    begin
        CollectVendorKeys(DuplicateCountByKey);

        Vendor.Reset();
        if Vendor.FindSet() then
            repeat
                AddVendorDuplicate(TempDuplicateBuffer, Vendor, DuplicateCountByKey, 'EMAIL', Vendor."E-Mail", 'Gleiche E-Mail');
                AddVendorDuplicate(TempDuplicateBuffer, Vendor, DuplicateCountByKey, 'VAT', Vendor."VAT Registration No.", 'Gleiche USt-IdNr.');
                AddVendorDuplicate(TempDuplicateBuffer, Vendor, DuplicateCountByKey, 'NAMECITY', GetNameCityKey(Vendor.Name, Vendor."Post Code", Vendor.City), 'Gleicher Name + PLZ + Ort');
            until Vendor.Next() = 0;
    end;

    local procedure CollectCustomerKeys(var DuplicateCountByKey: Dictionary of [Text, Integer])
    var
        Customer: Record Customer;
    begin
        Customer.Reset();
        if Customer.FindSet() then
            repeat
                RegisterDuplicateKey(DuplicateCountByKey, BuildKey('CUSTOMER', 'EMAIL', Customer."E-Mail"));
                RegisterDuplicateKey(DuplicateCountByKey, BuildKey('CUSTOMER', 'VAT', Customer."VAT Registration No."));
                RegisterDuplicateKey(DuplicateCountByKey, BuildKey('CUSTOMER', 'NAMECITY', GetNameCityKey(Customer.Name, Customer."Post Code", Customer.City)));
            until Customer.Next() = 0;
    end;

    local procedure CollectVendorKeys(var DuplicateCountByKey: Dictionary of [Text, Integer])
    var
        Vendor: Record Vendor;
    begin
        Vendor.Reset();
        if Vendor.FindSet() then
            repeat
                RegisterDuplicateKey(DuplicateCountByKey, BuildKey('VENDOR', 'EMAIL', Vendor."E-Mail"));
                RegisterDuplicateKey(DuplicateCountByKey, BuildKey('VENDOR', 'VAT', Vendor."VAT Registration No."));
                RegisterDuplicateKey(DuplicateCountByKey, BuildKey('VENDOR', 'NAMECITY', GetNameCityKey(Vendor.Name, Vendor."Post Code", Vendor.City)));
            until Vendor.Next() = 0;
    end;

    local procedure AddCustomerDuplicate(var TempDuplicateBuffer: Record "DH Duplicate Buffer" temporary; Customer: Record Customer; DuplicateCountByKey: Dictionary of [Text, Integer]; DuplicateType: Code[20]; RawValue: Text; Reason: Text)
    var
        DuplicateCount: Integer;
        GroupKey: Text[250];
    begin
        if not HasRelevantValue(DuplicateType, RawValue) then
            exit;

        GroupKey := BuildKey('CUSTOMER', DuplicateType, RawValue);
        if not DuplicateCountByKey.Get(GroupKey, DuplicateCount) then
            exit;

        if DuplicateCount <= 1 then
            exit;

        InsertDuplicateBuffer(TempDuplicateBuffer, TempDuplicateBuffer."Source Type"::Customer, Customer."No.", Customer.Name, Customer.City, Customer."Post Code", Customer."E-Mail", Customer."VAT Registration No.", GroupKey, Reason, DuplicateCount);
    end;

    local procedure AddVendorDuplicate(var TempDuplicateBuffer: Record "DH Duplicate Buffer" temporary; Vendor: Record Vendor; DuplicateCountByKey: Dictionary of [Text, Integer]; DuplicateType: Code[20]; RawValue: Text; Reason: Text)
    var
        DuplicateCount: Integer;
        GroupKey: Text[250];
    begin
        if not HasRelevantValue(DuplicateType, RawValue) then
            exit;

        GroupKey := BuildKey('VENDOR', DuplicateType, RawValue);
        if not DuplicateCountByKey.Get(GroupKey, DuplicateCount) then
            exit;

        if DuplicateCount <= 1 then
            exit;

        InsertDuplicateBuffer(TempDuplicateBuffer, TempDuplicateBuffer."Source Type"::Vendor, Vendor."No.", Vendor.Name, Vendor.City, Vendor."Post Code", Vendor."E-Mail", Vendor."VAT Registration No.", GroupKey, Reason, DuplicateCount);
    end;

    local procedure InsertDuplicateBuffer(var TempDuplicateBuffer: Record "DH Duplicate Buffer" temporary; SourceType: Enum "DH Duplicate Source Type"; SourceNo: Code[20]; Name: Text[100]; City: Text[30]; PostCode: Code[20]; Email: Text[80]; VatRegistrationNo: Text[20]; GroupKey: Text[250]; Reason: Text[100]; DuplicateCount: Integer)
    begin
        if TempDuplicateBuffer.FindLast() then;
        TempDuplicateBuffer.Init();
        TempDuplicateBuffer."Entry No." := TempDuplicateBuffer."Entry No." + 1;
        TempDuplicateBuffer."Source Type" := SourceType;
        TempDuplicateBuffer."Source No." := SourceNo;
        TempDuplicateBuffer.Name := CopyStr(Name, 1, MaxStrLen(TempDuplicateBuffer.Name));
        TempDuplicateBuffer.City := CopyStr(City, 1, MaxStrLen(TempDuplicateBuffer.City));
        TempDuplicateBuffer."Post Code" := PostCode;
        TempDuplicateBuffer."E-Mail" := CopyStr(Email, 1, MaxStrLen(TempDuplicateBuffer."E-Mail"));
        TempDuplicateBuffer."VAT Registration No." := CopyStr(VatRegistrationNo, 1, MaxStrLen(TempDuplicateBuffer."VAT Registration No."));
        TempDuplicateBuffer."Group Key" := CopyStr(GroupKey, 1, MaxStrLen(TempDuplicateBuffer."Group Key"));
        TempDuplicateBuffer.Reason := CopyStr(Reason, 1, MaxStrLen(TempDuplicateBuffer.Reason));
        TempDuplicateBuffer."Duplicate Count" := DuplicateCount;
        TempDuplicateBuffer.Insert();
    end;

    local procedure RegisterDuplicateKey(var DuplicateCountByKey: Dictionary of [Text, Integer]; GroupKey: Text[250])
    var
        CurrentCount: Integer;
    begin
        if GroupKey = '' then
            exit;

        if DuplicateCountByKey.Get(GroupKey, CurrentCount) then
            DuplicateCountByKey.Set(GroupKey, CurrentCount + 1)
        else
            DuplicateCountByKey.Add(GroupKey, 1);
    end;

    local procedure BuildKey(SourceType: Text; DuplicateType: Code[20]; RawValue: Text): Text[250]
    var
        NormalizedValue: Text;
    begin
        NormalizedValue := UpperCase(DelChr(RawValue, '=', ' '));
        if NormalizedValue = '' then
            exit('');

        exit(CopyStr(StrSubstNo('%1|%2|%3', SourceType, DuplicateType, NormalizedValue), 1, 250));
    end;

    local procedure GetNameCityKey(Name: Text; PostCode: Code[20]; City: Text): Text
    begin
        exit(StrSubstNo('%1|%2|%3', Name, PostCode, City));
    end;

    local procedure HasRelevantValue(DuplicateType: Code[20]; RawValue: Text): Boolean
    begin
        if DuplicateType = 'NAMECITY' then
            exit(DelChr(RawValue, '=', ' |') <> '');

        exit(DelChr(RawValue, '=', ' ') <> '');
    end;
}
