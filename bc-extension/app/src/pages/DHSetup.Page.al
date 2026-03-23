page 53100 "DH Setup"
{
    PageType = Card;
    SourceTable = "DH Setup";
    Caption = 'BCSentinel Setup';
    ApplicationArea = All;
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("API Base URL"; Rec."API Base URL")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Fixed production API URL.';
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

                field(Registered; Rec.Registered)
                {
                    ApplicationArea = All;
                    Editable = false;
                }

                field("Registration Date"; Rec."Registration Date")
                {
                    ApplicationArea = All;
                    Editable = false;
                }

                field("Data Processing Consent"; Rec."Data Processing Consent")
                {
                    ApplicationArea = All;
                    ToolTip = 'Must be enabled before tenant registration and scan synchronization.';
                }
            }

            group(License)
            {
                Caption = 'License';

                field("Current Plan"; Rec."Current Plan")
                {
                    ApplicationArea = All;
                    Editable = false;
                }

                field("License Status"; Rec."License Status")
                {
                    ApplicationArea = All;
                    Editable = false;
                }

                field("Last License Check"; Rec."Last License Check")
                {
                    ApplicationArea = All;
                    Editable = false;
                }

                field("Premium Enabled"; Rec."Premium Enabled")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
            }

            group(Scan)
            {
                Caption = 'Last Scan';

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
            action(TestConnection)
            {
                Caption = 'Test BCSentinel Connection';
                ApplicationArea = All;
                Image = TestFile;

                trigger OnAction()
                var
                    ApiClient: Codeunit "DH API Client";
                begin
                    ApiClient.TestConnection(Rec);
                end;
            }

            action(RegisterTenant)
            {
                Caption = 'Register with BCSentinel';
                ApplicationArea = All;
                Image = Web;

                trigger OnAction()
                var
                    ApiClient: Codeunit "DH API Client";
                begin
                    ApiClient.EnsureTenantRegistered(Rec);
                    CurrPage.Update(false);
                    Message('BCSentinel tenant registration completed.');
                end;
            }

            action(RefreshLicense)
            {
                Caption = 'Refresh BCSentinel License';
                ApplicationArea = All;
                Image = Refresh;

                trigger OnAction()
                var
                    ApiClient: Codeunit "DH API Client";
                begin
                    ApiClient.RefreshLicenseStatus(Rec);
                    CurrPage.Update(false);
                    Message('BCSentinel license status refreshed.');
                end;
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
            Rec.Insert(true);
        end;

        Rec.ApplyDefaults();
        Rec.Modify(true);
    end;
}