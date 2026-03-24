codeunit 53100 "DH API Client"
{
    procedure TestConnection(var Setup: Record "DH Setup")
    var
        Client: HttpClient;
        Response: HttpResponseMessage;
        ResponseText: Text;
        JsonResponse: JsonObject;
        Token: JsonToken;
        StatusText: Text;
    begin
        EnsureSetupLoaded(Setup);

        if not Client.Get(BuildUrl(Setup."API Base URL", '/health'), Response) then
            Error('The backend request could not be sent. Please verify the network connection.');

        Response.Content.ReadAs(ResponseText);

        if not Response.IsSuccessStatusCode() then
            Error('Backend connection test failed. Status %1 - %2', Response.HttpStatusCode(), ResponseText);

        if JsonResponse.ReadFrom(ResponseText) then
            if JsonResponse.Get('status', Token) then
                if not IsJsonNull(Token) then
                    StatusText := Token.AsValue().AsText();

        if StatusText = '' then
            StatusText := 'ok';

        Message('BCSentinel backend reachable. Status: %1', StatusText);
    end;

    procedure EnsureTenantRegistered(var Setup: Record "DH Setup")
    begin
        EnsureSetupLoaded(Setup);

        if not Setup."Data Processing Consent" then
            Error('Please enable Data Processing Consent first.');

        if Setup.Registered and (Setup."Tenant ID" <> '') and (Setup."API Token" <> '') then
            exit;

        RegisterTenant(Setup);
        RefreshLicenseStatus(Setup);
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
        EnsureSetupLoaded(Setup);

        JsonRequest.Add('environment_name', 'BC Cloud');
        JsonRequest.Add('app_version', '0.4.0');
        JsonRequest.WriteTo(RequestText);

        Content.WriteFrom(RequestText);
        Content.GetHeaders(Headers);
        Headers.Clear();
        Headers.Add('Content-Type', 'application/json');

        if not Client.Post(BuildUrl(Setup."API Base URL", '/tenant/register'), Content, Response) then
            Error('The backend request could not be sent. Please verify the network connection.');

        Response.Content.ReadAs(ResponseText);

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
        Setup.Registered := true;
        Setup."Registration Date" := CurrentDateTime();
        Setup.Modify(true);
    end;

    procedure RefreshLicenseStatus(var Setup: Record "DH Setup")
    var
        Client: HttpClient;
        Response: HttpResponseMessage;
        ResponseText: Text;
        Headers: HttpHeaders;
        JsonResponse: JsonObject;
        Token: JsonToken;
        FeaturesToken: JsonToken;
        Features: JsonArray;
    begin
        EnsureTenantAccessConfigured(Setup);

        Headers := Client.DefaultRequestHeaders();
        Headers.Clear();
        Headers.Add('X-Tenant-Id', Setup."Tenant ID");
        Headers.Add('X-Api-Token', Setup."API Token");

        if not Client.Get(BuildUrl(Setup."API Base URL", '/license/status'), Response) then
            Error('The backend request could not be sent. Please verify the network connection.');

        Response.Content.ReadAs(ResponseText);

        if not Response.IsSuccessStatusCode() then
            Error('License status request failed. Status %1 - %2', Response.HttpStatusCode(), ResponseText);

        if not JsonResponse.ReadFrom(ResponseText) then
            Error('The backend returned an invalid JSON response: %1', ResponseText);

        if JsonResponse.Get('plan', Token) then
            if not IsJsonNull(Token) then
                Setup."Current Plan" := MapPlan(Token.AsValue().AsText());

        if JsonResponse.Get('license_status', Token) then
            if not IsJsonNull(Token) then
                Setup."License Status" := MapLicenseStatus(Token.AsValue().AsText());

        Setup."Last License Check" := CurrentDateTime();
        Setup."Premium Enabled" := false;

        if JsonResponse.Get('features', FeaturesToken) then begin
            Features := FeaturesToken.AsArray();
            Setup."Premium Enabled" := JsonArrayContainsText(Features, 'deep_scan');
        end else
            Setup."Premium Enabled" := IsPremiumAllowed(Setup);

        Setup.Modify(true);
    end;

    procedure EnsureReadyForScan(var Setup: Record "DH Setup")
    begin
        EnsureTenantRegistered(Setup);
        RefreshLicenseStatus(Setup);
    end;

    procedure IsPremiumAllowed(Setup: Record "DH Setup"): Boolean
    begin
        exit(
            (Setup."Current Plan" = Setup."Current Plan"::Premium) and
            (Setup."License Status" in [Setup."License Status"::Trial, Setup."License Status"::Active]));
    end;

    procedure ExecuteScan(var Setup: Record "DH Setup"; var ScanId: Code[50]; var DataScore: Integer; var IssuesCount: Integer; var UsedPremiumLicense: Boolean): Text
    var
        ResponseText: Text;
        GeneratedAtUtc: DateTime;
    begin
        EnsureReadyForScan(Setup);

        UsedPremiumLicense := Setup."Premium Enabled";

        // Aktuell wird auch im Premium-Fall noch der QuickScan-Endpunkt verwendet,
        // bis der echte DeepScan-Endpunkt angebunden ist.
        ResponseText := RunQuickScan(Setup);

        ParseScanResponse(ResponseText, ScanId, DataScore, IssuesCount, GeneratedAtUtc);
        UpdateSetupFromScanResult(Setup, DataScore, GeneratedAtUtc);

        exit(ResponseText);
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
        DataProfilingMgt: Codeunit "DH Data Profiling Mgt.";
        DataProfile: JsonObject;
    begin
        EnsureReadyForScan(Setup);

        JsonRequest.Add('tenant_id', Setup."Tenant ID");
        AddCustomerMetrics(JsonMetrics);
        AddVendorMetrics(JsonMetrics);
        AddItemMetrics(JsonMetrics);
        JsonRequest.Add('metrics', JsonMetrics);

        DataProfile := DataProfilingMgt.BuildDataProfile();
        JsonRequest.Add('data_profile', DataProfile);

        JsonRequest.WriteTo(RequestText);

        Content.WriteFrom(RequestText);
        Content.GetHeaders(Headers);
        Headers.Clear();
        Headers.Add('Content-Type', 'application/json');

        Headers := Client.DefaultRequestHeaders();
        Headers.Clear();
        Headers.Add('X-Tenant-Id', Setup."Tenant ID");
        Headers.Add('X-Api-Token', Setup."API Token");

        if not Client.Post(BuildUrl(Setup."API Base URL", '/scan/quick'), Content, Response) then
            Error('The backend request could not be sent. Please verify the network connection.');

        Response.Content.ReadAs(ResponseText);

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
        Headers: HttpHeaders;
    begin
        EnsureReadyForScan(Setup);

        if Limit <= 0 then
            Limit := 10;

        Url := BuildUrl(Setup."API Base URL", '/scan/history/' + Setup."Tenant ID" + '?limit=' + Format(Limit));

        Headers := Client.DefaultRequestHeaders();
        Headers.Clear();
        Headers.Add('X-Tenant-Id', Setup."Tenant ID");
        Headers.Add('X-Api-Token', Setup."API Token");

        if not Client.Get(Url, Response) then
            Error('The backend request could not be sent. Please verify the network connection.');

        Response.Content.ReadAs(ResponseText);

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
        Headers: HttpHeaders;
    begin
        EnsureReadyForScan(Setup);

        Url := BuildUrl(Setup."API Base URL", '/scan/trend/' + Setup."Tenant ID");

        Headers := Client.DefaultRequestHeaders();
        Headers.Clear();
        Headers.Add('X-Tenant-Id', Setup."Tenant ID");
        Headers.Add('X-Api-Token', Setup."API Token");

        if not Client.Get(Url, Response) then
            Error('The backend request could not be sent. Please verify the network connection.');

        Response.Content.ReadAs(ResponseText);

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
        EnsureReadyForScan(Setup);

        Content.WriteFrom(RequestText);
        Content.GetHeaders(Headers);
        Headers.Clear();
        Headers.Add('Content-Type', 'application/json');

        Headers := Client.DefaultRequestHeaders();
        Headers.Clear();
        Headers.Add('X-Tenant-Id', Setup."Tenant ID");
        Headers.Add('X-Api-Token', Setup."API Token");

        if not Client.Post(BuildUrl(Setup."API Base URL", '/scan/sync'), Content, Response) then
            Error('The backend sync request could not be sent. Please verify the network connection.');

        Response.Content.ReadAs(ResponseText);

        if not Response.IsSuccessStatusCode() then
            Error('Scan sync failed. Status %1 - %2', Response.HttpStatusCode(), ResponseText);
    end;

    procedure DeleteScanFromBackend(var Setup: Record "DH Setup"; ScanId: Code[50])
    var
        Client: HttpClient;
        Response: HttpResponseMessage;
        ResponseText: Text;
        Headers: HttpHeaders;
    begin
        EnsureReadyForScan(Setup);

        Headers := Client.DefaultRequestHeaders();
        Headers.Clear();
        Headers.Add('X-Tenant-Id', Setup."Tenant ID");
        Headers.Add('X-Api-Token', Setup."API Token");

        if not Client.Delete(BuildUrl(Setup."API Base URL", '/scan/' + Format(ScanId)), Response) then
            Error('The backend delete request could not be sent. Please verify the network connection.');

        Response.Content.ReadAs(ResponseText);

        if not Response.IsSuccessStatusCode() then
            Error('Backend scan delete failed. Status %1 - %2', Response.HttpStatusCode(), ResponseText);
    end;

    procedure ParseScanResponse(ResponseText: Text; var ScanId: Code[50]; var DataScore: Integer; var IssuesCount: Integer; var GeneratedAtUtc: DateTime)
    var
        JsonResponse: JsonObject;
        Token: JsonToken;
        GeneratedAtText: Text;
    begin
        Clear(ScanId);
        Clear(DataScore);
        Clear(IssuesCount);
        Clear(GeneratedAtUtc);

        if not JsonResponse.ReadFrom(ResponseText) then
            Error('The backend returned an invalid JSON response: %1', ResponseText);

        if JsonResponse.Get('scan_id', Token) then
            if not IsJsonNull(Token) then
                ScanId := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(ScanId));

        if JsonResponse.Get('data_score', Token) then
            if not IsJsonNull(Token) then
                DataScore := Token.AsValue().AsInteger();

        if JsonResponse.Get('issues_count', Token) then
            if not IsJsonNull(Token) then
                IssuesCount := Token.AsValue().AsInteger();

        if JsonResponse.Get('generated_at_utc', Token) then
            if not IsJsonNull(Token) then
                GeneratedAtText := Token.AsValue().AsText();

        if GeneratedAtText <> '' then
            Evaluate(GeneratedAtUtc, GeneratedAtText);
    end;

    procedure UpdateSetupFromScanResult(var Setup: Record "DH Setup"; DataScore: Integer; GeneratedAtUtc: DateTime)
    begin
        Setup."Last Score" := DataScore;

        if GeneratedAtUtc <> 0DT then
            Setup."Last Scan Date" := GeneratedAtUtc
        else
            Setup."Last Scan Date" := CurrentDateTime();

        Setup.Modify(true);
    end;

    local procedure EnsureSetupLoaded(var Setup: Record "DH Setup")
    begin
        if not Setup.Get('SETUP') then begin
            Setup.Init();
            Setup."Primary Key" := 'SETUP';
            Setup.Insert(true);
        end;

        if Setup."API Base URL" <> Setup.GetFixedApiBaseUrl() then begin
            Setup."API Base URL" := Setup.GetFixedApiBaseUrl();
            Setup.Modify(true);
        end;
    end;

    local procedure EnsureTenantAccessConfigured(var Setup: Record "DH Setup")
    begin
        EnsureSetupLoaded(Setup);

        if Setup."Tenant ID" = '' then
            Error('Please register the tenant first.');

        if Setup."API Token" = '' then
            Error('The API token is missing. Please register the tenant again.');
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
        exit((JsonValueText = 'null') or (JsonValueText = ''));
    end;

    local procedure MapPlan(Value: Text): Enum "DH License Plan"
    begin
        case LowerCase(Value) of
            'free':
                exit("DH License Plan"::Free);
            'standard':
                exit("DH License Plan"::Standard);
            'premium':
                exit("DH License Plan"::Premium);
            else
                exit("DH License Plan"::Free);
        end;
    end;

    local procedure MapLicenseStatus(Value: Text): Enum "DH License Status"
    begin
        case LowerCase(Value) of
            'trial':
                exit("DH License Status"::Trial);
            'active':
                exit("DH License Status"::Active);
            'expired':
                exit("DH License Status"::Expired);
            'blocked':
                exit("DH License Status"::Blocked);
            else
                exit("DH License Status"::Trial);
        end;
    end;

    local procedure JsonArrayContainsText(Values: JsonArray; SearchText: Text): Boolean
    var
        Token: JsonToken;
        i: Integer;
    begin
        for i := 0 to Values.Count() - 1 do begin
            Values.Get(i, Token);
            if LowerCase(Token.AsValue().AsText()) = LowerCase(SearchText) then
                exit(true);
        end;

        exit(false);
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