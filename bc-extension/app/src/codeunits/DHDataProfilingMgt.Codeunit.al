codeunit 53164 "DH Data Profiling Mgt."
{
    procedure BuildDataProfile(): JsonObject
    var
        DataProfile: JsonObject;
        TotalRecords: Integer;
    begin
        AddCount(DataProfile, 'customers', CountCustomers(), TotalRecords);
        AddCount(DataProfile, 'vendors', CountVendors(), TotalRecords);
        AddCount(DataProfile, 'items', CountItems(), TotalRecords);
        AddCount(DataProfile, 'customer_ledger_entries', CountCustomerLedgerEntries(), TotalRecords);
        AddCount(DataProfile, 'vendor_ledger_entries', CountVendorLedgerEntries(), TotalRecords);
        AddCount(DataProfile, 'item_ledger_entries', CountItemLedgerEntries(), TotalRecords);
        AddCount(DataProfile, 'sales_headers', CountSalesHeaders(), TotalRecords);
        AddCount(DataProfile, 'sales_lines', CountSalesLines(), TotalRecords);
        AddCount(DataProfile, 'purchase_headers', CountPurchaseHeaders(), TotalRecords);
        AddCount(DataProfile, 'purchase_lines', CountPurchaseLines(), TotalRecords);
        AddCount(DataProfile, 'gl_entries', CountGLEntries(), TotalRecords);
        AddCount(DataProfile, 'value_entries', CountValueEntries(), TotalRecords);
        AddCount(DataProfile, 'warehouse_entries', CountWarehouseEntries(), TotalRecords);

        DataProfile.Add('total_records', TotalRecords);
        exit(DataProfile);
    end;

    local procedure AddCount(var DataProfile: JsonObject; PropertyName: Text; RecordCount: Integer; var TotalRecords: Integer)
    begin
        DataProfile.Add(PropertyName, RecordCount);
        TotalRecords += RecordCount;
    end;

    local procedure CountCustomers(): Integer
    var
        Customer: Record Customer;
    begin
        exit(Customer.Count());
    end;

    local procedure CountVendors(): Integer
    var
        Vendor: Record Vendor;
    begin
        exit(Vendor.Count());
    end;

    local procedure CountItems(): Integer
    var
        Item: Record Item;
    begin
        exit(Item.Count());
    end;

    local procedure CountCustomerLedgerEntries(): Integer
    var
        CustomerLedgerEntry: Record "Cust. Ledger Entry";
    begin
        exit(CustomerLedgerEntry.Count());
    end;

    local procedure CountVendorLedgerEntries(): Integer
    var
        VendorLedgerEntry: Record "Vendor Ledger Entry";
    begin
        exit(VendorLedgerEntry.Count());
    end;

    local procedure CountItemLedgerEntries(): Integer
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        exit(ItemLedgerEntry.Count());
    end;

    local procedure CountSalesHeaders(): Integer
    var
        SalesHeader: Record "Sales Header";
    begin
        exit(SalesHeader.Count());
    end;

    local procedure CountSalesLines(): Integer
    var
        SalesLine: Record "Sales Line";
    begin
        exit(SalesLine.Count());
    end;

    local procedure CountPurchaseHeaders(): Integer
    var
        PurchaseHeader: Record "Purchase Header";
    begin
        exit(PurchaseHeader.Count());
    end;

    local procedure CountPurchaseLines(): Integer
    var
        PurchaseLine: Record "Purchase Line";
    begin
        exit(PurchaseLine.Count());
    end;

    local procedure CountGLEntries(): Integer
    var
        GLEntry: Record "G/L Entry";
    begin
        exit(GLEntry.Count());
    end;

    local procedure CountValueEntries(): Integer
    var
        ValueEntry: Record "Value Entry";
    begin
        exit(ValueEntry.Count());
    end;

    local procedure CountWarehouseEntries(): Integer
    var
        WarehouseEntry: Record "Warehouse Entry";
    begin
        exit(WarehouseEntry.Count());
    end;
}
