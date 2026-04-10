page 53123 "DHM Analytics"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = None;
    Caption = 'DHM Analytics';

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'Analytics';

                field(DescriptionTxt; DescriptionTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Beschreibung';
                    Editable = false;
                    MultiLine = true;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(OpenDashboard)
            {
                ApplicationArea = All;
                Caption = 'Analytics Dashboard öffnen';
                Image = View;
                ToolTip = 'Öffnet das externe Data Health Management Analytics Dashboard.';

                trigger OnAction()
                var
                    Setup: Record "DH Setup";
                    ApiClient: Codeunit "DH API Client";
                    Token: Text;
                begin
                    LoadSetupOrError(Setup);

                    Token := ApiClient.GetAnalyticsDashboardToken(Setup);

                    if Token = '' then
                        Error('In der Antwort des Token-Services wurde kein gültiger Token gefunden.');

                    Hyperlink(GetDashboardUrl(Setup, Token));
                end;
            }
        }
    }

    var
        DescriptionTxt: Text[250];

    trigger OnOpenPage()
    var
        Setup: Record "DH Setup";
        BaseUrl: Text;
    begin
        DescriptionTxt := 'Öffnet das Data Health Management Analytics Dashboard in einem neuen Browser-Tab.';

        if Setup.Get('SETUP') then begin
            BaseUrl := RemoveTrailingSlash(Setup."API Base URL");
            if BaseUrl <> '' then
                DescriptionTxt := StrSubstNo(
                    'Öffnet das Data Health Management Analytics Dashboard in einem neuen Browser-Tab. Backend: %1',
                    CopyStr(BaseUrl, 1, 180));
        end;
    end;

    local procedure LoadSetupOrError(var Setup: Record "DH Setup")
    begin
        if not Setup.Get('SETUP') then
            Error('DH Setup wurde nicht gefunden.');

        if Setup."API Base URL" = '' then
            Error('Bitte hinterlegen Sie zuerst die API Base URL im DH Setup.');

        if Setup."Tenant ID" = '' then
            Error('Bitte registrieren Sie zuerst den Tenant im DH Setup.');

        if Setup."API Token" = '' then
            Error('Bitte registrieren Sie zuerst den Tenant im DH Setup, damit ein API-Token hinterlegt ist.');
    end;

    local procedure RequestDashboardToken(var Setup: Record "DH Setup"): Text
    var
        Client: HttpClient;
        Request: HttpRequestMessage;
        Headers: HttpHeaders;
        Response: HttpResponseMessage;
        ResponseText: Text;
    begin
        Request.Method := 'GET';
        Request.SetRequestUri(GetTokenUrl(Setup));
        Request.GetHeaders(Headers);
        Headers.Clear();
        Headers.Add('X-Tenant-Id', Setup."Tenant ID");
        Headers.Add('X-Api-Token', Setup."API Token");

        if not Client.Send(Request, Response) then
            Error('Der Token-Service konnte nicht erreicht werden.');

        Response.Content().ReadAs(ResponseText);

        if not Response.IsSuccessStatusCode() then
            Error(
                'Der Token-Service hat einen Fehler zurückgegeben. Status: %1. Antwort: %2',
                Response.HttpStatusCode(),
                CopyStr(ResponseText, 1, 1024));

        exit(ResponseText);
    end;


    local procedure GetTokenUrl(var Setup: Record "DH Setup"): Text
    var
        BaseUrl: Text;
        CompanyValue: Text;
        EnvironmentValue: Text;
        TenantValue: Text;
        ScanModeValue: Text;
    begin
        BaseUrl := BuildUrl(Setup."API Base URL", '/analytics/get-token');
        CompanyValue := EncodeUrlValue(CompanyName());
        EnvironmentValue := EncodeUrlValue('BC Cloud');
        TenantValue := EncodeUrlValue(Setup."Tenant ID");
        ScanModeValue := EncodeUrlValue(GetScanMode(Setup));

        exit(
            BaseUrl +
            '?company=' + CompanyValue +
            '&environment=' + EnvironmentValue +
            '&tenant_id=' + TenantValue +
            '&scan_mode=' + ScanModeValue);
    end;


    local procedure GetScanMode(var Setup: Record "DH Setup"): Text
    begin
        if Setup."Premium Enabled" then
            exit('premium_deep');

        exit('free_deep');
    end;

    local procedure GetDashboardUrl(var Setup: Record "DH Setup"; Token: Text): Text
    var
        BaseUrl: Text;
    begin
        BaseUrl := BuildUrl(Setup."API Base URL", '/analytics/embed');
        exit(BaseUrl + '?token=' + EncodeUrlValue(Token));
    end;

    local procedure ExtractTokenFromJson(JsonText: Text): Text
    var
        JsonObj: JsonObject;
        JsonToken: JsonToken;
    begin
        if not JsonObj.ReadFrom(JsonText) then
            Error('Die Antwort des Token-Services ist kein gültiges JSON.');

        if not JsonObj.Get('token', JsonToken) then
            Error('Das Feld "token" fehlt in der Antwort des Token-Services.');

        exit(JsonToken.AsValue().AsText());
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

    local procedure EncodeUrlValue(Value: Text): Text
    begin
        Value := Value.Replace('%', '%25');
        Value := Value.Replace(' ', '%20');
        Value := Value.Replace('&', '%26');
        Value := Value.Replace('?', '%3F');
        Value := Value.Replace('=', '%3D');
        Value := Value.Replace('#', '%23');
        Value := Value.Replace('+', '%2B');
        Value := Value.Replace('/', '%2F');
        exit(Value);
    end;
}
