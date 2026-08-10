namespace GMSoft.InventoryPlanning.Test;

using GMSoft.InventoryPlanning;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using System.TestLibraries.Utilities;

/// <summary>
/// End-to-end calculator tests on crafted demand history. Items and postings
/// are created through the standard test libraries; each test posts a known
/// pattern of sales and asserts the calculator's behaviour and guard rails.
/// </summary>
codeunit 50601 "GSO Calculator Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";

    local procedure Initialize()
    var
        Setup: Record "GSO Setup";
    begin
        // Runs for every test (no IsInitialized guard): per-test rollback
        // reverts the setup record, so a one-shot flag would leave later
        // tests running against defaults.
        Setup.GetSetup();
        Setup."History Window (Days)" := 90;
        Setup."Min Demand Observations" := 5;
        Setup."Default Lead Time (Days)" := 7;
        Setup."Log History" := true;
        Setup."Round Up Results" := true;
        Setup."Apply Maximum Inventory" := true;
        Setup."Trend Warning Threshold %" := 30;
        Setup."Include Consumption Demand" := false;
        Setup.Modify();
    end;

    local procedure CreateItemWithSalesHistory(var Item: Record Item; DemandDays: Integer; QtyPerDay: Decimal)
    begin
        CreateItemWithSalesHistoryOffset(Item, DemandDays, QtyPerDay, 1);
    end;

    local procedure CreateItemWithSalesHistoryOffset(var Item: Record Item; DemandDays: Integer; QtyPerDay: Decimal; StartDaysAgo: Integer)
    var
        ItemJournalLine: Record "Item Journal Line";
        i: Integer;
    begin
        LibraryInventory.CreateItem(Item);

        // Seed stock so sales can post.
        LibraryInventory.CreateItemJournalLineInItemTemplate(
            ItemJournalLine, Item."No.", '', '', DemandDays * QtyPerDay * 2);
        LibraryInventory.PostItemJournalLine(ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name");

        // Post one Sale entry per day so ILE Entry Type = Sale, which is what
        // the demand-statistics engine filters on.
        for i := StartDaysAgo to StartDaysAgo + DemandDays - 1 do begin
            LibraryInventory.CreateItemJournalLineInItemTemplate(
                ItemJournalLine, Item."No.", '', '', QtyPerDay);
            ItemJournalLine.Validate("Entry Type", ItemJournalLine."Entry Type"::Sale);
            ItemJournalLine.Validate("Posting Date", CalcDate(StrSubstNo('<-%1D>', i), WorkDate()));
            ItemJournalLine.Validate(Quantity, QtyPerDay);
            ItemJournalLine.Modify(true);
            LibraryInventory.PostItemJournalLine(ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name");
        end;
    end;

    local procedure ClearStatsCache()
    var
        DemandStats: Codeunit "GSO Demand Statistics";
    begin
        DemandStats.ClearCache();
    end;

    [Test]
    procedure DemandStats_SteadyDailySales_YieldsExpectedAverage()
    var
        Item: Record Item;
        DemandStats: Codeunit "GSO Demand Statistics";
        AvgDemand: Decimal;
        StdDev: Decimal;
        Observations: Integer;
        ADI: Decimal;
        CV2: Decimal;
    begin
        Initialize();
        CreateItemWithSalesHistory(Item, 30, 10);
        ClearStatsCache();

        DemandStats.ComputeDemandStats(Item."No.", 90, AvgDemand, StdDev, Observations, ADI, CV2);

        Assert.AreEqual(30, Observations, '30 demand days posted must yield 30 observations');
        Assert.IsTrue(AvgDemand > 0, 'Average demand must be positive');
        // 300 units over a ~91-day calendar window.
        Assert.AreNearlyEqual(300 / 91, AvgDemand, 0.5, 'Average daily demand must be total/calendar days');
        Assert.IsTrue(CV2 < 0.01, 'Identical daily quantities must give near-zero CV2');
    end;

    [Test]
    procedure SafetyStock_SteadyDemandKnownLeadTime_MatchesFormula()
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        DemandStats: Codeunit "GSO Demand Statistics";
        GSOMath: Codeunit "GSO Math";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
        LeadTimeFormula: DateFormula;
        AvgDemand: Decimal;
        StdDev: Decimal;
        Observations: Integer;
        ADI: Decimal;
        CV2: Decimal;
        Expected: Decimal;
        Result: Decimal;
    begin
        Initialize();
        CreateItemWithSalesHistory(Item, 30, 10);
        Item.Get(Item."No.");
        Evaluate(LeadTimeFormula, '<7D>');
        Item.Validate("Lead Time Calculation", LeadTimeFormula);
        Item.Modify(true);
        ClearStatsCache();

        DemandStats.ComputeDemandStats(Item."No.", 90, AvgDemand, StdDev, Observations, ADI, CV2);
        // No purchase receipts exist, so lead time = 7 days with zero
        // variability: SS = Z x sqrt(LT x sigmaD^2), rounded up.
        Expected := Round(GSOMath.ZScore(95) * GSOMath.Sqrt(7 * Power(StdDev, 2)), 1, '>');

        Result := SafetyStockCalc.CalculateForItem(Item."No.", 95, true, ResultCode, Note);

        Assert.AreEqual(ResultCode::OK, ResultCode, 'Calculation must succeed');
        Assert.AreEqual(Expected, Result, 'Safety stock must match Z x sqrt(LT x sigmaD^2)');
        Item.Get(Item."No.");
        Assert.AreEqual(Expected, Item."Safety Stock Quantity", 'Applied result must be written to the item');
    end;

    [Test]
    procedure SafetyStock_InsufficientHistory_SkipsWithResultCode()
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
        Result: Decimal;
    begin
        Initialize();
        LibraryInventory.CreateItem(Item); // no history at all

        Result := SafetyStockCalc.CalculateForItem(Item."No.", 95, true, ResultCode, Note);

        Assert.AreEqual(0, Result, 'No history must yield zero');
        Assert.AreEqual(ResultCode::"Insufficient Demand Data", ResultCode, 'Result code must say why');
        Item.Get(Item."No.");
        Assert.AreEqual(0, Item."Safety Stock Quantity", 'Item must not be touched on a skip');
    end;

    [Test]
    procedure SafetyStock_BlockedItem_SkipsWithResultCode()
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        Initialize();
        LibraryInventory.CreateItem(Item);
        Item.Validate(Blocked, true);
        Item.Modify(true);

        SafetyStockCalc.CalculateForItem(Item."No.", 95, true, ResultCode, Note);

        Assert.AreEqual(ResultCode::"Item Blocked", ResultCode, 'Blocked item must be skipped');
    end;

    [Test]
    procedure SafetyStock_ExcludedItem_SkipsAndLeavesItemUntouched()
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
        Result: Decimal;
    begin
        Initialize();
        CreateItemWithSalesHistory(Item, 20, 10);
        Item.Get(Item."No.");
        Item."Safety Stock Quantity" := 42; // planner-maintained value
        Item."GSO Exclude From Planning" := true;
        Item.Modify();

        Result := SafetyStockCalc.CalculateForItem(Item."No.", 95, true, ResultCode, Note);

        Assert.AreEqual(0, Result, 'Excluded item must yield zero');
        Assert.AreEqual(ResultCode::Excluded, ResultCode, 'Result code must say the item is excluded');
        Item.Get(Item."No.");
        Assert.AreEqual(42, Item."Safety Stock Quantity", 'Excluded item''s manual value must survive');
    end;

    [Test]
    procedure SafetyStock_NonInventoryItem_SkipsWithResultCode()
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        Initialize();
        LibraryInventory.CreateItem(Item);
        Item.Validate(Type, Item.Type::Service);
        Item.Modify(true);

        SafetyStockCalc.CalculateForItem(Item."No.", 95, true, ResultCode, Note);

        Assert.AreEqual(ResultCode::"Not an Inventory Item", ResultCode, 'Service items must be skipped, not written to');
    end;

    [Test]
    procedure ReorderPoint_MakeToOrderItem_Skipped()
    var
        Item: Record Item;
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
        Result: Decimal;
    begin
        Initialize();
        CreateItemWithSalesHistory(Item, 10, 5);
        Item.Get(Item."No.");
        Item.Validate("Reordering Policy", Item."Reordering Policy"::Order);
        Item.Modify(true);

        Result := ReorderPointCalc.CalculateForItem(Item."No.", true, -1, ResultCode, Note);

        Assert.AreEqual(0, Result, 'MTO item must yield zero');
        Assert.AreEqual(ResultCode::"Make-to-Order Skipped", ResultCode, 'MTO item must be skipped, not calculated');
    end;

    [Test]
    procedure ReorderPoint_WithHistory_AppliesToItem()
    var
        Item: Record Item;
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
        Result: Decimal;
    begin
        Initialize();
        CreateItemWithSalesHistory(Item, 20, 8);
        ClearStatsCache();

        Result := ReorderPointCalc.CalculateForItem(Item."No.", true, 0, ResultCode, Note);

        Assert.AreEqual(ResultCode::OK, ResultCode, 'Calculation must succeed with 20 demand days');
        Assert.IsTrue(Result > 0, 'Reorder point must be positive');
        Item.Get(Item."No.");
        Assert.AreEqual(Result, Item."Reorder Point", 'Applied result must be written to the item');
    end;

    [Test]
    procedure ReorderPoint_ExceedsMaximumInventory_IsCapped()
    var
        Item: Record Item;
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
        Result: Decimal;
    begin
        Initialize();
        CreateItemWithSalesHistory(Item, 20, 8);
        Item.Get(Item."No.");
        Item."Maximum Inventory" := 5; // far below demand-during-lead-time
        Item.Modify();
        ClearStatsCache();

        Result := ReorderPointCalc.CalculateForItem(Item."No.", true, 0, ResultCode, Note);

        Assert.AreEqual(ResultCode::"Cap Applied", ResultCode, 'ROP above Maximum Inventory must be capped');
        Assert.AreEqual(5, Result, 'Capped ROP must equal Maximum Inventory');
        Item.Get(Item."No.");
        Assert.AreEqual(5, Item."Reorder Point", 'The capped value must be written, keeping the Maximum Qty. parameter pair valid');
    end;

    [Test]
    procedure EOQ_ZeroOrderingCost_SkipsWithResultCode()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        AppliedQty: Decimal;
        SavedOrderingCost: Decimal;
    begin
        Initialize();
        CreateItemWithSalesHistory(Item, 10, 5);
        Item.Get(Item."No.");
        Item.Validate("Last Direct Cost", 10);
        Item.Modify(true);

        Setup.GetSetup();
        SavedOrderingCost := Setup."Ordering Cost";
        Setup."Ordering Cost" := 0;
        Setup.Modify();

        Assert.IsFalse(EOQCalc.Calculate(Item, true, ResultCode, AppliedQty), 'Zero ordering cost must fail');
        Assert.AreEqual(ResultCode::"Zero Ordering Cost", ResultCode, 'Result code must say why');

        Setup."Ordering Cost" := SavedOrderingCost;
        Setup.Modify();
    end;

    [Test]
    procedure EOQ_WithCostAndDemand_ProducesWilsonQuantity()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        AppliedQty: Decimal;
    begin
        Initialize();
        CreateItemWithSalesHistory(Item, 30, 10);
        Item.Get(Item."No.");
        Item.Validate("Last Direct Cost", 20);
        Item.Modify(true);

        Setup.GetSetup();
        Setup."Ordering Cost" := 50;
        Setup."Holding Rate" := 0.25;
        Setup."Max EOQ Months" := 24; // effectively uncapped for this test
        Setup.Modify();
        ClearStatsCache();

        Assert.IsTrue(EOQCalc.Calculate(Item, false, ResultCode, AppliedQty), 'EOQ must calculate');
        Assert.IsTrue(AppliedQty > 0, 'EOQ must be positive');
    end;

    [Test]
    procedure EOQ_TinyDemandWithRoundUp_NeverWritesZero()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        AppliedQty: Decimal;
    begin
        Initialize();
        // 10 demand days of 0.01 units: fractional raw EOQ, months-cap far
        // below 1. The old code rounded this to 0 and wrote it with result OK.
        CreateItemWithSalesHistory(Item, 10, 0.01);
        Item.Get(Item."No.");
        Item.Validate("Last Direct Cost", 10);
        Item.Modify(true);

        Setup.GetSetup();
        Setup."Ordering Cost" := 50;
        Setup."Holding Rate" := 0.25;
        Setup."Max EOQ Months" := 6;
        Setup."Round Up Results" := true;
        Setup.Modify();
        ClearStatsCache();

        if EOQCalc.Calculate(Item, true, ResultCode, AppliedQty) then
            Assert.IsTrue(AppliedQty >= 1, 'A successful EOQ with round-up must be at least one unit, never zero')
        else
            Assert.AreEqual(ResultCode::"Zero Result", ResultCode, 'A zero EOQ must be reported as Zero Result, not applied');
        Item.Get(Item."No.");
        Assert.IsTrue(Item."Reorder Quantity" >= 0, 'Reorder Quantity must never be negative');
    end;

    [Test]
    procedure EOQ_BelowMinimumOrderQty_IsRaisedToMinimum()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        AppliedQty: Decimal;
    begin
        Initialize();
        CreateItemWithSalesHistory(Item, 30, 10);
        Item.Get(Item."No.");
        Item.Validate("Last Direct Cost", 20);
        Item.Validate("Minimum Order Quantity", 500);
        Item.Modify(true);

        Setup.GetSetup();
        Setup."Ordering Cost" := 50;
        Setup."Holding Rate" := 0.25;
        Setup."Max EOQ Months" := 24;
        Setup.Modify();
        ClearStatsCache();

        Assert.IsTrue(EOQCalc.Calculate(Item, false, ResultCode, AppliedQty), 'EOQ must calculate');
        Assert.AreEqual(500, AppliedQty, 'EOQ below Minimum Order Quantity must be raised to it');
        Assert.AreEqual(ResultCode::"Cap Applied", ResultCode, 'The adjustment must be surfaced as Cap Applied');
    end;

    [Test]
    procedure RunAll_MaximumQtyItem_WritesMaxInventoryAsROPPlusEOQ()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        RunAll: Codeunit "GSO Run All";
    begin
        Initialize();
        CreateItemWithSalesHistory(Item, 30, 10);
        Item.Get(Item."No.");
        Item.Validate("Last Direct Cost", 20);
        Item.Validate("Reordering Policy", Item."Reordering Policy"::"Maximum Qty.");
        Item.Modify(true);

        Setup.GetSetup();
        Setup."Ordering Cost" := 50;
        Setup."Holding Rate" := 0.25;
        Setup."Max EOQ Months" := 24;
        Setup.Modify();
        ClearStatsCache();

        RunAll.RunForItem(Item."No.", true);

        Item.Get(Item."No.");
        Assert.IsTrue(Item."Reorder Point" > 0, 'Reorder point must be calculated');
        Assert.IsTrue(Item."Reorder Quantity" > 0, 'EOQ must be calculated');
        Assert.AreEqual(
            Item."Reorder Point" + Item."Reorder Quantity", Item."Maximum Inventory",
            'Maximum Inventory must be the order-up-to level: reorder point + EOQ');
        Assert.IsTrue(Item."Reorder Point" < Item."Maximum Inventory", 'The Maximum Qty. parameter pair must be valid');
    end;

    [Test]
    procedure DemandStats_RecentOnlyDemand_TrendsUp()
    var
        Item: Record Item;
        DemandStats: Codeunit "GSO Demand Statistics";
    begin
        Initialize();
        // All demand inside the trailing 30-day sub-window of a 90-day window:
        // the recent daily average far exceeds the full-window average.
        CreateItemWithSalesHistoryOffset(Item, 20, 10, 1);
        ClearStatsCache();

        Assert.IsTrue(DemandStats.ComputeTrendPct(Item."No.", 90) > 50, 'Recent-only demand must report a strong upward trend');
    end;

    [Test]
    procedure DemandStats_OldOnlyDemand_TrendsDown()
    var
        Item: Record Item;
        DemandStats: Codeunit "GSO Demand Statistics";
    begin
        Initialize();
        // All demand 45-64 days ago, none in the trailing 30 days: recent
        // average is zero, i.e. a -100% trend (phase-out signature).
        CreateItemWithSalesHistoryOffset(Item, 20, 10, 45);
        ClearStatsCache();

        Assert.IsTrue(DemandStats.ComputeTrendPct(Item."No.", 90) < -50, 'Demand that stopped must report a strong downward trend');
    end;

    [Test]
    procedure PolicyAdvisor_SmoothDemand_RecommendsFixedReorderQty()
    var
        Item: Record Item;
        PolicyAdvisor: Codeunit "GSO Policy Advisor";
        Recommendation: Enum "GSO Policy Recommendation";
        Pattern: Text[30];
        Note: Text[250];
    begin
        Initialize();
        // Daily identical demand = ADI 1.0 (smooth), CV2 0 → Fixed Reorder Qty.
        CreateItemWithSalesHistory(Item, 30, 10);
        ClearStatsCache();

        Recommendation := PolicyAdvisor.AdvisePreview(Item."No.", Pattern, Note);

        Assert.AreEqual('Smooth', Pattern, 'Daily identical demand must classify as Smooth');
        Assert.AreEqual(Recommendation::"Fixed Reorder Qty.", Recommendation, 'Smooth demand without a cap must recommend Fixed Reorder Qty.');
    end;

    [Test]
    procedure PlanningProvider_Disabled_ReturnsFalse()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        Provider: Codeunit "GSO Planning Provider";
        SS: Decimal;
        ROP: Decimal;
        RQ: Decimal;
    begin
        Initialize();
        CreateItemWithSalesHistory(Item, 30, 10);
        Setup.GetSetup();
        Setup."Dynamic Provider Enabled" := false;
        Setup.Modify();

        Assert.IsFalse(Provider.TryGetPlanningValues(Item."No.", SS, ROP, RQ), 'Provider must fail closed when disabled');
    end;

    [Test]
    procedure PlanningProvider_Enabled_ServesAndCaches()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        Provider: Codeunit "GSO Planning Provider";
        SS: Decimal;
        ROP: Decimal;
        RQ: Decimal;
        SS2: Decimal;
        ROP2: Decimal;
        RQ2: Decimal;
    begin
        Initialize();
        CreateItemWithSalesHistory(Item, 30, 10);
        Setup.GetSetup();
        Setup."Dynamic Provider Enabled" := true;
        Setup.Modify();
        Provider.ClearCache();
        ClearStatsCache();

        Assert.IsTrue(Provider.TryGetPlanningValues(Item."No.", SS, ROP, RQ), 'Provider must serve values for a calculable item');
        Assert.IsTrue(ROP > 0, 'Provided reorder point must be positive');

        // Second call must serve identical values (from cache).
        Assert.IsTrue(Provider.TryGetPlanningValues(Item."No.", SS2, ROP2, RQ2), 'Cached call must succeed');
        Assert.AreEqual(ROP, ROP2, 'Cached reorder point must match computed one');

        Setup."Dynamic Provider Enabled" := false;
        Setup.Modify();
    end;

    [Test]
    procedure PlanningProvider_ExcludedItem_FailsOpen()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        Provider: Codeunit "GSO Planning Provider";
        SS: Decimal;
        ROP: Decimal;
        RQ: Decimal;
    begin
        Initialize();
        CreateItemWithSalesHistory(Item, 30, 10);
        Item.Get(Item."No.");
        Item."GSO Exclude From Planning" := true;
        Item.Modify();
        Setup.GetSetup();
        Setup."Dynamic Provider Enabled" := true;
        Setup.Modify();
        Provider.ClearCache();

        Assert.IsFalse(Provider.TryGetPlanningValues(Item."No.", SS, ROP, RQ), 'Excluded items must fail open so stored values stand');

        Setup."Dynamic Provider Enabled" := false;
        Setup.Modify();
    end;
}
