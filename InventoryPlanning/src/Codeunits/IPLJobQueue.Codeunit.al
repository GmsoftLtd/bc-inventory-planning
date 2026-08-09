/// <summary>
/// Job Queue entry point for scheduled recalculation. The Parameter String on
/// the Job Queue Entry selects what runs: SAFETYSTOCK, REORDERPOINT, EOQ,
/// ADVISOR, or ALL (default when empty). Results are applied and logged.
/// </summary>
codeunit 50518 "IPL Job Queue"
{
    TableNo = "Job Queue Entry";

    trigger OnRun()
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "IPL Safety Stock";
        ReorderPointCalc: Codeunit "IPL Reorder Point";
        EOQCalc: Codeunit "IPL EOQ";
        PolicyAdvisor: Codeunit "IPL Policy Advisor";
        RunAll: Codeunit "IPL Run All";
        Telemetry: Codeunit "IPL Telemetry";
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
