/// <summary>
/// Job Queue entry point for scheduled recalculation. The Parameter String on
/// the Job Queue Entry selects what runs: SAFETYSTOCK, REORDERPOINT, EOQ,
/// ADVISOR, or ALL (default when empty). Results are applied and logged.
/// </summary>
codeunit 70455018 "GSO Job Queue"
{
    TableNo = "Job Queue Entry";

    trigger OnRun()
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        EOQCalc: Codeunit "GSO EOQ";
        PolicyAdvisor: Codeunit "GSO Policy Advisor";
        RunAll: Codeunit "GSO Run All";
        Telemetry: Codeunit "GSO Telemetry";
        Param: Text;
        Processed: Integer;
    begin
        Param := UpperCase(DelChr(Rec."Parameter String", '<>', ' '));

        case Param of
            'SAFETYSTOCK':
                Processed := SafetyStockCalc.CalculateBulk(Item, 0, true);
            'REORDERPOINT':
                Processed := ReorderPointCalc.CalculateBulk(Item, true);
            'EOQ':
                Processed := EOQCalc.CalculateBulk(Item, true);
            'ADVISOR':
                Processed := PolicyAdvisor.AdviseBulk(Item, true);
            else
                Processed := RunAll.RunBulk(Item, true);
        end;

        Telemetry.LogScheduledRun(Param, Processed);
    end;
}
