page 53100 "DH Setup"
{
    PageType = Card;
    SourceTable = "DH Setup";
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'DH Setup';

    layout
    {
        area(Content)
        {
            group(General)
            {
                field("API Base URL"; Rec."API Base URL")
                {
                    ApplicationArea = All;
                }
                field("Tenant ID"; Rec."Tenant ID")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("API Token"; Rec."API Token")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Premium Enabled"; Rec."Premium Enabled")
                {
                    ApplicationArea = All;
                    ToolTip = 'Enable this only for your own test tenant to unlock premium deep scan actions.';
                }
                field("Last Score"; Rec."Last Score")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Last Scan Date"; Rec."Last Scan Date")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(RegisterTenant)
            {
                Caption = 'Register Tenant';
                ApplicationArea = All;
                Image = Add;

                trigger OnAction()
                var
                    ApiClient: Codeunit "DH API Client";
                begin
                    ApiClient.RegisterTenant(Rec);
                    CurrPage.Update();
                end;
            }

            action(TestConnection)
            {
                Caption = 'Test Connection';
                ApplicationArea = All;
                Image = TestFile;

                trigger OnAction()
                var
                    ApiClient: Codeunit "DH API Client";
                begin
                    ApiClient.TestConnection(Rec);
                end;
            }

            action(StartScan)
            {
                Caption = 'Start Scan';
                ApplicationArea = All;
                Image = Calculate;

                trigger OnAction()
                begin
                    StartScanForCurrentTenant();
                    CurrPage.Update();
                end;
            }

            action(OpenScanHistory)
            {
                Caption = 'Scan History';
                ApplicationArea = All;
                Image = List;
                RunObject = page "DH Dashboard List";
            }
        }
    }

    trigger OnOpenPage()
    begin
        EnsureSetupExists();
    end;

    local procedure EnsureSetupExists()
    begin
        if not Rec.Get('SETUP') then begin
            Rec.Init();
            Rec."Primary Key" := 'SETUP';
            Rec.Insert();
        end;
    end;

    local procedure StartScanForCurrentTenant()
    var
        QuickScanMgt: Codeunit "DH QuickScan Mgt.";
        DeepScanMgt: Codeunit "DH Deep Scan Mgt.";
    begin
        if Rec."Premium Enabled" then
            DeepScanMgt.QueueDeepScan(Rec)
        else
            QuickScanMgt.RunQuickScanAndOpenDashboard(Rec);
    end;
}