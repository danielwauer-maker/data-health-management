codeunit 53143 "DH Issue Drilldown Dispatcher"
{
    procedure OpenByIssueCode(IssueCode: Code[50])
    var
        IssueCodeUpper: Text;
        Item: Record Item;
        Customer: Record Customer;
        Vendor: Record Vendor;
        SalesHeader: Record "Sales Header";
        PurchaseHeader: Record "Purchase Header";
        CustomerLedgerEntry: Record "Cust. Ledger Entry";
        VendorLedgerEntry: Record "Vendor Ledger Entry";
        SalesLine: Record "Sales Line";
        PurchaseLine: Record "Purchase Line";
        SalesWorklist: Page "DH Sales Line Issue Worklist";
        PurchaseWorklist: Page "DH Purch. Line Worklist";
        CustomerWorklist: Page "DH Customer Issue List";
        VendorWorklist: Page "DH Vendor Issue List";
    begin
        IssueCodeUpper := UpperCase(Format(IssueCode));

        case IssueCodeUpper of
            'ITEMS_NEGATIVE_INVENTORY':
                Page.Run(Page::"DH Item Neg. Inventory");
            'ITEMS_WITHOUT_UNIT_COST':
                Page.Run(Page::"DH Item Missing Cost List");
            'BLOCKED_ITEMS_WITH_INVENTORY':
                Page.Run(Page::"DH Blocked Items Inv");
            'ITEMS_WITHOUT_UNIT_PRICE':
                Page.Run(Page::"DH Item Missing Price List");

            'SALES_ORDERS_MISSING_SHIPMENT_DATE':
                begin
                    SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
                    SalesHeader.SetRange("Shipment Date", 0D);
                    Page.Run(Page::"Sales Order List", SalesHeader);
                end;
            'SALES_ORDERS_OLD_OPEN':
                begin
                    SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
                    SalesHeader.SetFilter("Document Date", '<%1', CalcDate('<-30D>', Today));
                    Page.Run(Page::"Sales Order List", SalesHeader);
                end;
            'SALES_DOCS_WITH_BLOCKED_CUSTOMERS':
                begin
                    PrepareBlockedCustomerSalesOrders(SalesHeader);
                    Page.Run(Page::"Sales Order List", SalesHeader);
                end;
            'SALES_LINES_ZERO_QUANTITY',
            'SALES_LINES_ZERO_PRICE',
            'SALES_LINES_MISSING_DIMENSIONS',
            'SALES_LINES_MISSING_NO',
            'SALES_LINES_WITH_BLOCKED_ITEMS':
                begin
                    SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
                    SalesWorklist.SetTableView(SalesLine);
                    SalesWorklist.SetIssueCode(IssueCodeUpper);
                    SalesWorklist.Run();
                end;

            'PURCHASE_ORDERS_MISSING_EXPECTED_DATE':
                begin
                    PurchaseHeader.SetRange("Document Type", PurchaseHeader."Document Type"::Order);
                    PurchaseHeader.SetRange("Expected Receipt Date", 0D);
                    Page.Run(Page::"Purchase Order List", PurchaseHeader);
                end;
            'PURCHASE_ORDERS_OLD_OPEN':
                begin
                    PurchaseHeader.SetRange("Document Type", PurchaseHeader."Document Type"::Order);
                    PurchaseHeader.SetFilter("Document Date", '<%1', CalcDate('<-30D>', Today));
                    Page.Run(Page::"Purchase Order List", PurchaseHeader);
                end;
            'PURCHASE_DOCS_WITH_BLOCKED_VENDORS':
                begin
                    PrepareBlockedVendorPurchaseOrders(PurchaseHeader);
                    Page.Run(Page::"Purchase Order List", PurchaseHeader);
                end;
            'PURCHASE_LINES_ZERO_QUANTITY',
            'PURCHASE_LINES_ZERO_COST',
            'PURCHASE_LINES_MISSING_DIMENSIONS',
            'PURCHASE_LINES_MISSING_NO',
            'PURCHASE_LINES_WITH_BLOCKED_ITEMS':
                begin
                    PurchaseLine.SetRange("Document Type", PurchaseLine."Document Type"::Order);
                    PurchaseWorklist.SetTableView(PurchaseLine);
                    PurchaseWorklist.SetIssueCode(IssueCodeUpper);
                    PurchaseWorklist.Run();
                end;

            'CUSTOMER_LEDGER_OVERDUE_30':
                begin
                    CustomerLedgerEntry.SetRange(Open, true);
                    CustomerLedgerEntry.SetFilter("Due Date", '<%1', CalcDate('<-30D>', Today));
                    Page.Run(Page::"Customer Ledger Entries", CustomerLedgerEntry);
                end;
            'BLOCKED_CUSTOMERS_WITH_OPEN_LEDGER':
                begin
                    PrepareBlockedCustomerLedgerEntries(CustomerLedgerEntry);
                    Page.Run(Page::"Customer Ledger Entries", CustomerLedgerEntry);
                end;
            'VENDOR_LEDGER_OVERDUE_30':
                begin
                    VendorLedgerEntry.SetRange(Open, true);
                    VendorLedgerEntry.SetFilter("Due Date", '<%1', CalcDate('<-30D>', Today));
                    Page.Run(Page::"Vendor Ledger Entries", VendorLedgerEntry);
                end;
            'BLOCKED_VENDORS_WITH_OPEN_LEDGER':
                begin
                    PrepareBlockedVendorLedgerEntries(VendorLedgerEntry);
                    Page.Run(Page::"Vendor Ledger Entries", VendorLedgerEntry);
                end;

            'DUPLICATE_CUSTOMER_EMAIL',
            'DUPLICATE_CUSTOMER_NAME_CITY',
            'DUPLICATE_CUSTOMER_VAT',
            'DUPLICATE_VENDOR_EMAIL',
            'DUPLICATE_VENDOR_NAME_CITY',
            'DUPLICATE_VENDOR_VAT',
            'DUPLICATES_EMAIL',
            'DUPLICATES_VAT',
            'DUPLICATES_NAME_POSTCODE_CITY',
            'CUSTOMERS_DUPLICATE_EMAIL',
            'CUSTOMERS_DUPLICATE_NAME_POST_CITY',
            'CUSTOMERS_DUPLICATE_VAT',
            'VENDORS_DUPLICATE_EMAIL',
            'VENDORS_DUPLICATE_NAME_POST_CITY',
            'VENDORS_DUPLICATE_VAT':
                Page.Run(Page::"DH Duplicate Worklist");
            else
                if TryOpenCustomerIssue(IssueCodeUpper, Customer) then begin
                    CustomerWorklist.SetTableView(Customer);
                    CustomerWorklist.SetIssueCode(IssueCodeUpper);
                    CustomerWorklist.Run();
                end else
                    if TryOpenVendorIssue(IssueCodeUpper, Vendor) then begin
                        VendorWorklist.SetTableView(Vendor);
                        VendorWorklist.SetIssueCode(IssueCodeUpper);
                        VendorWorklist.Run();
                    end else
                        if TryOpenBaseIssue(IssueCodeUpper, Item) then
                            Page.Run(Page::"Item List", Item)
                        else
                            Message(
                              'Für den Issue-Code %1 ist aktuell noch keine direkte Bearbeitungsliste hinterlegt.',
                              IssueCode);
        end;
    end;

    local procedure TryOpenBaseIssue(IssueCodeUpper: Text; var Item: Record Item): Boolean
    begin
        case IssueCodeUpper of
            'ITEMS_MISSING_DESCRIPTION':
                Item.SetRange(Description, '');
            'ITEMS_MISSING_CATEGORY':
                Item.SetRange("Item Category Code", '');
            'ITEMS_MISSING_BASE_UNIT',
            'ITEMS_MISSING_BASE_UOM':
                Item.SetRange("Base Unit of Measure", '');
            'ITEMS_MISSING_GEN_PROD_POSTING_GROUP',
            'ITEMS_MISSING_GEN_PROD_POSTING':
                Item.SetRange("Gen. Prod. Posting Group", '');
            'ITEMS_MISSING_INVENTORY_POSTING_GROUP',
            'ITEMS_MISSING_INVENTORY_POSTING':
                Item.SetRange("Inventory Posting Group", '');
            'ITEMS_MISSING_VAT_PROD_POSTING_GROUP':
                Item.SetRange("VAT Prod. Posting Group", '');
            'ITEMS_MISSING_VENDOR_NO',
            'ITEMS_WITHOUT_VENDOR_NO':
                Item.SetRange("Vendor No.", '');
            else
                exit(false);
        end;

        exit(true);
    end;

    local procedure TryOpenCustomerIssue(IssueCodeUpper: Text; var Customer: Record Customer): Boolean
    begin
        case IssueCodeUpper of
            'CUSTOMERS_MISSING_NAME':
                Customer.SetRange(Name, '');
            'CUSTOMERS_MISSING_SEARCH_NAME':
                Customer.SetRange("Search Name", '');
            'CUSTOMERS_MISSING_ADDRESS':
                Customer.SetRange(Address, '');
            'CUSTOMERS_MISSING_CITY':
                Customer.SetRange(City, '');
            'CUSTOMERS_MISSING_POST_CODE':
                Customer.SetRange("Post Code", '');
            'CUSTOMERS_MISSING_COUNTRY':
                Customer.SetRange("Country/Region Code", '');
            'CUSTOMERS_MISSING_EMAIL':
                Customer.SetRange("E-Mail", '');
            'CUSTOMERS_MISSING_PHONE':
                Customer.SetRange("Phone No.", '');
            'CUSTOMERS_MISSING_PAYMENT_TERMS':
                Customer.SetRange("Payment Terms Code", '');
            'CUSTOMERS_MISSING_PAYMENT_METHOD':
                Customer.SetRange("Payment Method Code", '');
            'CUSTOMERS_MISSING_POSTING_GROUP':
                Customer.SetRange("Customer Posting Group", '');
            'CUSTOMERS_MISSING_GEN_BUS_POSTING':
                Customer.SetRange("Gen. Bus. Posting Group", '');
            'CUSTOMERS_MISSING_VAT_BUS_POSTING':
                Customer.SetRange("VAT Bus. Posting Group", '');
            'CUSTOMERS_MISSING_CREDIT_LIMIT':
                Customer.SetRange("Credit Limit (LCY)", 0);
            else
                exit(false);
        end;

        exit(true);
    end;

    local procedure TryOpenVendorIssue(IssueCodeUpper: Text; var Vendor: Record Vendor): Boolean
    begin
        case IssueCodeUpper of
            'VENDORS_MISSING_NAME':
                Vendor.SetRange(Name, '');
            'VENDORS_MISSING_SEARCH_NAME':
                Vendor.SetRange("Search Name", '');
            'VENDORS_MISSING_ADDRESS':
                Vendor.SetRange(Address, '');
            'VENDORS_MISSING_CITY':
                Vendor.SetRange(City, '');
            'VENDORS_MISSING_POST_CODE':
                Vendor.SetRange("Post Code", '');
            'VENDORS_MISSING_COUNTRY':
                Vendor.SetRange("Country/Region Code", '');
            'VENDORS_MISSING_EMAIL':
                Vendor.SetRange("E-Mail", '');
            'VENDORS_MISSING_PHONE':
                Vendor.SetRange("Phone No.", '');
            'VENDORS_MISSING_PAYMENT_TERMS':
                Vendor.SetRange("Payment Terms Code", '');
            'VENDORS_MISSING_PAYMENT_METHOD':
                Vendor.SetRange("Payment Method Code", '');
            'VENDORS_MISSING_POSTING_GROUP':
                Vendor.SetRange("Vendor Posting Group", '');
            'VENDORS_MISSING_GEN_BUS_POSTING':
                Vendor.SetRange("Gen. Bus. Posting Group", '');
            'VENDORS_MISSING_VAT_BUS_POSTING':
                Vendor.SetRange("VAT Bus. Posting Group", '');
            'VENDORS_MISSING_BANK_ACCOUNT':
                Vendor.SetRange("Preferred Bank Account Code", '');
            else
                exit(false);
        end;

        exit(true);
    end;

    local procedure PrepareBlockedCustomerSalesOrders(var SalesHeader: Record "Sales Header")
    var
        Customer: Record Customer;
    begin
        SalesHeader.Reset();
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader.MarkedOnly(false);
        if SalesHeader.FindSet() then
            repeat
                if Customer.Get(SalesHeader."Sell-to Customer No.") then
                    if Customer.Blocked <> Customer.Blocked::" " then
                        SalesHeader.Mark(true);
            until SalesHeader.Next() = 0;
        SalesHeader.MarkedOnly(true);
    end;

    local procedure PrepareBlockedVendorPurchaseOrders(var PurchaseHeader: Record "Purchase Header")
    var
        Vendor: Record Vendor;
    begin
        PurchaseHeader.Reset();
        PurchaseHeader.SetRange("Document Type", PurchaseHeader."Document Type"::Order);
        PurchaseHeader.MarkedOnly(false);
        if PurchaseHeader.FindSet() then
            repeat
                if Vendor.Get(PurchaseHeader."Buy-from Vendor No.") then
                    if Vendor.Blocked <> Vendor.Blocked::" " then
                        PurchaseHeader.Mark(true);
            until PurchaseHeader.Next() = 0;
        PurchaseHeader.MarkedOnly(true);
    end;

    local procedure PrepareBlockedCustomerLedgerEntries(var CustomerLedgerEntry: Record "Cust. Ledger Entry")
    var
        Customer: Record Customer;
    begin
        CustomerLedgerEntry.Reset();
        CustomerLedgerEntry.SetRange(Open, true);
        CustomerLedgerEntry.MarkedOnly(false);
        if CustomerLedgerEntry.FindSet() then
            repeat
                if Customer.Get(CustomerLedgerEntry."Customer No.") then
                    if Customer.Blocked <> Customer.Blocked::" " then
                        CustomerLedgerEntry.Mark(true);
            until CustomerLedgerEntry.Next() = 0;
        CustomerLedgerEntry.MarkedOnly(true);
    end;

    local procedure PrepareBlockedVendorLedgerEntries(var VendorLedgerEntry: Record "Vendor Ledger Entry")
    var
        Vendor: Record Vendor;
    begin
        VendorLedgerEntry.Reset();
        VendorLedgerEntry.SetRange(Open, true);
        VendorLedgerEntry.MarkedOnly(false);
        if VendorLedgerEntry.FindSet() then
            repeat
                if Vendor.Get(VendorLedgerEntry."Vendor No.") then
                    if Vendor.Blocked <> Vendor.Blocked::" " then
                        VendorLedgerEntry.Mark(true);
            until VendorLedgerEntry.Next() = 0;
        VendorLedgerEntry.MarkedOnly(true);
    end;
}
