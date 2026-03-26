codeunit 53123 "DH QuickScan Mgt."
{
    procedure RunQuickScanAndOpenDashboard(var Setup: Record "DH Setup")
    var
        Header: Record "DH Scan Header";
        EntryNo: Integer;
    begin
        EntryNo := RunQuickScan(Setup);

        if Header.Get(EntryNo) then
            Page.Run(Page::"DH Dashboard", Header);
    end;

    procedure RunQuickScan(var Setup: Record "DH Setup"): Integer
    var
        ApiClient: Codeunit "DH API Client";
        Header: Record "DH Scan Header";
        ResponseText: Text;
        RequestText: Text;
        SyncResponseText: Text;
        EntryNo: Integer;
    begin
        ResponseText := ApiClient.RunQuickScan(Setup);
        EntryNo := SaveQuickScanResponse(Setup, ResponseText);

        Commit();

        if Header.Get(EntryNo) then begin
            RequestText := BuildSyncPayload(Setup, Header);
            SyncResponseText := ApiClient.SyncScanToBackendAndGetResponse(Setup, RequestText);
            ApplySyncCommercials(Header, SyncResponseText);
            ApplySyncIssueImpacts(Header, SyncResponseText);
        end;

        exit(EntryNo);
    end;

    procedure GetScanHistory(var Setup: Record "DH Setup"; Limit: Integer): Text
    var
        ApiClient: Codeunit "DH API Client";
    begin
        exit(ApiClient.GetScanHistory(Setup, Limit));
    end;

    procedure GetScanTrend(var Setup: Record "DH Setup"): Text
    var
        ApiClient: Codeunit "DH API Client";
    begin
        exit(ApiClient.GetScanTrend(Setup));
    end;

    local procedure SaveQuickScanResponse(var Setup: Record "DH Setup"; ResponseText: Text): Integer
    var
        JsonObj: JsonObject;
        JsonToken: JsonToken;
        Header: Record "DH Scan Header";
        EntryNo: Integer;
    begin
        if not JsonObj.ReadFrom(ResponseText) then
            Error('Invalid JSON response: %1', ResponseText);

        EntryNo := GetNextHeaderEntryNo();

        Header.Init();
        Header."Entry No." := EntryNo;
        Header."Scan Type" := Header."Scan Type"::Quick;
        Header."Scan DateTime" := CurrentDateTime();

        if JsonObj.Get('scan_id', JsonToken) then
            Header."Backend Scan Id" := CopyStr(JsonToken.AsValue().AsText(), 1, MaxStrLen(Header."Backend Scan Id"));

        if JsonObj.Get('bc_run_id', JsonToken) then
            Header."Run ID" := CopyStr(JsonToken.AsValue().AsText(), 1, MaxStrLen(Header."Run ID"));

        if Header."Run ID" = '' then
            Header."Run ID" := Header."Backend Scan Id";

        if JsonObj.Get('data_score', JsonToken) then
            Header."Data Score" := JsonToken.AsValue().AsInteger();

        if JsonObj.Get('checks_count', JsonToken) then
            Header."Checks Count" := JsonToken.AsValue().AsInteger();

        if JsonObj.Get('issues_count', JsonToken) then
            Header."Issues Count" := JsonToken.AsValue().AsInteger();

        if JsonObj.Get('premium_available', JsonToken) then
            Header."Premium Available" := JsonToken.AsValue().AsBoolean();

        ReadSummary(JsonObj, Header);
        ReadCommercials(JsonObj, Header);
        Header.Insert();

        SaveIssues(JsonObj, EntryNo);

        Setup.Validate("Last Score", Header."Data Score");
        Setup.Validate("Last Scan Date", Header."Scan DateTime");
        Setup.Modify(true);

        exit(EntryNo);
    end;

    local procedure BuildSyncPayload(var Setup: Record "DH Setup"; var Header: Record "DH Scan Header"): Text
    var
        DataProfilingMgt: Codeunit "DH Data Profiling Mgt.";
        Issue: Record "DH Scan Issue";
        Payload: JsonObject;
        IssuesArray: JsonArray;
        IssueObject: JsonObject;
        RequestText: Text;
    begin
        Payload.Add('tenant_id', Setup."Tenant ID");
        Payload.Add('scan_id', Format(Header."Backend Scan Id"));
        Payload.Add('scan_type', 'quick');
        Payload.Add('generated_at_utc', Format(Header."Scan DateTime", 0, 9));
        Payload.Add('data_score', Header."Data Score");
        Payload.Add('checks_count', Header."Checks Count");
        Payload.Add('issues_count', Header."Issues Count");
        Payload.Add('premium_available', Header."Premium Available");
        Payload.Add('headline', Header."Headline");
        Payload.Add('rating', Header."Rating");
        Payload.Add('data_profile', DataProfilingMgt.BuildDataProfile());

        Issue.Reset();
        Issue.SetRange("Scan Entry No.", Header."Entry No.");
        if Issue.FindSet() then
            repeat
                Clear(IssueObject);
                IssueObject.Add('code', Format(Issue."Issue Code"));
                IssueObject.Add('title', Issue."Title");
                IssueObject.Add('severity', LowerCase(Format(Issue."Severity")));
                IssueObject.Add('affected_count', Issue."Affected Count");
                IssueObject.Add('premium_only', Issue."Premium Only");
                IssueObject.Add('recommendation_preview', Issue."Recommendation Preview");
                IssuesArray.Add(IssueObject);
            until Issue.Next() = 0;

        Payload.Add('issues', IssuesArray);
        Payload.WriteTo(RequestText);
        exit(RequestText);
    end;

    local procedure ReadSummary(var JsonObj: JsonObject; var Header: Record "DH Scan Header")
    var
        SummaryToken: JsonToken;
        SummaryObj: JsonObject;
        ValueToken: JsonToken;
    begin
        if not JsonObj.Get('summary', SummaryToken) then
            exit;

        SummaryObj := SummaryToken.AsObject();

        if SummaryObj.Get('headline', ValueToken) then
            Header."Headline" := CopyStr(ValueToken.AsValue().AsText(), 1, MaxStrLen(Header."Headline"));

        if SummaryObj.Get('rating', ValueToken) then
            Header."Rating" := CopyStr(ValueToken.AsValue().AsText(), 1, MaxStrLen(Header."Rating"));
    end;

    local procedure ReadCommercials(var JsonObj: JsonObject; var Header: Record "DH Scan Header")
    var
        Token: JsonToken;
        DataProfileToken: JsonToken;
        DataProfileObj: JsonObject;
    begin
        if JsonObj.Get('estimated_loss_eur', Token) then begin
            Header."Est. Loss" := ReadJsonDecimal(Token);
            Header."Estimated Loss (EUR)" := Header."Est. Loss";
        end;

        if JsonObj.Get('potential_saving_eur', Token) then begin
            Header."Potential Saving" := ReadJsonDecimal(Token);
            Header."Potential Saving (EUR)" := Header."Potential Saving";
        end;

        if JsonObj.Get('estimated_premium_price_monthly', Token) then
            Header."Est. Premium Price" := ReadJsonDecimal(Token);

        if JsonObj.Get('roi_eur', Token) then
            Header."ROI" := ReadJsonDecimal(Token);

        if JsonObj.Get('data_profile', DataProfileToken) then begin
            DataProfileObj := DataProfileToken.AsObject();
            if DataProfileObj.Get('total_records', Token) then
                Header."Total Records" := Token.AsValue().AsInteger();
        end;
    end;

    local procedure SaveIssues(var JsonObj: JsonObject; ScanEntryNo: Integer)
    var
        IssuesToken: JsonToken;
        IssuesArray: JsonArray;
        IssueToken: JsonToken;
        IssueObj: JsonObject;
        Issue: Record "DH Scan Issue";
        i: Integer;
    begin
        if not JsonObj.Get('issues', IssuesToken) then
            exit;

        IssuesArray := IssuesToken.AsArray();

        for i := 0 to IssuesArray.Count() - 1 do begin
            IssuesArray.Get(i, IssueToken);
            IssueObj := IssueToken.AsObject();

            Issue.Init();
            Issue."Entry No." := GetNextIssueEntryNo();
            Issue."Scan Entry No." := ScanEntryNo;
            Issue."Issue Code" := CopyStr(GetJsonText(IssueObj, 'code'), 1, MaxStrLen(Issue."Issue Code"));
            Issue."Title" := CopyStr(GetJsonText(IssueObj, 'title'), 1, MaxStrLen(Issue."Title"));
            Issue."Severity" := CopyStr(GetJsonText(IssueObj, 'severity'), 1, MaxStrLen(Issue."Severity"));
            ReadIssueFieldInt(IssueObj, 'affected_count', Issue."Affected Count");
            Issue."Severity Sort Order" := GetSeveritySortOrder(Issue."Severity");
            Issue."Affected Count Sort Value" := -Issue."Affected Count";
            Issue."Recommendation Preview" := CopyStr(GetJsonText(IssueObj, 'recommendation_preview'), 1, MaxStrLen(Issue."Recommendation Preview"));
            ReadIssueFieldBool(IssueObj, 'premium_only', Issue."Premium Only");
            Issue."Estimated Impact (EUR)" := ReadJsonDecimalFromObject(IssueObj, 'estimated_impact_eur');
            Issue.Insert(true);
        end;
    end;

    local procedure GetJsonText(var JsonObj: JsonObject; FieldName: Text): Text
    var
        Token: JsonToken;
    begin
        if JsonObj.Get(FieldName, Token) then
            if not IsJsonNull(Token) then
                exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure ReadIssueFieldInt(var IssueObj: JsonObject; FieldName: Text; var Target: Integer)
    var
        Token: JsonToken;
    begin
        Clear(Target);
        if IssueObj.Get(FieldName, Token) then
            if not IsJsonNull(Token) then
                Target := Token.AsValue().AsInteger();
    end;

    local procedure ReadIssueFieldBool(var IssueObj: JsonObject; FieldName: Text; var Target: Boolean)
    var
        Token: JsonToken;
    begin
        Clear(Target);
        if IssueObj.Get(FieldName, Token) then
            if not IsJsonNull(Token) then
                Target := Token.AsValue().AsBoolean();
    end;

    local procedure ApplySyncCommercials(var Header: Record "DH Scan Header"; SyncResponseText: Text)
    var
        JsonObj: JsonObject;
        CommercialsToken: JsonToken;
        CommercialsObj: JsonObject;
        Token: JsonToken;
    begin
        if SyncResponseText = '' then
            exit;

        if not JsonObj.ReadFrom(SyncResponseText) then
            exit;

        if not JsonObj.Get('commercials', CommercialsToken) then
            exit;

        CommercialsObj := CommercialsToken.AsObject();

        if CommercialsObj.Get('total_records', Token) then
            Header."Total Records" := Token.AsValue().AsInteger();

        if CommercialsObj.Get('estimated_loss_eur', Token) then begin
            Header."Est. Loss" := ReadJsonDecimal(Token);
            Header."Estimated Loss (EUR)" := Header."Est. Loss";
        end;

        if CommercialsObj.Get('potential_saving_eur', Token) then begin
            Header."Potential Saving" := ReadJsonDecimal(Token);
            Header."Potential Saving (EUR)" := Header."Potential Saving";
        end;

        if CommercialsObj.Get('premium_price_per_month', Token) then
            Header."Est. Premium Price" := ReadJsonDecimal(Token)
        else
            if CommercialsObj.Get('estimated_premium_price_monthly', Token) then
                Header."Est. Premium Price" := ReadJsonDecimal(Token);

        if CommercialsObj.Get('roi_eur', Token) then
            Header."ROI" := ReadJsonDecimal(Token);

        Header.Modify(true);
    end;

    local procedure ApplySyncIssueImpacts(var Header: Record "DH Scan Header"; SyncResponseText: Text)
    var
        JsonObj: JsonObject;
        IssuesToken: JsonToken;
        IssuesArray: JsonArray;
        IssueToken: JsonToken;
        IssueObj: JsonObject;
        Issue: Record "DH Scan Issue";
        i: Integer;
        CodeTxt: Text;
    begin
        if SyncResponseText = '' then
            exit;

        if not JsonObj.ReadFrom(SyncResponseText) then
            exit;

        if not JsonObj.Get('issues', IssuesToken) then
            exit;

        IssuesArray := IssuesToken.AsArray();

        for i := 0 to IssuesArray.Count() - 1 do begin
            IssuesArray.Get(i, IssueToken);
            IssueObj := IssueToken.AsObject();
            CodeTxt := GetJsonText(IssueObj, 'code');

            Issue.Reset();
            Issue.SetRange("Scan Entry No.", Header."Entry No.");
            Issue.SetRange("Issue Code", CopyStr(CodeTxt, 1, MaxStrLen(Issue."Issue Code")));
            if Issue.FindFirst() then begin
                Issue."Estimated Impact (EUR)" := ReadJsonDecimalFromObject(IssueObj, 'estimated_impact_eur');
                Issue.Modify(true);
            end;
        end;
    end;

    local procedure ReadJsonDecimalFromObject(var JsonObj: JsonObject; FieldName: Text): Decimal
    var
        Token: JsonToken;
    begin
        if JsonObj.Get(FieldName, Token) then
            if not IsJsonNull(Token) then
                exit(ReadJsonDecimal(Token));

        exit(0);
    end;

    local procedure ReadJsonDecimal(Token: JsonToken): Decimal
    var
        ValueText: Text;
        ValueDecimal: Decimal;
    begin
        if IsJsonNull(Token) then
            exit(0);

        ValueText := DelChr(Token.AsValue().AsText(), '=', ' ');
        if ValueText = '' then
            exit(0);

        if TryEvaluateDecimal(ValueText, ValueDecimal) then
            exit(ValueDecimal);

        if (StrPos(ValueText, '.') > 0) and (StrPos(ValueText, ',') = 0) then begin
            ValueText := ConvertStr(ValueText, '.', ',');
            if TryEvaluateDecimal(ValueText, ValueDecimal) then
                exit(ValueDecimal);
        end;

        if (StrPos(ValueText, '.') > 0) and (StrPos(ValueText, ',') > 0) then begin
            ValueText := DelChr(ValueText, '=', '.');
            if TryEvaluateDecimal(ValueText, ValueDecimal) then
                exit(ValueDecimal);
        end;

        Error('Could not parse decimal value from backend JSON: %1', Token.AsValue().AsText());
    end;

    [TryFunction]
    local procedure TryEvaluateDecimal(ValueText: Text; var ValueDecimal: Decimal)
    begin
        Evaluate(ValueDecimal, ValueText);
    end;

    local procedure IsJsonNull(Token: JsonToken): Boolean
    var
        JsonValueText: Text;
    begin
        JsonValueText := LowerCase(Format(Token));
        exit((JsonValueText = 'null') or (JsonValueText = '<null>'));
    end;

    local procedure GetNextHeaderEntryNo(): Integer
    var
        Header: Record "DH Scan Header";
    begin
        if Header.FindLast() then
            exit(Header."Entry No." + 1);
        exit(1);
    end;

    local procedure GetNextIssueEntryNo(): Integer
    var
        Issue: Record "DH Scan Issue";
    begin
        if Issue.FindLast() then
            exit(Issue."Entry No." + 1);
        exit(1);
    end;

    local procedure GetSeveritySortOrder(SeverityValue: Code[20]): Integer
    begin
        case LowerCase(SeverityValue) of
            'high':
                exit(1);
            'medium':
                exit(2);
            'low':
                exit(3);
        end;
        exit(99);
    end;
}
