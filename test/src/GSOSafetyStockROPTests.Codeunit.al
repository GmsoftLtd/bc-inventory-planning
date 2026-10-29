namespace GMSoft.InventoryPlanning.Test;

using GMSoft.InventoryPlanning;
using Microsoft.Inventory.Item;
using System.TestLibraries.Utilities;

/// <summary>
/// Safety stock and reorder point calculators: service level priority,
/// setup switches, skip rules, explanations, logging and bulk runs.
/// The standard item (CreateItemWithDailySales) has 300 units of demand in a
/// 90-day window: average 10/3 a day, variance 2000/89, and no lead time
/// source but the 7-day setup fallback.
/// </summary>
codeunit 50204 "GSO Safety Stock ROP Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLib: Codeunit "GSO Test Library";
        GSOMath: Codeunit "GSO Math";

    local procedure ExpectedSafetyStock(ServiceLevelPct: Decimal): Decimal
    begin
        exit(Round(GSOMath.ZScore(ServiceLevelPct) * GSOMath.Sqrt(7 * 2000 / 89), 1, '>'));
    end;

    local procedure SetSetupBoolean(FieldNo: Integer; NewValue: Boolean)
    var
        Setup: Record "GSO Setup";
        SetupRef: RecordRef;
    begin
        Setup.GetSetup();
        SetupRef.GetTable(Setup);
        SetupRef.Field(FieldNo).Value := NewValue;
        SetupRef.Modify(false);
    end;

    [Test]
    procedure SafetyStock_MatchesFormula()
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);

        Assert.AreEqual(ExpectedSafetyStock(95), SafetyStockCalc.CalculateForItem(Item."No.", 95, false, ResultCode, Note), 'Z(95%) x sqrt(LT x variance), rounded up');
        Assert.AreEqual(ResultCode::OK, ResultCode, 'Result OK');
    end;

    [Test]
    procedure SafetyStock_ItemServiceLevel_UsedWhenNoneGiven()
    var
        Item: Record Item;
        LogEntry: Record "GSO Calculation Log";
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
        Result: Decimal;
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);
        Item."GSO Service Level %" := 99;
        Item.Modify(false);

        Result := SafetyStockCalc.CalculateForItem(Item."No.", 0, false, ResultCode, Note);

        Assert.AreEqual(ExpectedSafetyStock(99), Result, 'The item service level overrides setup');
        TestLib.FindLastLog(Item."No.", LogEntry."Calculation Type"::"Safety Stock", LogEntry);
        Assert.AreEqual(99, LogEntry."Service Level %", 'Logged service level');
    end;

    [Test]
    procedure SafetyStock_ExplicitServiceLevel_BeatsItem()
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);
        Item."GSO Service Level %" := 99;
        Item.Modify(false);

        Assert.AreEqual(ExpectedSafetyStock(90), SafetyStockCalc.CalculateForItem(Item."No.", 90, false, ResultCode, Note), 'An explicit service level wins');
    end;

    [Test]
    procedure SafetyStock_InvalidServiceLevel_FallsBackToSetup()
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);

        Assert.AreEqual(ExpectedSafetyStock(95), SafetyStockCalc.CalculateForItem(Item."No.", 150, false, ResultCode, Note), 'Above 100% is ignored; setup default 95% applies');
    end;

    [Test]
    procedure SafetyStock_ApplyOffInSetup_NotWritten()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        LogEntry: Record "GSO Calculation Log";
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        SetSetupBoolean(Setup.FieldNo("Apply Safety Stock"), false);
        TestLib.CreateItemWithDailySales(Item);

        Assert.IsTrue(SafetyStockCalc.CalculateForItem(Item."No.", 95, true, ResultCode, Note) > 0, 'Still calculated');

        Item.Get(Item."No.");
        Assert.AreEqual(0, Item."Safety Stock Quantity", 'Apply Safety Stock off must not write');
        TestLib.FindLastLog(Item."No.", LogEntry."Calculation Type"::"Safety Stock", LogEntry);
        Assert.IsFalse(LogEntry.Applied, 'Logged as not applied');
    end;

    [Test]
    procedure SafetyStock_ApplyFalse_NotWritten()
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);

        SafetyStockCalc.CalculateForItem(Item."No.", 95, false, ResultCode, Note);

        Item.Get(Item."No.");
        Assert.AreEqual(0, Item."Safety Stock Quantity", 'Apply = false must not write');
    end;

    [Test]
    procedure SafetyStock_Apply_WritesItem()
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);

        SafetyStockCalc.CalculateForItem(Item."No.", 95, true, ResultCode, Note);

        Item.Get(Item."No.");
        Assert.AreEqual(ExpectedSafetyStock(95), Item."Safety Stock Quantity", 'Applied to the item');
    end;

    [Test]
    procedure SafetyStock_MakeToOrder_Skipped()
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);
        Item."Manufacturing Policy" := Item."Manufacturing Policy"::"Make-to-Order";
        Item.Modify(false);

        Assert.AreEqual(0, SafetyStockCalc.CalculateForItem(Item."No.", 95, true, ResultCode, Note), 'MTO yields 0');
        Assert.AreEqual(ResultCode::"Make-to-Order Skipped", ResultCode, 'MTO result code');
    end;

    [Test]
    procedure SafetyStock_MakeToOrder_CalculatedWhenSkipOff()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        SetSetupBoolean(Setup.FieldNo("Skip Make-to-Order"), false);
        TestLib.CreateItemWithDailySales(Item);
        Item."Manufacturing Policy" := Item."Manufacturing Policy"::"Make-to-Order";
        Item.Modify(false);

        SafetyStockCalc.CalculateForItem(Item."No.", 95, false, ResultCode, Note);

        Assert.AreEqual(ResultCode::OK, ResultCode, 'With Skip Make-to-Order off, MTO items are calculated');
    end;

    [Test]
    procedure SafetyStock_NoLeadTime_SkipsWithResultCode()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        Setup.GetSetup();
        Setup."Default Lead Time (Days)" := 0;
        Setup.Modify(false);
        TestLib.CreateItemWithDailySales(Item);

        Assert.AreEqual(0, SafetyStockCalc.CalculateForItem(Item."No.", 95, true, ResultCode, Note), 'No lead time yields 0');
        Assert.AreEqual(ResultCode::"No Lead Time Data", ResultCode, 'No lead time result code');
    end;

    [Test]
    procedure SafetyStock_Note_BothVary()
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);
        TestLib.AddReceipt(Item."No.", 20, 10);
        TestLib.AddReceipt(Item."No.", 30, 16);

        SafetyStockCalc.CalculateForItem(Item."No.", 95, false, ResultCode, Note);

        Assert.IsTrue(StrPos(Note, 'demand and lead-time variability') > 0, 'Note must say both vary');
    end;

    [Test]
    procedure SafetyStock_Note_DemandVaries()
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);

        SafetyStockCalc.CalculateForItem(Item."No.", 95, false, ResultCode, Note);

        Assert.IsTrue(StrPos(Note, 'demand variability over a stable lead time') > 0, 'Note must say demand varies');
    end;

    [Test]
    procedure SafetyStock_Note_LeadTimeVaries()
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddSales(Item."No.", 0, 89, 1, 10, 10); // identical demand every day: no demand variance
        TestLib.AddReceipt(Item."No.", 20, 10);
        TestLib.AddReceipt(Item."No.", 30, 16);

        SafetyStockCalc.CalculateForItem(Item."No.", 95, false, ResultCode, Note);

        Assert.IsTrue(StrPos(Note, 'lead-time variability over stable demand') > 0, 'Note must say lead time varies');
    end;

    [Test]
    procedure SafetyStock_NoVariability_NoBuffer()
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddSales(Item."No.", 0, 89, 1, 10, 10);

        Assert.AreEqual(0, SafetyStockCalc.CalculateForItem(Item."No.", 95, false, ResultCode, Note), 'No variance, no buffer');
        Assert.IsTrue(StrPos(Note, 'No buffer needed') > 0, 'Note must explain the zero');
    end;

    [Test]
    procedure SafetyStock_IntermittentDemand_Warns()
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddSales(Item."No.", 1, 30, 3, 10, 10); // ADI 9

        SafetyStockCalc.CalculateForItem(Item."No.", 95, false, ResultCode, Note);

        Assert.IsTrue(StrPos(Note, 'intermittent demand') > 0, 'Z-score on intermittent demand must carry a warning');
    end;

    [Test]
    procedure SafetyStock_Preview_NoWriteNoLog()
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);

        Assert.AreEqual(ExpectedSafetyStock(95), SafetyStockCalc.CalculatePreview(Item."No.", ResultCode, Note), 'Preview calculates');

        Item.Get(Item."No.");
        Assert.AreEqual(0, Item."Safety Stock Quantity", 'Preview must not write');
        Assert.AreEqual(0, TestLib.CountLog(Item."No."), 'Preview must not log');
    end;

    [Test]
    procedure SafetyStock_Log_RecordsCalculation()
    var
        Item: Record Item;
        LogEntry: Record "GSO Calculation Log";
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);

        SafetyStockCalc.CalculateForItem(Item."No.", 95, true, ResultCode, Note);

        Assert.IsTrue(TestLib.FindLastLog(Item."No.", LogEntry."Calculation Type"::"Safety Stock", LogEntry), 'A log entry');
        Assert.AreEqual(95, LogEntry."Service Level %", 'Service level');
        Assert.AreNearlyEqual(GSOMath.ZScore(95), LogEntry."Z Score", 0.0001, 'Z score');
        Assert.AreNearlyEqual(TestLib.DailySalesAvgDemand(), LogEntry."Avg Daily Demand", 0.0001, 'Average demand');
        Assert.AreEqual(30, LogEntry."Demand Observations", 'Observations');
        Assert.AreEqual(7, LogEntry."Lead Time (Days)", 'Lead time');
        Assert.AreEqual('Setup fallback', LogEntry."Lead Time Source", 'Lead time source');
        Assert.AreEqual(ExpectedSafetyStock(95), LogEntry.Result, 'Result');
        Assert.AreEqual(0, LogEntry."Previous Value", 'Previous value');
        Assert.IsTrue(LogEntry.Applied, 'Applied');
        Assert.AreEqual(LogEntry."Result Code"::OK, LogEntry."Result Code", 'Result code');
        Assert.AreEqual(Note, LogEntry.Note, 'The logged note is the returned note');
    end;

    [Test]
    procedure SafetyStock_LogHistoryOff_NoLog()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        SetSetupBoolean(Setup.FieldNo("Log History"), false);
        TestLib.CreateItemWithDailySales(Item);

        SafetyStockCalc.CalculateForItem(Item."No.", 95, true, ResultCode, Note);

        Assert.AreEqual(0, TestLib.CountLog(Item."No."), 'Log History off must not log');
    end;

    [Test]
    procedure SafetyStock_SkippedItem_Logged()
    var
        Item: Record Item;
        LogEntry: Record "GSO Calculation Log";
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddSales(Item."No.", 1, 3, 1, 10, 10);

        SafetyStockCalc.CalculateForItem(Item."No.", 95, true, ResultCode, Note);

        Assert.IsTrue(TestLib.FindLastLog(Item."No.", LogEntry."Calculation Type"::"Safety Stock", LogEntry), 'Skips are logged too');
        Assert.AreEqual(LogEntry."Result Code"::"Insufficient Demand Data", LogEntry."Result Code", 'With the reason');
        Assert.AreEqual(3, LogEntry."Demand Observations", 'And the observations found');
    end;

    [Test]
    procedure SafetyStock_RoundUpOff_KeepsFraction()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
        Result: Decimal;
    begin
        TestLib.InitSetup();
        SetSetupBoolean(Setup.FieldNo("Round Up Results"), false);
        TestLib.CreateItemWithDailySales(Item);

        Result := SafetyStockCalc.CalculateForItem(Item."No.", 95, false, ResultCode, Note);

        Assert.AreNearlyEqual(GSOMath.ZScore(95) * GSOMath.Sqrt(7 * 2000 / 89), Result, 0.0001, 'Unrounded formula value');
        Assert.AreNotEqual(Round(Result, 1), Result, 'The value keeps its fraction');
    end;

    [Test]
    procedure SafetyStock_Bulk_ProcessesFilteredEligibleItems()
    var
        Item1, Item2, Excluded : Record Item;
        ItemFilter: Record Item;
        SafetyStockCalc: Codeunit "GSO Safety Stock";
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item1);
        TestLib.CreateItemWithDailySales(Item2);
        TestLib.CreateItemWithDailySales(Excluded);
        Excluded."GSO Exclude From Planning" := true;
        Excluded.Modify(false);
        ItemFilter.SetFilter("No.", '%1|%2|%3', Item1."No.", Item2."No.", Excluded."No.");

        Assert.AreEqual(2, SafetyStockCalc.CalculateBulk(ItemFilter, 95, true), 'Excluded items are left out of the count');

        Item1.Get(Item1."No.");
        Item2.Get(Item2."No.");
        Excluded.Get(Excluded."No.");
        Assert.IsTrue(Item1."Safety Stock Quantity" > 0, 'First item written');
        Assert.IsTrue(Item2."Safety Stock Quantity" > 0, 'Second item written');
        Assert.AreEqual(0, Excluded."Safety Stock Quantity", 'Excluded item untouched');
    end;

    [Test]
    procedure SafetyStock_Bulk_EmptyFilter_ReturnsZero()
    var
        ItemFilter: Record Item;
        SafetyStockCalc: Codeunit "GSO Safety Stock";
    begin
        TestLib.InitSetup();
        ItemFilter.SetRange("No.", 'GSO-NO-SUCH-ITEM');

        Assert.AreEqual(0, SafetyStockCalc.CalculateBulk(ItemFilter, 95, true), 'Nothing to process');
    end;

    [Test]
    procedure ReorderPoint_MatchesFormula()
    var
        Item: Record Item;
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);

        // 10/3 a day x 7 days = 23.33, rounded up; stored safety stock is 0.
        Assert.AreEqual(24, ReorderPointCalc.CalculateForItem(Item."No.", false, -1, ResultCode, Note), 'Demand during lead time');
    end;

    [Test]
    procedure ReorderPoint_AddsStoredSafetyStock()
    var
        Item: Record Item;
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);
        Item."Safety Stock Quantity" := 50;
        Item.Modify(false);

        Assert.AreEqual(74, ReorderPointCalc.CalculateForItem(Item."No.", false, -1, ResultCode, Note), '23.33 + 50, rounded up');
    end;

    [Test]
    procedure ReorderPoint_OverrideBeatsStoredSafetyStock()
    var
        Item: Record Item;
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);
        Item."Safety Stock Quantity" := 50;
        Item.Modify(false);

        Assert.AreEqual(34, ReorderPointCalc.CalculateForItem(Item."No.", false, 10, ResultCode, Note), '23.33 + override 10, rounded up');
    end;

    [Test]
    procedure ReorderPoint_IncludeSafetyStockOff_IgnoresIt()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        SetSetupBoolean(Setup.FieldNo("Include Safety Stock"), false);
        TestLib.CreateItemWithDailySales(Item);
        Item."Safety Stock Quantity" := 50;
        Item.Modify(false);

        Assert.AreEqual(24, ReorderPointCalc.CalculateForItem(Item."No.", false, -1, ResultCode, Note), 'Stored safety stock ignored');
        Assert.AreEqual(24, ReorderPointCalc.CalculateForItem(Item."No.", false, 10, ResultCode, Note), 'Override ignored');
    end;

    [Test]
    procedure ReorderPoint_BlankPolicy_StampedFixedReorderQty()
    var
        Item: Record Item;
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);

        ReorderPointCalc.CalculateForItem(Item."No.", true, -1, ResultCode, Note);

        Item.Get(Item."No.");
        Assert.AreEqual(Item."Reordering Policy"::"Fixed Reorder Qty.", Item."Reordering Policy", 'Set Policy When None stamps Fixed Reorder Qty.');
        Assert.AreEqual(24, Item."Reorder Point", 'And writes the reorder point');
    end;

    [Test]
    procedure ReorderPoint_PolicyDefaultNotAllowed_StaysBlank()
    var
        Item: Record Item;
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);

        ReorderPointCalc.CalculateForItem(Item."No.", true, -1, false, ResultCode, Note);

        Item.Get(Item."No.");
        Assert.AreEqual(Item."Reordering Policy"::" ", Item."Reordering Policy", 'Run All''s veto must hold');
    end;

    [Test]
    procedure ReorderPoint_SetPolicyWhenNoneOff_StaysBlank()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        SetSetupBoolean(Setup.FieldNo("Set Policy When None"), false);
        TestLib.CreateItemWithDailySales(Item);

        ReorderPointCalc.CalculateForItem(Item."No.", true, -1, ResultCode, Note);

        Item.Get(Item."No.");
        Assert.AreEqual(Item."Reordering Policy"::" ", Item."Reordering Policy", 'Setting off: no policy stamped');
    end;

    [Test]
    procedure ReorderPoint_ExistingPolicy_Kept()
    var
        Item: Record Item;
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);
        Item."Reordering Policy" := Item."Reordering Policy"::"Lot-for-Lot";
        Item.Modify(false);

        ReorderPointCalc.CalculateForItem(Item."No.", true, -1, ResultCode, Note);

        Item.Get(Item."No.");
        Assert.AreEqual(Item."Reordering Policy"::"Lot-for-Lot", Item."Reordering Policy", 'An existing policy is never replaced');
    end;

    [Test]
    procedure ReorderPoint_ApplyOffInSetup_NotWritten()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        SetSetupBoolean(Setup.FieldNo("Apply Reorder Point"), false);
        TestLib.CreateItemWithDailySales(Item);

        Assert.AreEqual(24, ReorderPointCalc.CalculateForItem(Item."No.", true, -1, ResultCode, Note), 'Still calculated');

        Item.Get(Item."No.");
        Assert.AreEqual(0, Item."Reorder Point", 'Apply Reorder Point off must not write');
    end;

    [Test]
    procedure ReorderPoint_NoLeadTime_SkipsWithResultCode()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        Setup.GetSetup();
        Setup."Default Lead Time (Days)" := 0;
        Setup.Modify(false);
        TestLib.CreateItemWithDailySales(Item);

        ReorderPointCalc.CalculateForItem(Item."No.", true, -1, ResultCode, Note);

        Assert.AreEqual(ResultCode::"No Lead Time Data", ResultCode, 'No lead time result code');
    end;

    [Test]
    procedure ReorderPoint_InsufficientHistory_SkipsWithResultCode()
    var
        Item: Record Item;
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddSales(Item."No.", 1, 3, 1, 10, 10);

        Assert.AreEqual(0, ReorderPointCalc.CalculateForItem(Item."No.", true, -1, ResultCode, Note), 'Too little history yields 0');
        Assert.AreEqual(ResultCode::"Insufficient Demand Data", ResultCode, 'Insufficient data result code');
    end;

    [Test]
    procedure ReorderPoint_BlockedItem_Skipped()
    var
        Item: Record Item;
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);
        Item.Blocked := true;
        Item.Modify(false);

        ReorderPointCalc.CalculateForItem(Item."No.", true, -1, ResultCode, Note);

        Assert.AreEqual(ResultCode::"Item Blocked", ResultCode, 'Blocked result code');
    end;

    [Test]
    procedure ReorderPoint_ExcludedItem_Skipped()
    var
        Item: Record Item;
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);
        Item."Reorder Point" := 42;
        Item."GSO Exclude From Planning" := true;
        Item.Modify(false);

        ReorderPointCalc.CalculateForItem(Item."No.", true, -1, ResultCode, Note);

        Assert.AreEqual(ResultCode::Excluded, ResultCode, 'Excluded result code');
        Item.Get(Item."No.");
        Assert.AreEqual(42, Item."Reorder Point", 'The manual value survives');
    end;

    [Test]
    procedure ReorderPoint_NonInventoryItem_Skipped()
    var
        Item: Record Item;
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);
        Item.Type := Item.Type::"Non-Inventory";
        Item.Modify(false);

        ReorderPointCalc.CalculateForItem(Item."No.", true, -1, ResultCode, Note);

        Assert.AreEqual(ResultCode::"Not an Inventory Item", ResultCode, 'Non-inventory result code');
    end;

    [Test]
    procedure ReorderPoint_UnknownItem_ReturnsZero()
    var
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();

        Assert.AreEqual(0, ReorderPointCalc.CalculateForItem('GSO-NO-SUCH-ITEM', true, -1, ResultCode, Note), 'An unknown item yields 0 without an error');
    end;

    [Test]
    procedure ReorderPoint_Cap_ExplainedInNote()
    var
        Item: Record Item;
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);
        Item."Maximum Inventory" := 5;
        Item.Modify(false);

        ReorderPointCalc.CalculateForItem(Item."No.", false, -1, ResultCode, Note);

        Assert.IsTrue(StrPos(Note, 'Capped at Maximum Inventory') > 0, 'The cap must be explained');
    end;

    [Test]
    procedure ReorderPoint_IgnoreMaxInventoryCap_NotCapped()
    var
        Item: Record Item;
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);
        Item."Maximum Inventory" := 5;
        Item.Modify(false);

        ReorderPointCalc.SetIgnoreMaxInventoryCap(true);

        Assert.AreEqual(24, ReorderPointCalc.CalculateForItem(Item."No.", false, -1, ResultCode, Note), 'No cap when told to ignore it');
        Assert.AreEqual(ResultCode::OK, ResultCode, 'Not Cap Applied');
    end;

    [Test]
    procedure ReorderPoint_PreviewWithOverride_NoWriteNoLog()
    var
        Item: Record Item;
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);

        Assert.AreEqual(34, ReorderPointCalc.CalculatePreview(Item."No.", 10, ResultCode, Note), 'Preview uses the given safety stock');

        Item.Get(Item."No.");
        Assert.AreEqual(0, Item."Reorder Point", 'Preview must not write');
        Assert.AreEqual(0, TestLib.CountLog(Item."No."), 'Preview must not log');
    end;

    [Test]
    procedure ReorderPoint_Log_RecordsSafetyStockComponent()
    var
        Item: Record Item;
        LogEntry: Record "GSO Calculation Log";
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);
        Item."Reorder Point" := 3;
        Item."Safety Stock Quantity" := 50;
        Item.Modify(false);

        ReorderPointCalc.CalculateForItem(Item."No.", true, -1, ResultCode, Note);

        Assert.IsTrue(TestLib.FindLastLog(Item."No.", LogEntry."Calculation Type"::"Reorder Point", LogEntry), 'A log entry');
        Assert.AreEqual(50, LogEntry."Raw Result", 'Raw Result holds the safety stock component');
        Assert.AreEqual(74, LogEntry.Result, 'Result');
        Assert.AreEqual(3, LogEntry."Previous Value", 'Previous value');
        Assert.AreEqual(7, LogEntry."Lead Time (Days)", 'Lead time');
        Assert.AreEqual(30, LogEntry."Demand Observations", 'Observations');
        Assert.IsTrue(LogEntry.Applied, 'Applied');
    end;

    [Test]
    procedure ReorderPoint_Bulk_ProcessesFilteredItems()
    var
        Item1, Item2 : Record Item;
        ItemFilter: Record Item;
        ReorderPointCalc: Codeunit "GSO Reorder Point";
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item1);
        TestLib.CreateItemWithDailySales(Item2);
        ItemFilter.SetFilter("No.", '%1|%2', Item1."No.", Item2."No.");

        Assert.AreEqual(2, ReorderPointCalc.CalculateBulk(ItemFilter, true), 'Two items');

        Item1.Get(Item1."No.");
        Item2.Get(Item2."No.");
        Assert.AreEqual(24, Item1."Reorder Point", 'First item written');
        Assert.AreEqual(24, Item2."Reorder Point", 'Second item written');
    end;
}
