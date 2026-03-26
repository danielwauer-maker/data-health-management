codeunit 53153 "DH Cost Mgt."
{
    ObsoleteState = Pending;
    ObsoleteReason = 'Commercial calculations are backend-driven. This codeunit is no longer used by BCSentinel.';
    ObsoleteTag = '2.0.0';

    procedure GetIssueImpact(IssueCode: Text; AffectedCount: Integer): Decimal
    begin
        exit(0);
    end;

    procedure CalculatePotentialSaving(EstimatedLoss: Decimal): Decimal
    begin
        exit(0);
    end;
}
