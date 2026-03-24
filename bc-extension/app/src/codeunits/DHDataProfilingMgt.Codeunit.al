codeunit 53150 "DH Data Profiling Mgt."
{
    procedure BuildDataProfile(): JsonObject
    var
        Customer: Record Customer;
        Vendor: Record Vendor;
        Item: Record Item;
        CustLedger: Record "Cust. Ledger Entry";
        VendLedger: Record "Vendor Ledger Entry";
        ItemLedger: Record "Item Ledger Entry";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        GLEntry: Record "G/L Entry";
        ValueEntry: Record "Value Entry";
        WarehouseEntry: Record "Warehouse Entry";
        Profile: JsonObject;
        TotalRecords: Integer;
    begin
        Profile.Add('customers', Customer.Count());
        Profile.Add('vendors', Vendor.Count());
        Profile.Add('items', Item.Count());
        Profile.Add('customer_ledger_entries', CustLedger.Count());
        Profile.Add('vendor_ledger_entries', VendLedger.Count());
        Profile.Add('item_ledger_entries', ItemLedger.Count());
        Profile.Add('sales_headers', SalesHeader.Count());
        Profile.Add('sales_lines', SalesLine.Count());
        Profile.Add('purchase_headers', PurchaseHeader.Count());
        Profile.Add('purchase_lines', PurchaseLine.Count());
        Profile.Add('gl_entries', GLEntry.Count());
        Profile.Add('value_entries', ValueEntry.Count());
        Profile.Add('warehouse_entries', WarehouseEntry.Count());

        TotalRecords :=
            Customer.Count() + Vendor.Count() + Item.Count() +
            CustLedger.Count() + VendLedger.Count() + ItemLedger.Count() +
            SalesHeader.Count() + SalesLine.Count() +
            PurchaseHeader.Count() + PurchaseLine.Count() +
            GLEntry.Count() + ValueEntry.Count() + WarehouseEntry.Count();

        Profile.Add('total_records', TotalRecords);
        exit(Profile);
    end;
}
