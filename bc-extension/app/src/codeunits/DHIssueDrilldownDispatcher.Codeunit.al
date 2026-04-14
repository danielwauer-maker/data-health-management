codeunit 53143 "DH Issue Drilldown Dispatcher"
{
    procedure OpenByIssueCode(IssueCode: Code[50])
    var
        IssueCodeUpper: Text;
        Item: Record Item;
        Customer: Record Customer;
        Vendor: Record Vendor;
        Contact: Record Contact;
        Employee: Record Employee;
        ResourceRec: Record Resource;
        SalesHeader: Record "Sales Header";
        PurchaseHeader: Record "Purchase Header";
        CustomerLedgerEntry: Record "Cust. Ledger Entry";
        VendorLedgerEntry: Record "Vendor Ledger Entry";
        GLEntry: Record "G/L Entry";
        GLAccount: Record "G/L Account";
        SalesLine: Record "Sales Line";
        PurchaseLine: Record "Purchase Line";
        ServiceItem: Record "Service Item";
        ServiceHeader: Record "Service Header";
        ServiceLine: Record "Service Line";
        JobRec: Record Job;
        JobTask: Record "Job Task";
        JobPlanningLine: Record "Job Planning Line";
        ProdBOMHeader: Record "Production BOM Header";
        ProdBOMLine: Record "Production BOM Line";
        RoutingHeader: Record "Routing Header";
        RoutingLine: Record "Routing Line";
        WorkCenter: Record "Work Center";
        MachineCenter: Record "Machine Center";
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
            'SALES_DOCS_WITH_BLOCKED_CUSTOMERS',
            'BLOCKED_CUSTOMERS_WITH_OPEN_SALES_DOCS':
                begin
                    PrepareBlockedCustomerSalesOrders(SalesHeader);
                    Page.Run(Page::"Sales Order List", SalesHeader);
                end;
            'SALES_HEADERS_MISSING_PAYMENT_TERMS',
            'SALES_HEADERS_MISSING_PAYMENT_METHOD',
            'SALES_HEADERS_MISSING_REQUESTED_DELIVERY_DATE',
            'SALES_HEADERS_MISSING_SHIPMENT_METHOD',
            'SALES_HEADERS_MISSING_EXTERNAL_DOC_NO',
            'SALES_HEADERS_PAST_REQUESTED_DELIVERY_DATE':
                begin
                    PrepareSalesHeaderIssue(SalesHeader, IssueCodeUpper);
                    Page.Run(Page::"Sales Order List", SalesHeader);
                end;
            'SALES_LINES_ZERO_QUANTITY',
            'SALES_LINES_ZERO_PRICE',
            'SALES_LINES_MISSING_DIMENSIONS',
            'SALES_LINES_MISSING_NO',
            'SALES_LINES_WITH_BLOCKED_ITEMS',
            'SALES_LINES_DISCOUNT_OVER_25',
            'SALES_LINES_DISCOUNT_OVER_50',
            'SALES_LINES_PRICE_BELOW_UNIT_COST',
            'SALES_LINES_SHIPPED_NOT_INVOICED',
            'SALES_LINES_OUTSTANDING_PAST_SHIPMENT_DATE',
            'SALES_LINES_MISSING_DESCRIPTION',
            'SALES_LINES_MISSING_LOCATION':
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
            'PURCHASE_DOCS_WITH_BLOCKED_VENDORS',
            'BLOCKED_VENDORS_WITH_OPEN_PURCHASE_DOCS':
                begin
                    PrepareBlockedVendorPurchaseOrders(PurchaseHeader);
                    Page.Run(Page::"Purchase Order List", PurchaseHeader);
                end;
            'PURCHASE_HEADERS_MISSING_PAYMENT_TERMS',
            'PURCHASE_HEADERS_MISSING_PAYMENT_METHOD',
            'PURCHASE_HEADERS_MISSING_PURCHASER',
            'PURCHASE_HEADERS_MISSING_VENDOR_INVOICE_NO',
            'PURCHASE_HEADERS_PAST_EXPECTED_RECEIPT_DATE':
                begin
                    PreparePurchaseHeaderIssue(PurchaseHeader, IssueCodeUpper);
                    Page.Run(Page::"Purchase Order List", PurchaseHeader);
                end;
            'PURCHASE_LINES_ZERO_QUANTITY',
            'PURCHASE_LINES_ZERO_COST',
            'PURCHASE_LINES_MISSING_DIMENSIONS',
            'PURCHASE_LINES_MISSING_NO',
            'PURCHASE_LINES_WITH_BLOCKED_ITEMS',
            'PURCHASE_LINES_DISCOUNT_OVER_25',
            'PURCHASE_LINES_DISCOUNT_OVER_50',
            'PURCHASE_LINES_RECEIVED_NOT_INVOICED',
            'PURCHASE_LINES_OUTSTANDING_PAST_RECEIPT_DATE',
            'PURCHASE_LINES_MISSING_DESCRIPTION',
            'PURCHASE_LINES_MISSING_LOCATION',
            'PURCHASE_LINES_COST_BELOW_LAST_DIRECT_COST':
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
            'CUSTOMER_LEDGER_OVERDUE_60':
                begin
                    CustomerLedgerEntry.SetRange(Open, true);
                    CustomerLedgerEntry.SetFilter("Due Date", '<>%1&<=%2', 0D, CalcDate('<-60D>', Today));
                    Page.Run(Page::"Customer Ledger Entries", CustomerLedgerEntry);
                end;
            'CUSTOMER_LEDGER_OVERDUE_90':
                begin
                    CustomerLedgerEntry.SetRange(Open, true);
                    CustomerLedgerEntry.SetFilter("Due Date", '<>%1&<=%2', 0D, CalcDate('<-90D>', Today));
                    Page.Run(Page::"Customer Ledger Entries", CustomerLedgerEntry);
                end;
            'CUSTOMER_LEDGER_MISSING_DUE_DATE':
                begin
                    CustomerLedgerEntry.SetRange(Open, true);
                    CustomerLedgerEntry.SetRange("Due Date", 0D);
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
            'VENDOR_LEDGER_OVERDUE_60':
                begin
                    VendorLedgerEntry.SetRange(Open, true);
                    VendorLedgerEntry.SetFilter("Due Date", '<>%1&<=%2', 0D, CalcDate('<-60D>', Today));
                    Page.Run(Page::"Vendor Ledger Entries", VendorLedgerEntry);
                end;
            'VENDOR_LEDGER_OVERDUE_90':
                begin
                    VendorLedgerEntry.SetRange(Open, true);
                    VendorLedgerEntry.SetFilter("Due Date", '<>%1&<=%2', 0D, CalcDate('<-90D>', Today));
                    Page.Run(Page::"Vendor Ledger Entries", VendorLedgerEntry);
                end;
            'VENDOR_LEDGER_MISSING_DUE_DATE':
                begin
                    VendorLedgerEntry.SetRange(Open, true);
                    VendorLedgerEntry.SetRange("Due Date", 0D);
                    Page.Run(Page::"Vendor Ledger Entries", VendorLedgerEntry);
                end;
            'BLOCKED_VENDORS_WITH_OPEN_LEDGER':
                begin
                    PrepareBlockedVendorLedgerEntries(VendorLedgerEntry);
                    Page.Run(Page::"Vendor Ledger Entries", VendorLedgerEntry);
                end;
            'GL_ENTRIES_MISSING_DIM1':
                begin
                    GLEntry.SetRange("Global Dimension 1 Code", '');
                    Page.Run(Page::"General Ledger Entries", GLEntry);
                end;
            'GL_ENTRIES_MISSING_DIM2':
                begin
                    GLEntry.SetRange("Global Dimension 2 Code", '');
                    Page.Run(Page::"General Ledger Entries", GLEntry);
                end;
            'GL_ENTRIES_MISSING_BOTH_DIMS':
                begin
                    GLEntry.SetRange("Global Dimension 1 Code", '');
                    GLEntry.SetRange("Global Dimension 2 Code", '');
                    Page.Run(Page::"General Ledger Entries", GLEntry);
                end;
            'GL_ACCOUNTS_BLOCKED_BUT_USED',
            'GL_ACCOUNTS_NO_DIRECT_POSTING_BUT_USED':
                begin
                    PrepareGLAccountIssue(GLAccount, IssueCodeUpper);
                    Page.Run(Page::"G/L Account List", GLAccount);
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
                        if TryOpenItemIssue(IssueCodeUpper, Item) then
                            Page.Run(Page::"Item List", Item)
                        else
                            if TryOpenContactIssue(IssueCodeUpper, Contact) then
                                Page.Run(Page::"Contact List", Contact)
                            else
                                if TryOpenEmployeeIssue(IssueCodeUpper, Employee) then
                                    Page.Run(Page::"Employee List", Employee)
                                else
                                    if TryOpenResourceIssue(IssueCodeUpper, ResourceRec) then
                                        Page.Run(Page::"Resource List", ResourceRec)
                                    else
                                        if TryOpenServiceItemIssue(IssueCodeUpper, ServiceItem) then
                                            Page.Run(Page::"Service Item List", ServiceItem)
                                        else
                                            if TryOpenServiceHeaderIssue(IssueCodeUpper, ServiceHeader) then
                                                Page.Run(0, ServiceHeader)
                                            else
                                                if TryOpenServiceLineIssue(IssueCodeUpper, ServiceLine) then
                                                    Page.Run(0, ServiceLine)
                                                else
                                                    if TryOpenJobIssue(IssueCodeUpper, JobRec) then
                                                        Page.Run(Page::"Job List", JobRec)
                                                    else
                                                        if TryOpenJobTaskIssue(IssueCodeUpper, JobTask) then
                                                            Page.Run(0, JobTask)
                                                        else
                                                            if TryOpenJobPlanningLineIssue(IssueCodeUpper, JobPlanningLine) then
                                                                Page.Run(0, JobPlanningLine)
                                                            else
                                                                if TryOpenProductionBOMIssue(IssueCodeUpper, ProdBOMHeader) then
                                                                    Page.Run(0, ProdBOMHeader)
                                                                else
                                                                    if TryOpenProductionBOMLineIssue(IssueCodeUpper, ProdBOMLine) then
                                                                        Page.Run(0, ProdBOMLine)
                                                                    else
                                                                        if TryOpenRoutingIssue(IssueCodeUpper, RoutingHeader) then
                                                                            Page.Run(0, RoutingHeader)
                                                                        else
                                                                            if TryOpenRoutingLineIssue(IssueCodeUpper, RoutingLine) then
                                                                                Page.Run(0, RoutingLine)
                                                                            else
                                                                                if TryOpenWorkCenterIssue(IssueCodeUpper, WorkCenter) then
                                                                                    Page.Run(0, WorkCenter)
                                                                                else
                                                                                    if TryOpenMachineCenterIssue(IssueCodeUpper, MachineCenter) then
                                                                                        Page.Run(0, MachineCenter)
                                                                                    else
                                                                                        Message(
                                                                                          'FÃ¼r den Issue-Code %1 ist aktuell noch keine direkte Bearbeitungsliste hinterlegt.',
                                                                                          IssueCode);
        end;
    end;

    local procedure TryOpenItemIssue(IssueCodeUpper: Text; var Item: Record Item): Boolean
    begin
        Item.Reset();
        Item.MarkedOnly(false);

        case IssueCodeUpper of
            'ITEMS_MISSING_DESCRIPTION':
                Item.SetRange(Description, '');
            'ITEMS_MISSING_CATEGORY':
                Item.SetRange("Item Category Code", '');
            'ITEMS_MISSING_BASE_UNIT',
            'ITEMS_MISSING_BASE_UOM':
                Item.SetRange("Base Unit of Measure", '');
            'ITEMS_MISSING_GEN_PROD_POSTING_GROUP',
            'ITEMS_MISSING_GEN_PROD_POSTING',
            'SYSTEM_ITEMS_MISSING_GEN_PROD_POSTING':
                Item.SetRange("Gen. Prod. Posting Group", '');
            'ITEMS_MISSING_INVENTORY_POSTING_GROUP',
            'ITEMS_MISSING_INVENTORY_POSTING',
            'SYSTEM_ITEMS_MISSING_INVENTORY_POSTING':
                Item.SetRange("Inventory Posting Group", '');
            'ITEMS_MISSING_VAT_PROD_POSTING_GROUP':
                Item.SetRange("VAT Prod. Posting Group", '');
            'ITEMS_MISSING_VENDOR_NO',
            'ITEMS_WITHOUT_VENDOR_NO':
                Item.SetRange("Vendor No.", '');
            'ITEMS_MISSING_SHELF_NO':
                Item.SetRange("Shelf No.", '');
            'ITEMS_MISSING_TARIFF_NO':
                Item.SetRange("Tariff No.", '');
            'ITEMS_STANDARD_COST_ZERO':
                Item.SetRange("Standard Cost", 0);
            'ITEMS_LAST_DIRECT_COST_ZERO':
                Item.SetRange("Last Direct Cost", 0);
            'ITEMS_SAFETY_STOCK_ZERO':
                Item.SetRange("Safety Stock Quantity", 0);
            'ITEMS_REORDER_POINT_ZERO':
                Item.SetRange("Reorder Point", 0);
            'ITEMS_MAX_INVENTORY_ZERO':
                Item.SetRange("Maximum Inventory", 0);
            'ITEMS_MIN_ORDER_QTY_ZERO':
                Item.SetRange("Minimum Order Quantity", 0);
            'ITEMS_ORDER_MULTIPLE_ZERO':
                Item.SetRange("Order Multiple", 0);
            'ITEMS_GROSS_WEIGHT_ZERO':
                Item.SetRange("Gross Weight", 0);
            'ITEMS_NET_WEIGHT_ZERO':
                Item.SetRange("Net Weight", 0);
            'ITEMS_UNIT_VOLUME_ZERO':
                Item.SetRange("Unit Volume", 0);
            'ITEMS_MISSING_LEAD_TIME':
                MarkItemsForMissingLeadTime(Item);
            'ITEMS_PRICE_BELOW_UNIT_COST':
                MarkItemsForPriceBelowUnitCost(Item);
            'ITEMS_PRICE_BELOW_STANDARD_COST':
                MarkItemsForPriceBelowStandardCost(Item);
            'INVENTORY_WITHOUT_UNIT_COST':
                MarkItemsForInventoryWithoutUnitCost(Item);
            'DEAD_STOCK_90':
                MarkDeadStockItems(Item, 90);
            'DEAD_STOCK_180':
                MarkDeadStockItems(Item, 180);
            'DEAD_STOCK_365':
                MarkDeadStockItems(Item, 365);
            'MFG_ITEMS_MISSING_PROD_BOM_NO':
                begin
                    Item.SetFilter("Routing No.", '<>%1', '');
                    Item.SetRange("Production BOM No.", '');
                end;
            'MFG_ITEMS_MISSING_ROUTING_NO':
                begin
                    Item.SetFilter("Production BOM No.", '<>%1', '');
                    Item.SetRange("Routing No.", '');
                end;
            else
                exit(false);
        end;

        exit(true);
    end;

    local procedure TryOpenCustomerIssue(IssueCodeUpper: Text; var Customer: Record Customer): Boolean
    begin
        Customer.Reset();

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
            'CUSTOMERS_MISSING_GEN_BUS_POSTING',
            'SYSTEM_CUSTOMERS_MISSING_GEN_BUS_POSTING':
                Customer.SetRange("Gen. Bus. Posting Group", '');
            'CUSTOMERS_MISSING_VAT_BUS_POSTING',
            'SYSTEM_CUSTOMERS_MISSING_VAT_BUS_POSTING':
                Customer.SetRange("VAT Bus. Posting Group", '');
            'CUSTOMERS_MISSING_CREDIT_LIMIT':
                Customer.SetRange("Credit Limit (LCY)", 0);
            'CUSTOMERS_MISSING_VAT_REG_NO':
                Customer.SetRange("VAT Registration No.", '');
            'CUSTOMERS_MISSING_SALESPERSON':
                Customer.SetRange("Salesperson Code", '');
            'CUSTOMERS_MISSING_PRICE_GROUP':
                Customer.SetRange("Customer Price Group", '');
            'CUSTOMERS_MISSING_DISC_GROUP':
                Customer.SetRange("Customer Disc. Group", '');
            'CUSTOMERS_MISSING_REMINDER_TERMS':
                Customer.SetRange("Reminder Terms Code", '');
            'CUSTOMERS_MISSING_FIN_CHARGE_TERMS':
                Customer.SetRange("Fin. Charge Terms Code", '');
            'CUSTOMERS_MISSING_CONTACT':
                Customer.SetRange(Contact, '');
            'CUSTOMERS_MISSING_HOME_PAGE':
                Customer.SetRange("Home Page", '');
            else
                exit(false);
        end;

        exit(true);
    end;

    local procedure TryOpenVendorIssue(IssueCodeUpper: Text; var Vendor: Record Vendor): Boolean
    begin
        Vendor.Reset();

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
            'VENDORS_MISSING_GEN_BUS_POSTING',
            'SYSTEM_VENDORS_MISSING_GEN_BUS_POSTING':
                Vendor.SetRange("Gen. Bus. Posting Group", '');
            'VENDORS_MISSING_VAT_BUS_POSTING',
            'SYSTEM_VENDORS_MISSING_VAT_BUS_POSTING':
                Vendor.SetRange("VAT Bus. Posting Group", '');
            'VENDORS_MISSING_BANK_ACCOUNT':
                Vendor.SetRange("Preferred Bank Account Code", '');
            'VENDORS_MISSING_VAT_REG_NO':
                Vendor.SetRange("VAT Registration No.", '');
            'VENDORS_MISSING_PURCHASER':
                Vendor.SetRange("Purchaser Code", '');
            'VENDORS_MISSING_CONTACT':
                Vendor.SetRange(Contact, '');
            'VENDORS_MISSING_HOME_PAGE':
                Vendor.SetRange("Home Page", '');
            else
                exit(false);
        end;

        exit(true);
    end;

    local procedure TryOpenContactIssue(IssueCodeUpper: Text; var Contact: Record Contact): Boolean
    begin
        Contact.Reset();

        case IssueCodeUpper of
            'CONTACTS_MISSING_NAME':
                Contact.SetRange(Name, '');
            'CONTACTS_MISSING_EMAIL':
                Contact.SetRange("E-Mail", '');
            'CONTACTS_MISSING_PHONE':
                Contact.SetRange("Phone No.", '');
            'CONTACTS_MISSING_MOBILE_PHONE':
                Contact.SetRange("Mobile Phone No.", '');
            'CONTACTS_PERSONS_MISSING_COMPANY':
                begin
                    Contact.SetRange(Type, Contact.Type::Person);
                    Contact.SetRange("Company No.", '');
                end;
            'CONTACTS_MISSING_ADDRESS':
                Contact.SetRange(Address, '');
            'CONTACTS_MISSING_CITY':
                Contact.SetRange(City, '');
            'CONTACTS_MISSING_POST_CODE':
                Contact.SetRange("Post Code", '');
            'CONTACTS_MISSING_COUNTRY':
                Contact.SetRange("Country/Region Code", '');
            else
                exit(false);
        end;

        exit(true);
    end;

    local procedure TryOpenEmployeeIssue(IssueCodeUpper: Text; var Employee: Record Employee): Boolean
    begin
        Employee.Reset();

        case IssueCodeUpper of
            'EMPLOYEES_MISSING_FIRST_NAME':
                Employee.SetRange("First Name", '');
            'EMPLOYEES_MISSING_LAST_NAME':
                Employee.SetRange("Last Name", '');
            'EMPLOYEES_MISSING_SEARCH_NAME':
                Employee.SetRange("Search Name", '');
            'EMPLOYEES_MISSING_EMAIL':
                Employee.SetRange("E-Mail", '');
            'EMPLOYEES_MISSING_PHONE':
                Employee.SetRange("Phone No.", '');
            'EMPLOYEES_MISSING_COUNTRY':
                Employee.SetRange("Country/Region Code", '');
            'EMPLOYEES_MISSING_RESOURCE_NO':
                Employee.SetRange("Resource No.", '');
            'EMPLOYEES_MISSING_JOB_TITLE':
                Employee.SetRange("Job Title", '');
            else
                exit(false);
        end;

        exit(true);
    end;

    local procedure TryOpenResourceIssue(IssueCodeUpper: Text; var ResourceRec: Record Resource): Boolean
    begin
        ResourceRec.Reset();

        case IssueCodeUpper of
            'RESOURCES_MISSING_NAME':
                ResourceRec.SetRange(Name, '');
            'RESOURCES_ZERO_UNIT_COST':
                ResourceRec.SetRange("Unit Cost", 0);
            'RESOURCES_ZERO_UNIT_PRICE':
                ResourceRec.SetRange("Unit Price", 0);
            'RESOURCES_MISSING_BASE_UOM':
                ResourceRec.SetRange("Base Unit of Measure", '');
            else
                exit(false);
        end;

        exit(true);
    end;

    local procedure TryOpenServiceItemIssue(IssueCodeUpper: Text; var ServiceItem: Record "Service Item"): Boolean
    begin
        ServiceItem.Reset();

        case IssueCodeUpper of
            'SERVICE_ITEMS_MISSING_DESCRIPTION':
                ServiceItem.SetRange(Description, '');
            'SERVICE_ITEMS_MISSING_CUSTOMER':
                ServiceItem.SetRange("Customer No.", '');
            'SERVICE_ITEMS_MISSING_ITEM_NO':
                ServiceItem.SetRange("Item No.", '');
            'SERVICE_ITEMS_MISSING_SERIAL_NO':
                ServiceItem.SetRange("Serial No.", '');
            else
                exit(false);
        end;

        exit(true);
    end;

    local procedure TryOpenServiceHeaderIssue(IssueCodeUpper: Text; var ServiceHeader: Record "Service Header"): Boolean
    begin
        ServiceHeader.Reset();

        case IssueCodeUpper of
            'SERVICE_ORDERS_MISSING_CUSTOMER':
                ServiceHeader.SetRange("Customer No.", '');
            'SERVICE_ORDERS_MISSING_BILL_TO':
                ServiceHeader.SetRange("Bill-to Customer No.", '');
            'SERVICE_ORDERS_MISSING_DESCRIPTION':
                ServiceHeader.SetRange(Description, '');
            'SERVICE_ORDERS_MISSING_ASSIGNED_USER':
                ServiceHeader.SetRange("Assigned User ID", '');
            else
                exit(false);
        end;

        exit(true);
    end;

    local procedure TryOpenServiceLineIssue(IssueCodeUpper: Text; var ServiceLine: Record "Service Line"): Boolean
    begin
        ServiceLine.Reset();

        case IssueCodeUpper of
            'SERVICE_LINES_MISSING_NO':
                begin
                    ServiceLine.SetRange("No.", '');
                end;
            'SERVICE_LINES_MISSING_DESCRIPTION':
                begin
                    ServiceLine.SetRange(Description, '');
                end;
            'SERVICE_LINES_ZERO_QTY':
                begin
                    ServiceLine.SetRange(Quantity, 0);
                end;
            'SERVICE_LINES_ZERO_UNIT_PRICE':
                begin
                    ServiceLine.SetRange("Unit Price", 0);
                end;
            else
                exit(false);
        end;

        exit(true);
    end;

    local procedure TryOpenJobIssue(IssueCodeUpper: Text; var JobRec: Record Job): Boolean
    begin
        JobRec.Reset();

        case IssueCodeUpper of
            'JOBS_MISSING_DESCRIPTION':
                JobRec.SetRange(Description, '');
            'JOBS_MISSING_BILL_TO_CUSTOMER':
                JobRec.SetRange("Bill-to Customer No.", '');
            'JOBS_MISSING_RESPONSIBLE':
                JobRec.SetRange("Person Responsible", '');
            'JOBS_MISSING_POSTING_GROUP':
                JobRec.SetRange("Job Posting Group", '');
            else
                exit(false);
        end;

        exit(true);
    end;

    local procedure TryOpenJobTaskIssue(IssueCodeUpper: Text; var JobTask: Record "Job Task"): Boolean
    begin
        JobTask.Reset();

        case IssueCodeUpper of
            'JOB_TASKS_MISSING_DESCRIPTION':
                JobTask.SetRange(Description, '');
            else
                exit(false);
        end;

        exit(true);
    end;

    local procedure TryOpenJobPlanningLineIssue(IssueCodeUpper: Text; var JobPlanningLine: Record "Job Planning Line"): Boolean
    begin
        JobPlanningLine.Reset();

        case IssueCodeUpper of
            'JOB_PLANNING_LINES_MISSING_NO':
                begin
                    JobPlanningLine.SetRange("No.", '');
                end;
            'JOB_PLANNING_LINES_MISSING_DESCRIPTION':
                begin
                    JobPlanningLine.SetRange(Description, '');
                end;
            'JOB_PLANNING_LINES_ZERO_QTY':
                begin
                    JobPlanningLine.SetRange(Quantity, 0);
                end;
            'JOB_PLANNING_LINES_ZERO_UNIT_COST':
                begin
                    JobPlanningLine.SetRange("Unit Cost", 0);
                end;
            'JOB_PLANNING_LINES_ZERO_UNIT_PRICE':
                begin
                    JobPlanningLine.SetRange("Unit Price", 0);
                end;
            else
                exit(false);
        end;

        exit(true);
    end;

    local procedure TryOpenProductionBOMIssue(IssueCodeUpper: Text; var ProdBOMHeader: Record "Production BOM Header"): Boolean
    begin
        ProdBOMHeader.Reset();

        case IssueCodeUpper of
            'MFG_BOM_MISSING_DESCRIPTION':
                ProdBOMHeader.SetRange(Description, '');
            'MFG_BOM_NOT_CERTIFIED':
                ProdBOMHeader.SetFilter(Status, '<>%1', ProdBOMHeader.Status::Certified);
            else
                exit(false);
        end;

        exit(true);
    end;

    local procedure TryOpenProductionBOMLineIssue(IssueCodeUpper: Text; var ProdBOMLine: Record "Production BOM Line"): Boolean
    begin
        ProdBOMLine.Reset();

        case IssueCodeUpper of
            'MFG_BOM_LINES_MISSING_NO':
                begin
                    ProdBOMLine.SetRange("No.", '');
                end;
            'MFG_BOM_LINES_ZERO_QTY':
                ProdBOMLine.SetRange(Quantity, 0);
            else
                exit(false);
        end;

        exit(true);
    end;

    local procedure TryOpenRoutingIssue(IssueCodeUpper: Text; var RoutingHeader: Record "Routing Header"): Boolean
    begin
        RoutingHeader.Reset();

        case IssueCodeUpper of
            'MFG_ROUTING_MISSING_DESCRIPTION':
                RoutingHeader.SetRange(Description, '');
            'MFG_ROUTING_NOT_CERTIFIED':
                RoutingHeader.SetFilter(Status, '<>%1', RoutingHeader.Status::Certified);
            else
                exit(false);
        end;

        exit(true);
    end;

    local procedure TryOpenRoutingLineIssue(IssueCodeUpper: Text; var RoutingLine: Record "Routing Line"): Boolean
    begin
        RoutingLine.Reset();

        case IssueCodeUpper of
            'MFG_ROUTING_LINES_MISSING_NO':
                begin
                    RoutingLine.SetRange("No.", '');
                end;
            'MFG_ROUTING_LINES_ZERO_SETUP':
                RoutingLine.SetRange("Setup Time", 0);
            'MFG_ROUTING_LINES_ZERO_RUN':
                RoutingLine.SetRange("Run Time", 0);
            else
                exit(false);
        end;

        exit(true);
    end;

    local procedure TryOpenWorkCenterIssue(IssueCodeUpper: Text; var WorkCenter: Record "Work Center"): Boolean
    begin
        WorkCenter.Reset();

        case IssueCodeUpper of
            'MFG_WORK_CENTERS_BLOCKED':
                WorkCenter.SetRange(Blocked, true);
            'MFG_WORK_CENTERS_MISSING_NAME':
                WorkCenter.SetRange(Name, '');
            'MFG_WORK_CENTERS_ZERO_COST':
                WorkCenter.SetRange("Unit Cost", 0);
            else
                exit(false);
        end;

        exit(true);
    end;

    local procedure TryOpenMachineCenterIssue(IssueCodeUpper: Text; var MachineCenter: Record "Machine Center"): Boolean
    begin
        MachineCenter.Reset();

        case IssueCodeUpper of
            'MFG_MACHINE_CENTERS_BLOCKED':
                MachineCenter.SetRange(Blocked, true);
            'MFG_MACHINE_CENTERS_MISSING_NAME':
                MachineCenter.SetRange(Name, '');
            'MFG_MACHINE_CENTERS_ZERO_COST':
                MachineCenter.SetRange("Unit Cost", 0);
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

    local procedure PrepareSalesHeaderIssue(var SalesHeader: Record "Sales Header"; IssueCodeUpper: Text)
    begin
        SalesHeader.Reset();
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);

        case IssueCodeUpper of
            'SALES_HEADERS_MISSING_PAYMENT_TERMS':
                SalesHeader.SetRange("Payment Terms Code", '');
            'SALES_HEADERS_MISSING_PAYMENT_METHOD':
                SalesHeader.SetRange("Payment Method Code", '');
            'SALES_HEADERS_MISSING_REQUESTED_DELIVERY_DATE':
                SalesHeader.SetRange("Requested Delivery Date", 0D);
            'SALES_HEADERS_MISSING_SHIPMENT_METHOD':
                SalesHeader.SetRange("Shipment Method Code", '');
            'SALES_HEADERS_MISSING_EXTERNAL_DOC_NO':
                SalesHeader.SetRange("External Document No.", '');
            'SALES_HEADERS_PAST_REQUESTED_DELIVERY_DATE':
                SalesHeader.SetFilter("Requested Delivery Date", '<>%1&<%2', 0D, Today);
        end;
    end;

    local procedure PreparePurchaseHeaderIssue(var PurchaseHeader: Record "Purchase Header"; IssueCodeUpper: Text)
    begin
        PurchaseHeader.Reset();
        PurchaseHeader.SetRange("Document Type", PurchaseHeader."Document Type"::Order);

        case IssueCodeUpper of
            'PURCHASE_HEADERS_MISSING_PAYMENT_TERMS':
                PurchaseHeader.SetRange("Payment Terms Code", '');
            'PURCHASE_HEADERS_MISSING_PAYMENT_METHOD':
                PurchaseHeader.SetRange("Payment Method Code", '');
            'PURCHASE_HEADERS_MISSING_PURCHASER':
                PurchaseHeader.SetRange("Purchaser Code", '');
            'PURCHASE_HEADERS_MISSING_VENDOR_INVOICE_NO':
                PurchaseHeader.SetRange("Vendor Invoice No.", '');
            'PURCHASE_HEADERS_PAST_EXPECTED_RECEIPT_DATE':
                PurchaseHeader.SetFilter("Expected Receipt Date", '<>%1&<%2', 0D, Today);
        end;
    end;

    local procedure PrepareGLAccountIssue(var GLAccount: Record "G/L Account"; IssueCodeUpper: Text)
    begin
        GLAccount.Reset();
        GLAccount.MarkedOnly(false);
        if GLAccount.FindSet() then
            repeat
                case IssueCodeUpper of
                    'GL_ACCOUNTS_BLOCKED_BUT_USED':
                        if GLAccount.Blocked and HasGLEntriesForAccount(GLAccount."No.") then
                            GLAccount.Mark(true);
                    'GL_ACCOUNTS_NO_DIRECT_POSTING_BUT_USED':
                        if (not GLAccount."Direct Posting") and HasGLEntriesForAccount(GLAccount."No.") then
                            GLAccount.Mark(true);
                end;
            until GLAccount.Next() = 0;
        GLAccount.MarkedOnly(true);
    end;

    local procedure MarkItemsForMissingLeadTime(var Item: Record Item)
    begin
        Item.Reset();
        Item.MarkedOnly(false);
        if Item.FindSet() then
            repeat
                if Format(Item."Lead Time Calculation") = '' then
                    Item.Mark(true);
            until Item.Next() = 0;
        Item.MarkedOnly(true);
    end;

    local procedure MarkItemsForPriceBelowUnitCost(var Item: Record Item)
    begin
        Item.Reset();
        Item.MarkedOnly(false);
        if Item.FindSet() then
            repeat
                if (Item."Unit Price" > 0) and (Item."Unit Cost" > 0) and (Item."Unit Price" < Item."Unit Cost") then
                    Item.Mark(true);
            until Item.Next() = 0;
        Item.MarkedOnly(true);
    end;

    local procedure MarkItemsForPriceBelowStandardCost(var Item: Record Item)
    begin
        Item.Reset();
        Item.MarkedOnly(false);
        if Item.FindSet() then
            repeat
                if (Item."Unit Price" > 0) and (Item."Standard Cost" > 0) and (Item."Unit Price" < Item."Standard Cost") then
                    Item.Mark(true);
            until Item.Next() = 0;
        Item.MarkedOnly(true);
    end;

    local procedure MarkItemsForInventoryWithoutUnitCost(var Item: Record Item)
    begin
        Item.Reset();
        Item.MarkedOnly(false);
        if Item.FindSet() then
            repeat
                Item.CalcFields(Inventory);
                if (Item.Inventory > 0) and (Item."Unit Cost" = 0) then
                    Item.Mark(true);
            until Item.Next() = 0;
        Item.MarkedOnly(true);
    end;

    local procedure MarkDeadStockItems(var Item: Record Item; DaysWithoutMovement: Integer)
    var
        LastMovementDate: Date;
        ThresholdDate: Date;
    begin
        ThresholdDate := CalcDate(StrSubstNo('<-%1D>', DaysWithoutMovement), Today);
        Item.Reset();
        Item.MarkedOnly(false);
        if Item.FindSet() then
            repeat
                Item.CalcFields(Inventory);
                LastMovementDate := GetLastItemMovementDate(Item."No.");
                if (Item.Inventory > 0) and (LastMovementDate <> 0D) and (LastMovementDate <= ThresholdDate) then
                    Item.Mark(true);
            until Item.Next() = 0;
        Item.MarkedOnly(true);
    end;

    local procedure GetLastItemMovementDate(ItemNo: Code[20]): Date
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        ItemLedgerEntry.SetCurrentKey("Item No.", "Posting Date");
        ItemLedgerEntry.SetRange("Item No.", ItemNo);
        if ItemLedgerEntry.FindLast() then
            exit(ItemLedgerEntry."Posting Date");

        exit(0D);
    end;

    local procedure HasGLEntriesForAccount(GLAccountNo: Code[20]): Boolean
    var
        GLEntry: Record "G/L Entry";
    begin
        GLEntry.SetRange("G/L Account No.", GLAccountNo);
        exit(not GLEntry.IsEmpty());
    end;
}
