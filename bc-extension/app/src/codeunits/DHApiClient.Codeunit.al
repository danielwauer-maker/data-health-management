codeunit 53100 "DH API Client"
{
    procedure TestConnection(var Setup: Record "DH Setup")
    var
        Client: HttpClient;
        Response: HttpResponseMessage;
        ResponseText: Text;
        JsonResponse: JsonObject;
        Token: JsonToken;
        ServiceName: Text;
        VersionText: Text;
        StatusText: Text;
    begin
        EnsureApiBaseUrlConfigured(Setup);

        AddPublicHeaders(Client);

        if not Client.Get(BuildUrl(Setup."API Base URL", '/health'), Response) then
            Error('The backend request could not be sent. Please verify the API Base URL and your network connection.');

        Response.Content().ReadAs(ResponseText);

        if not Response.IsSuccessStatusCode() then
            Error('Backend connection test failed. Status %1 - %2', Response.HttpStatusCode(), ResponseText);

        if not JsonResponse.ReadFrom(ResponseText) then
            Error('The backend returned an invalid JSON response: %1', ResponseText);

        if JsonResponse.Get('service', Token) then
            if not IsJsonNull(Token) then
                ServiceName := Token.AsValue().AsText();

        if JsonResponse.Get('version', Token) then
            if not IsJsonNull(Token) then
                VersionText := Token.AsValue().AsText();

        if JsonResponse.Get('status', Token) then
            if not IsJsonNull(Token) then
                StatusText := Token.AsValue().AsText();

        if ServiceName = '' then
            ServiceName := 'Backend';
        if VersionText = '' then
            VersionText := 'unknown';
        if StatusText = '' then
            StatusText := 'unknown';

        Message(
            'Backend reachable.\Service: %1\Status: %2\Version: %3',
            ServiceName,
            StatusText,
            VersionText);
    end;

    procedure RegisterTenant(var Setup: Record "DH Setup")
    var
        Client: HttpClient;
        Content: HttpContent;
        Headers: HttpHeaders;
        Response: HttpResponseMessage;
        RequestText: Text;
        ResponseText: Text;
        JsonRequest: JsonObject;
        JsonResponse: JsonObject;
        Token: JsonToken;
        TenantId: Text;
        ApiToken: Text;
    begin
        EnsureApiBaseUrlConfigured(Setup);

        JsonRequest.Add('environment_name', 'BC Cloud');
        JsonRequest.Add('app_version', '0.4.0');
        JsonRequest.WriteTo(RequestText);

        Content.WriteFrom(RequestText);
        Content.GetHeaders(Headers);
        Headers.Clear();
        Headers.Add('Content-Type', 'application/json');

        AddPublicHeaders(Client);

        if not Client.Post(BuildUrl(Setup."API Base URL", '/tenant/register'), Content, Response) then
            Error('The backend request could not be sent. Please verify the API Base URL and your network connection.');

        Response.Content().ReadAs(ResponseText);

        if not Response.IsSuccessStatusCode() then
            Error('Tenant registration failed. Status %1 - %2', Response.HttpStatusCode(), ResponseText);

        if not JsonResponse.ReadFrom(ResponseText) then
            Error('The backend returned an invalid JSON response: %1', ResponseText);

        if JsonResponse.Get('tenant_id', Token) then
            if not IsJsonNull(Token) then
                TenantId := Token.AsValue().AsText();

        if JsonResponse.Get('api_token', Token) then
            if not IsJsonNull(Token) then
                ApiToken := Token.AsValue().AsText();

        if TenantId = '' then
            Error('The backend response does not contain a tenant_id.');

        if ApiToken = '' then
            Error('The backend response does not contain an api_token.');

        Setup.Validate("Tenant ID", CopyStr(TenantId, 1, MaxStrLen(Setup."Tenant ID")));
        Setup.Validate("API Token", CopyStr(ApiToken, 1, MaxStrLen(Setup."API Token")));
        Setup.Modify(true);

        Message('Tenant successfully registered.');
    end;

    procedure RunQuickScan(var Setup: Record "DH Setup"): Text
    var
        Client: HttpClient;
        Content: HttpContent;
        Headers: HttpHeaders;
        Response: HttpResponseMessage;
        RequestText: Text;
        ResponseText: Text;
        JsonRequest: JsonObject;
        JsonMetrics: JsonObject;
    begin
        EnsureTenantAccessConfigured(Setup);

        JsonRequest.Add('tenant_id', Setup."Tenant ID");

        AddCustomerMetrics(JsonMetrics);
        AddVendorMetrics(JsonMetrics);
        AddItemMetrics(JsonMetrics);

        JsonRequest.Add('metrics', JsonMetrics);
        JsonRequest.WriteTo(RequestText);

        Content.WriteFrom(RequestText);
        Content.GetHeaders(Headers);
        Headers.Clear();
        Headers.Add('Content-Type', 'application/json');

        AddAuthenticatedHeaders(Client, Setup);

        if not Client.Post(BuildUrl(Setup."API Base URL", '/scan/quick'), Content, Response) then
            Error('The backend request could not be sent. Please verify the API Base URL and your network connection.');

        Response.Content().ReadAs(ResponseText);

        if not Response.IsSuccessStatusCode() then
            Error('Quick scan failed. Status %1 - %2', Response.HttpStatusCode(), ResponseText);

        exit(ResponseText);
    end;

    procedure GetScanHistory(var Setup: Record "DH Setup"; Limit: Integer): Text
    var
        Client: HttpClient;
        Response: HttpResponseMessage;
        ResponseText: Text;
        Url: Text;
    begin
        EnsureTenantAccessConfigured(Setup);

        if Limit <= 0 then
            Limit := 10;

        Url := BuildUrl(Setup."API Base URL", '/scan/history/' + Setup."Tenant ID" + '?limit=' + Format(Limit));

        AddAuthenticatedHeaders(Client, Setup);

        if not Client.Get(Url, Response) then
            Error('The backend request could not be sent. Please verify the API Base URL and your network connection.');

        Response.Content().ReadAs(ResponseText);

        if not Response.IsSuccessStatusCode() then
            Error('History request failed. Status %1 - %2', Response.HttpStatusCode(), ResponseText);

        exit(ResponseText);
    end;

    procedure GetScanTrend(var Setup: Record "DH Setup"): Text
    var
        Client: HttpClient;
        Response: HttpResponseMessage;
        Url: Text;
        ResponseText: Text;
    begin
        EnsureTenantAccessConfigured(Setup);

        Url := BuildUrl(Setup."API Base URL", '/scan/trend/' + Setup."Tenant ID");

        AddAuthenticatedHeaders(Client, Setup);

        if not Client.Get(Url, Response) then
            Error('The backend request could not be sent. Please verify the API Base URL and your network connection.');

        Response.Content().ReadAs(ResponseText);

        if not Response.IsSuccessStatusCode() then
            Error('Trend request failed. Status %1 - %2', Response.HttpStatusCode(), ResponseText);

        exit(ResponseText);
    end;

    procedure SyncScanToBackend(var Setup: Record "DH Setup"; RequestText: Text)
    var
        Client: HttpClient;
        Content: HttpContent;
        Headers: HttpHeaders;
        Response: HttpResponseMessage;
        ResponseText: Text;
    begin
        EnsureTenantAccessConfigured(Setup);

        Content.WriteFrom(RequestText);
        Content.GetHeaders(Headers);
        Headers.Clear();
        Headers.Add('Content-Type', 'application/json');

        AddAuthenticatedHeaders(Client, Setup);

        if not Client.Post(BuildUrl(Setup."API Base URL", '/scan/sync'), Content, Response) then
            Error('The backend sync request could not be sent. Please verify the API Base URL and your network connection.');

        Response.Content().ReadAs(ResponseText);

        if not Response.IsSuccessStatusCode() then
            Error('Scan sync failed. Status %1 - %2', Response.HttpStatusCode(), ResponseText);
    end;

    procedure DeleteScanFromBackend(var Setup: Record "DH Setup"; ScanId: Code[50])
    var
        Client: HttpClient;
        Response: HttpResponseMessage;
        ResponseText: Text;
    begin
        EnsureTenantAccessConfigured(Setup);

        AddAuthenticatedHeaders(Client, Setup);

        if not Client.Delete(BuildUrl(Setup."API Base URL", '/scan/' + Format(ScanId)), Response) then
            Error('The backend delete request could not be sent. Please verify the API Base URL and your network connection.');

        Response.Content().ReadAs(ResponseText);

        if not Response.IsSuccessStatusCode() then
            Error('Backend scan delete failed. Status %1 - %2', Response.HttpStatusCode(), ResponseText);
    end;

    local procedure EnsureApiBaseUrlConfigured(var Setup: Record "DH Setup")
    begin
        if Setup."API Base URL" = '' then
            Error('Please configure API Base URL first.');
    end;

    local procedure EnsureTenantAccessConfigured(var Setup: Record "DH Setup")
    begin
        EnsureApiBaseUrlConfigured(Setup);

        if Setup."Tenant ID" = '' then
            Error('Please register the tenant first.');

        if Setup."API Token" = '' then
            Error('The API token is missing. Please register the tenant again.');
    end;

    local procedure AddPublicHeaders(var Client: HttpClient)
    begin
        Client.DefaultRequestHeaders().Add('ngrok-skip-browser-warning', 'true');
    end;

    local procedure AddAuthenticatedHeaders(var Client: HttpClient; var Setup: Record "DH Setup")
    begin
        AddPublicHeaders(Client);
        Client.DefaultRequestHeaders().Add('x-dhm-api-token', Setup."API Token");
    end;

    local procedure BuildUrl(BaseUrl: Text; RelativePath: Text): Text
    begin
        exit(RemoveTrailingSlash(BaseUrl) + RelativePath);
    end;

    local procedure RemoveTrailingSlash(Value: Text): Text
    begin
        while (StrLen(Value) > 0) and (CopyStr(Value, StrLen(Value), 1) = '/') do
            Value := CopyStr(Value, 1, StrLen(Value) - 1);

        exit(Value);
    end;

    local procedure IsJsonNull(Token: JsonToken): Boolean
    var
        JsonValueText: Text;
    begin
        JsonValueText := LowerCase(Format(Token));
        exit((JsonValueText = 'null') or (JsonValueText = '<null>'));
    end;

    local procedure AddCustomerMetrics(var JsonMetrics: JsonObject)
    begin
        JsonMetrics.Add('customers_total', CountCustomers());
        JsonMetrics.Add('customers_missing_postcode', CountCustomersMissingPostCode());
        JsonMetrics.Add('customers_missing_payment_terms', CountCustomersMissingPaymentTerms());
        JsonMetrics.Add('customers_missing_country_code', CountCustomersMissingCountryCode());
        JsonMetrics.Add('customers_missing_vat_reg_no', CountCustomersMissingVATRegNo());
        JsonMetrics.Add('customers_missing_email', CountCustomersMissingEmail());
        JsonMetrics.Add('customers_missing_phone_no', CountCustomersMissingPhoneNo());
        JsonMetrics.Add('customers_missing_customer_posting_group', CountCustomersMissingCustomerPostingGroup());
        JsonMetrics.Add('customers_missing_gen_bus_posting_group', CountCustomersMissingGenBusPostingGroup());
        JsonMetrics.Add('customers_blocked_total', CountBlockedCustomers());
    end;

    local procedure AddVendorMetrics(var JsonMetrics: JsonObject)
    begin
        JsonMetrics.Add('vendors_total', CountVendors());
        JsonMetrics.Add('vendors_missing_payment_terms', CountVendorsMissingPaymentTerms());
        JsonMetrics.Add('vendors_missing_country_code', CountVendorsMissingCountryCode());
        JsonMetrics.Add('vendors_missing_email', CountVendorsMissingEmail());
        JsonMetrics.Add('vendors_missing_phone_no', CountVendorsMissingPhoneNo());
        JsonMetrics.Add('vendors_missing_vendor_posting_group', CountVendorsMissingVendorPostingGroup());
        JsonMetrics.Add('vendors_missing_gen_bus_posting_group', CountVendorsMissingGenBusPostingGroup());
        JsonMetrics.Add('vendors_blocked_total', CountBlockedVendors());
    end;

    local procedure AddItemMetrics(var JsonMetrics: JsonObject)
    begin
        JsonMetrics.Add('items_total', CountItems());
        JsonMetrics.Add('items_missing_category', CountItemsMissingCategory());
        JsonMetrics.Add('items_missing_base_unit', CountItemsMissingBaseUnit());
        JsonMetrics.Add('items_missing_gen_prod_posting_group', CountItemsMissingGenProdPostingGroup());
        JsonMetrics.Add('items_missing_inventory_posting_group', CountItemsMissingInventoryPostingGroup());
        JsonMetrics.Add('items_missing_vat_prod_posting_group', CountItemsMissingVATProdPostingGroup());
        JsonMetrics.Add('items_missing_vendor_no', CountItemsMissingVendorNo());
        JsonMetrics.Add('items_blocked_total', CountBlockedItems());
    end;

    local procedure CountCustomers(): Integer
    var
        Customer: Record Customer;
    begin
        exit(Customer.Count());
    end;

    local procedure CountCustomersMissingPostCode(): Integer
    var
        Customer: Record Customer;
    begin
        Customer.SetRange("Post Code", '');
        exit(Customer.Count());
    end;

    local procedure CountCustomersMissingPaymentTerms(): Integer
    var
        Customer: Record Customer;
    begin
        Customer.SetRange("Payment Terms Code", '');
        exit(Customer.Count());
    end;

    local procedure CountCustomersMissingCountryCode(): Integer
    var
        Customer: Record Customer;
    begin
        Customer.SetRange("Country/Region Code", '');
        exit(Customer.Count());
    end;

    local procedure CountCustomersMissingVATRegNo(): Integer
    var
        Customer: Record Customer;
    begin
        Customer.SetRange("VAT Registration No.", '');
        exit(Customer.Count());
    end;

    local procedure CountCustomersMissingEmail(): Integer
    var
        Customer: Record Customer;
    begin
        Customer.SetRange("E-Mail", '');
        exit(Customer.Count());
    end;

    local procedure CountCustomersMissingPhoneNo(): Integer
    var
        Customer: Record Customer;
    begin
        Customer.SetRange("Phone No.", '');
        exit(Customer.Count());
    end;

    local procedure CountCustomersMissingCustomerPostingGroup(): Integer
    var
        Customer: Record Customer;
    begin
        Customer.SetRange("Customer Posting Group", '');
        exit(Customer.Count());
    end;

    local procedure CountCustomersMissingGenBusPostingGroup(): Integer
    var
        Customer: Record Customer;
    begin
        Customer.SetRange("Gen. Bus. Posting Group", '');
        exit(Customer.Count());
    end;

    local procedure CountBlockedCustomers(): Integer
    var
        Customer: Record Customer;
    begin
        Customer.SetFilter(Blocked, '<>%1', Customer.Blocked::" ");
        exit(Customer.Count());
    end;

    local procedure CountVendors(): Integer
    var
        Vendor: Record Vendor;
    begin
        exit(Vendor.Count());
    end;

    local procedure CountVendorsMissingPaymentTerms(): Integer
    var
        Vendor: Record Vendor;
    begin
        Vendor.SetRange("Payment Terms Code", '');
        exit(Vendor.Count());
    end;

    local procedure CountVendorsMissingCountryCode(): Integer
    var
        Vendor: Record Vendor;
    begin
        Vendor.SetRange("Country/Region Code", '');
        exit(Vendor.Count());
    end;

    local procedure CountVendorsMissingEmail(): Integer
    var
        Vendor: Record Vendor;
    begin
        Vendor.SetRange("E-Mail", '');
        exit(Vendor.Count());
    end;

    local procedure CountVendorsMissingPhoneNo(): Integer
    var
        Vendor: Record Vendor;
    begin
        Vendor.SetRange("Phone No.", '');
        exit(Vendor.Count());
    end;

    local procedure CountVendorsMissingVendorPostingGroup(): Integer
    var
        Vendor: Record Vendor;
    begin
        Vendor.SetRange("Vendor Posting Group", '');
        exit(Vendor.Count());
    end;

    local procedure CountVendorsMissingGenBusPostingGroup(): Integer
    var
        Vendor: Record Vendor;
    begin
        Vendor.SetRange("Gen. Bus. Posting Group", '');
        exit(Vendor.Count());
    end;

    local procedure CountBlockedVendors(): Integer
    var
        Vendor: Record Vendor;
    begin
        Vendor.SetFilter(Blocked, '<>%1', Vendor.Blocked::" ");
        exit(Vendor.Count());
    end;

    local procedure CountItems(): Integer
    var
        Item: Record Item;
    begin
        exit(Item.Count());
    end;

    local procedure CountItemsMissingCategory(): Integer
    var
        Item: Record Item;
    begin
        Item.SetRange("Item Category Code", '');
        exit(Item.Count());
    end;

    local procedure CountItemsMissingBaseUnit(): Integer
    var
        Item: Record Item;
    begin
        Item.SetRange("Base Unit of Measure", '');
        exit(Item.Count());
    end;

    local procedure CountItemsMissingGenProdPostingGroup(): Integer
    var
        Item: Record Item;
    begin
        Item.SetRange("Gen. Prod. Posting Group", '');
        exit(Item.Count());
    end;

    local procedure CountItemsMissingInventoryPostingGroup(): Integer
    var
        Item: Record Item;
    begin
        Item.SetRange("Inventory Posting Group", '');
        exit(Item.Count());
    end;

    local procedure CountItemsMissingVATProdPostingGroup(): Integer
    var
        Item: Record Item;
    begin
        Item.SetRange("VAT Prod. Posting Group", '');
        exit(Item.Count());
    end;

    local procedure CountItemsMissingVendorNo(): Integer
    var
        Item: Record Item;
    begin
        Item.SetRange("Vendor No.", '');
        exit(Item.Count());
    end;

    local procedure CountBlockedItems(): Integer
    var
        Item: Record Item;
    begin
        Item.SetRange(Blocked, true);
        exit(Item.Count());
    end;
}