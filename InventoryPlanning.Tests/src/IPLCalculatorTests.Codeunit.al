/// <summary>
/// End-to-end calculator tests on crafted demand history. Items and postings
/// are created through the standard test libraries; each test posts a known
/// pattern of sales and asserts the calculator's behaviour and guard rails.
/// </summary>
codeunit 50601 "IPL Calculator Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        IsInitialized: Boolean;

    local procedure Initialize()
    var
        Setup: Record "IPL Setup";
    begin
        if IsInitialized then
            exit;
        Setup.GetSetup();
        Setup."History Window (Days)" := 90;
        Setup."Min Demand Observations" := 5;
        Setup."Default Lead Time (Days)" := 7;
        Setup."Log History" := true;
        Setup.Modify();
        IsInitialized := true;
    end;

    local procedure CreateItemWithSalesHistory(var Item: Record Item; DemandDays: Integer; QtyPerDay: Decimal)
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
        for i := 1 to DemandDays do begin
            LibraryInventory.CreateItemJournalLineInItemTemplate(
                ItemJournalLine, Item."No.", '', '', QtyPerDay);
            ItemJournalLine.Validate("Entry Type", ItemJournalLine."Entry Type"::Sale);
            ItemJournalLine.Validate("Posting Date", CalcDate(StrSubstNo('<-%1D>', i), WorkDate()));
            ItemJournalLine.Validate(Quantity, QtyPerDay);
            ItemJournalLine.Modify(true);
            LibraryInventory.PostItemJournalLine(ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name");
        end;
    end;

    [Test]
    procedure DemandStats_SteadyDailySales_YieldsExpectedAverage()
    var
        Item: Record Item;
        DemandStats: Codeunit "IPL Demand Statistics";
        AvgDemand: Decimal;
        StdDev: Decimal;
        Observations: Integer;
        ADI: Decimal;
        CV2: Decimal;
    begin
        Initialize();
        CreateItemWithSalesHistory(Item, 30, 10);

        DemandStats.ComputeDemandStats(Item."No.", 90, AvgDemand, StdDev, Observations, ADI, CV2);

        Assert.AreEqual(30, Observations, '30 demand days posted must yield 30 observations');
        Assert.IsTrue(AvgDemand > 0, 'Average demand must be positive');
        // 300 units over a ~91-day calendar window.
        Assert.AreNearlyEqual(300 / 91, AvgDemand, 0.5, 'Average daily demand must be total/calendar days');
        Assert.IsTrue(CV2 < 0.01, 'Identical daily quantities must give near-zero CV2');
    end;

    [Test]
    procedure SafetyStock_InsufficientHistory_SkipsWithResultCode()
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "IPL Safety Stock";
        ResultCode: Enum "IPL Result Code";
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
        SafetyStockCalc: Codeunit "IPL Safety Stock";
        ResultCode: Enum "IPL Result Code";
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
    procedure ReorderPoint_MakeToOrderItem_Skipped()
    var
        Item: Record Item;
        ReorderPointCalc: Codeunit "IPL Reorder Point";
        ResultCode: Enum "IPL Result Code";
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
        ReorderPointCalc: Codeunit "IPL Reorder Point";
        ResultCode: Enum "IPL Result Code";
        Note: Text[250];
        Result: Decimal;
    begin
        Initialize();
        CreateItemWithSalesHistory(Item, 20, 8);

        Result := ReorderPointCalc.CalculateForItem(Item."No.", true, 0, ResultCode, Note);

        Assert.AreEqual(ResultCode::OK, ResultCode, 'Calculation must succeed with 20 demand days');
        Assert.IsTrue(Result > 0, 'Reorder point must be positive');
        Item.Get(Item."No.");
        Assert.AreEqual(Result, Item."Reorder Point", 'Applied result must be written to the item');
    end;

    [Test]
    procedure EOQ_ZeroOrderingCost_SkipsWithResultCode()
    var
        Item: Record Item;
        Setup: Record "IPL Setup";
        EOQCalc: Codeunit "IPL EOQ";
        ResultCode: Enum "IPL Result Code";
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
        Setup: Record "IPL Setup";
        EOQCalc: Codeunit "IPL EOQ";
        IPLMath: Codeunit "IPL Math";
        ResultCode: Enum "IPL Result Code";
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

        Assert.IsTrue(EOQCalc.Calculate(Item, false, ResultCode, AppliedQty), 'EOQ must calculate');
        Assert.IsTrue(AppliedQty > 0, 'EOQ must be positive');
    end;

    [Test]
    procedure PolicyAdvisor_SmoothDemand_RecommendsFixedReorderQty()
    var
        Item: Record Item;
        PolicyAdvisor: Codeunit "IPL Policy Advisor";
        Recommendation: Enum "IPL Policy Recommendation";
        Pattern: Text[30];
        Note: Text[250];
    begin
        Initialize();
        // Daily identical demand = ADI 1.0 (smooth), CV2 0 → Fixed Reorder Qty.
        CreateItemWithSalesHistory(Item, 30, 10);

        Recommendation := PolicyAdvisor.AdvisePreview(Item."No.", Pattern, Note);

        Assert.AreEqual('Smooth', Pattern, 'Daily identical demand must classify as Smooth');
        Assert.AreEqual(Recommendation::"Fixed Reorder Qty.", Recommendation, 'Smooth demand without a cap must recommend Fixed Reorder Qty.');
    end;

    [Test]
    procedure PlanningProvider_Disabled_ReturnsFalse()
    var
        Item: Record Item;
        Setup: Record "IPL Setup";
        Provider: Codeunit "IPL Planning Provider";
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
        Setup: Record "IPL Setup";
        Provider: Codeunit "IPL Planning Provider";
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

        Assert.IsTrue(Provider.TryGetPlanningValues(Item."No.", SS, ROP, RQ), 'Provider must serve values for a calculable item');
        Assert.IsTrue(ROP > 0, 'Provided reorder point must be positive');

        // Second call must serve identical values (from cache).
        Assert.IsTrue(Provider.TryGetPlanningValues(Item."No.", SS2, ROP2, RQ2), 'Cached call must succeed');
        Assert.AreEqual(ROP, ROP2, 'Cached reorder point must match computed one');

        Setup."Dynamic Provider Enabled" := false;
        Setup.Modify();
    end;
}
