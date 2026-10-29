namespace GMSoft.InventoryPlanning.Test;

using GMSoft.InventoryPlanning;
using Microsoft.Inventory.Item;
using System.TestLibraries.Utilities;

/// <summary>
/// EOQ calculator: the Wilson value, caps, order modifiers, cost sources,
/// write targets, skip rules, logging and bulk runs. The standard item has
/// annual demand 300/90 x 365, Last Direct Cost 20, ordering cost 50 and
/// holding rate 0.25 (holding cost 5).
/// </summary>
codeunit 50205 "GSO EOQ Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLib: Codeunit "GSO Test Library";

    local procedure AnnualDemand(): Decimal
    begin
        exit(300 / 90 * 365);
    end;

    local procedure RawEOQ(HoldingCost: Decimal): Decimal
    begin
        exit(Power(2 * AnnualDemand() * 50 / HoldingCost, 0.5));
    end;

    local procedure ModifySetup(var Setup: Record "GSO Setup")
    begin
        Setup.Modify(false);
        TestLib.ClearCaches();
    end;

    [Test]
    procedure EOQ_WilsonValue()
    var
        Item: Record Item;
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        Qty: Decimal;
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);

        Assert.IsTrue(EOQCalc.Calculate(Item, false, ResultCode, Qty), 'EOQ must calculate');
        Assert.AreEqual(Round(RawEOQ(5), 1, '>'), Qty, 'sqrt(2DS/H), rounded up');
        Assert.AreEqual(ResultCode::OK, ResultCode, 'Result OK');
    end;

    [Test]
    procedure EOQ_MonthsCap_LimitsQuantity()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        Qty: Decimal;
    begin
        TestLib.InitSetup();
        Setup.GetSetup();
        Setup."Max EOQ Months" := 1;
        ModifySetup(Setup);
        TestLib.CreateItemWithDailySales(Item);

        EOQCalc.Calculate(Item, false, ResultCode, Qty);

        Assert.AreEqual(Round(AnnualDemand() / 12, 1, '>'), Qty, 'Capped at one month of demand');
        Assert.AreEqual(ResultCode::"Cap Applied", ResultCode, 'The cap is reported');
    end;

    [Test]
    procedure EOQ_RoundUpOff_KeepsFiveDecimals()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        Qty: Decimal;
    begin
        TestLib.InitSetup();
        Setup.GetSetup();
        Setup."Round Up Results" := false;
        ModifySetup(Setup);
        TestLib.CreateItemWithDailySales(Item);

        EOQCalc.Calculate(Item, false, ResultCode, Qty);

        Assert.AreEqual(Round(RawEOQ(5), 0.00001), Qty, 'Rounded to five decimals, not up');
    end;

    [Test]
    procedure EOQ_OrderMultiple_RoundsUp()
    var
        Item: Record Item;
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        Qty: Decimal;
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);
        Item."Order Multiple" := 50;
        Item.Modify(false);

        EOQCalc.Calculate(Item, false, ResultCode, Qty);

        Assert.AreEqual(200, Qty, '156 rounded up to a multiple of 50');
        Assert.AreEqual(ResultCode::OK, ResultCode, 'Rounding to the multiple is not a cap');
    end;

    [Test]
    procedure EOQ_MaximumOrderQty_Reduces()
    var
        Item: Record Item;
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        Qty: Decimal;
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);
        Item."Maximum Order Quantity" := 100;
        Item.Modify(false);

        Assert.IsTrue(EOQCalc.Calculate(Item, false, ResultCode, Qty), 'EOQ must calculate');

        Assert.AreEqual(100, Qty, 'Reduced to Maximum Order Quantity');
        Assert.AreEqual(ResultCode::"Cap Applied", ResultCode, 'The reduction is reported');
    end;

    [Test]
    procedure EOQ_MaximumOrderQtyWithMultiple_StaysOrderable()
    var
        Item: Record Item;
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        Qty: Decimal;
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);
        Item."Maximum Order Quantity" := 100;
        Item."Order Multiple" := 30;
        Item.Modify(false);

        EOQCalc.Calculate(Item, false, ResultCode, Qty);

        Assert.AreEqual(90, Qty, 'Largest multiple of 30 not above 100');
    end;

    [Test]
    procedure EOQ_MinimumOrderQty_Raises()
    var
        Item: Record Item;
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        Qty: Decimal;
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);
        Item."Minimum Order Quantity" := 500;
        Item.Modify(false);

        EOQCalc.Calculate(Item, false, ResultCode, Qty);

        Assert.AreEqual(500, Qty, 'Raised to Minimum Order Quantity');
        Assert.AreEqual(ResultCode::"Cap Applied", ResultCode, 'The raise is reported');
    end;

    [Test]
    procedure EOQ_CostSource_StandardCost()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        Qty: Decimal;
    begin
        TestLib.InitSetup();
        Setup.GetSetup();
        Setup."Cost Source" := Setup."Cost Source"::"Standard Cost";
        ModifySetup(Setup);
        TestLib.CreateItemWithDailySales(Item);
        Item."Standard Cost" := 80;
        Item.Modify(false);

        EOQCalc.Calculate(Item, false, ResultCode, Qty);

        Assert.AreEqual(Round(RawEOQ(80 * 0.25), 1, '>'), Qty, 'Holding cost from Standard Cost');
    end;

    [Test]
    procedure EOQ_CostSource_UnitCost()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        Qty: Decimal;
    begin
        TestLib.InitSetup();
        Setup.GetSetup();
        Setup."Cost Source" := Setup."Cost Source"::"Unit Cost";
        ModifySetup(Setup);
        TestLib.CreateItemWithDailySales(Item);
        Item."Unit Cost" := 5;
        Item.Modify(false);

        EOQCalc.Calculate(Item, false, ResultCode, Qty);

        Assert.AreEqual(Round(RawEOQ(5 * 0.25), 1, '>'), Qty, 'Holding cost from Unit Cost');
    end;

    [Test]
    procedure EOQ_ZeroUnitCost_SkipsWithResultCode()
    var
        Item: Record Item;
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        Qty: Decimal;
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);
        Item."Last Direct Cost" := 0;
        Item.Modify(false);

        Assert.IsFalse(EOQCalc.Calculate(Item, true, ResultCode, Qty), 'Zero cost must fail');
        Assert.AreEqual(ResultCode::"Zero Unit Cost", ResultCode, 'Zero unit cost result code');
        Assert.AreEqual(0, Qty, 'No quantity');
    end;

    [Test]
    procedure EOQ_ZeroDemand_SkipsWithResultCode()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        Qty: Decimal;
    begin
        TestLib.InitSetup();
        Setup.GetSetup();
        Setup."Min Demand Observations" := 0;
        ModifySetup(Setup);
        TestLib.CreateItem(Item); // no history at all

        Assert.IsFalse(EOQCalc.Calculate(Item, true, ResultCode, Qty), 'No demand must fail');
        Assert.AreEqual(ResultCode::"Zero Demand", ResultCode, 'Zero demand result code');
    end;

    [Test]
    procedure EOQ_InsufficientHistory_SkipsWithResultCode()
    var
        Item: Record Item;
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        Qty: Decimal;
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddSales(Item."No.", 1, 3, 1, 10, 10);

        Assert.IsFalse(EOQCalc.Calculate(Item, true, ResultCode, Qty), 'Too little history must fail');
        Assert.AreEqual(ResultCode::"Insufficient Demand Data", ResultCode, 'Insufficient data result code');
    end;

    [Test]
    procedure EOQ_BlockedItem_Skipped()
    var
        Item: Record Item;
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        Qty: Decimal;
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);
        Item.Blocked := true;
        Item.Modify(false);

        Assert.IsFalse(EOQCalc.Calculate(Item, true, ResultCode, Qty), 'Blocked must fail');
        Assert.AreEqual(ResultCode::"Item Blocked", ResultCode, 'Blocked result code');
    end;

    [Test]
    procedure EOQ_ExcludedItem_Skipped()
    var
        Item: Record Item;
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        Qty: Decimal;
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);
        Item."GSO Exclude From Planning" := true;
        Item.Modify(false);

        Assert.IsFalse(EOQCalc.Calculate(Item, true, ResultCode, Qty), 'Excluded must fail');
        Assert.AreEqual(ResultCode::Excluded, ResultCode, 'Excluded result code');
    end;

    [Test]
    procedure EOQ_NonInventoryItem_Skipped()
    var
        Item: Record Item;
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        Qty: Decimal;
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);
        Item.Type := Item.Type::Service;
        Item.Modify(false);

        Assert.IsFalse(EOQCalc.Calculate(Item, true, ResultCode, Qty), 'Service items must fail');
        Assert.AreEqual(ResultCode::"Not an Inventory Item", ResultCode, 'Non-inventory result code');
    end;

    [Test]
    procedure EOQ_Apply_WritesReorderQuantity()
    var
        Item: Record Item;
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        Qty: Decimal;
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);

        EOQCalc.Calculate(Item, true, ResultCode, Qty);

        Item.Get(Item."No.");
        Assert.AreEqual(Qty, Item."Reorder Quantity", 'Written to Reorder Quantity');
        Assert.AreEqual(Item."Reordering Policy"::"Fixed Reorder Qty.", Item."Reordering Policy", 'Set Policy When None stamps Fixed Reorder Qty.');
    end;

    [Test]
    procedure EOQ_PolicyDefaultNotAllowed_StaysBlank()
    var
        Item: Record Item;
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        Qty: Decimal;
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);

        EOQCalc.Calculate(Item, true, false, ResultCode, Qty);

        Item.Get(Item."No.");
        Assert.AreEqual(Item."Reordering Policy"::" ", Item."Reordering Policy", 'Run All''s veto must hold');
        Assert.AreEqual(Qty, Item."Reorder Quantity", 'The quantity is still written');
    end;

    [Test]
    procedure EOQ_WriteTargetOrderMultiple_NoModifiers()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        Qty: Decimal;
    begin
        TestLib.InitSetup();
        Setup.GetSetup();
        Setup."EOQ Write Target" := Setup."EOQ Write Target"::"Order Multiple";
        ModifySetup(Setup);
        TestLib.CreateItemWithDailySales(Item);
        Item."Maximum Order Quantity" := 100;
        Item.Modify(false);

        EOQCalc.Calculate(Item, true, ResultCode, Qty);

        Assert.AreEqual(Round(RawEOQ(5), 1, '>'), Qty, 'Order modifiers apply only when writing Reorder Quantity');
        Item.Get(Item."No.");
        Assert.AreEqual(Qty, Item."Order Multiple", 'Written to Order Multiple');
        Assert.AreEqual(0, Item."Reorder Quantity", 'Reorder Quantity untouched');
        Assert.AreEqual(Item."Reordering Policy"::" ", Item."Reordering Policy", 'No policy stamped for the Order Multiple target');
    end;

    [Test]
    procedure EOQ_ApplyOffInSetup_NotWritten()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        Qty: Decimal;
    begin
        TestLib.InitSetup();
        Setup.GetSetup();
        Setup."Apply EOQ" := false;
        ModifySetup(Setup);
        TestLib.CreateItemWithDailySales(Item);

        Assert.IsTrue(EOQCalc.Calculate(Item, true, ResultCode, Qty), 'Still calculated');

        Item.Get(Item."No.");
        Assert.AreEqual(0, Item."Reorder Quantity", 'Apply EOQ off must not write');
    end;

    [Test]
    procedure EOQ_Preview_NoWriteNoLog()
    var
        Item: Record Item;
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        Qty: Decimal;
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);

        Assert.IsTrue(EOQCalc.CalculatePreview(Item, ResultCode, Qty), 'Preview calculates');

        Item.Get(Item."No.");
        Assert.AreEqual(0, Item."Reorder Quantity", 'Preview must not write');
        Assert.AreEqual(0, TestLib.CountLog(Item."No."), 'Preview must not log');
    end;

    [Test]
    procedure EOQ_Log_RecordsCalculation()
    var
        Item: Record Item;
        LogEntry: Record "GSO Calculation Log";
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        Qty: Decimal;
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);
        Item."Reorder Quantity" := 7;
        Item.Modify(false);

        EOQCalc.Calculate(Item, true, ResultCode, Qty);

        Assert.IsTrue(TestLib.FindLastLog(Item."No.", LogEntry."Calculation Type"::EOQ, LogEntry), 'A log entry');
        Assert.AreEqual(30, LogEntry."Demand Observations", 'Observations');
        Assert.AreNearlyEqual(AnnualDemand(), LogEntry."Annual Demand", 0.0001, 'Annual demand');
        Assert.AreEqual(20, LogEntry."Unit Cost", 'Unit cost');
        Assert.AreEqual(5, LogEntry."Holding Cost", 'Holding cost');
        Assert.AreEqual(50, LogEntry."Ordering Cost", 'Ordering cost');
        Assert.AreNearlyEqual(RawEOQ(5), LogEntry."Raw Result", 0.0001, 'Raw EOQ');
        Assert.AreEqual(Qty, LogEntry.Result, 'Result');
        Assert.AreEqual(7, LogEntry."Previous Value", 'Previous value');
        Assert.IsTrue(LogEntry.Applied, 'Applied');
    end;

    [Test]
    procedure EOQ_Bulk_ProcessesFilteredItems()
    var
        Item1, Item2 : Record Item;
        ItemFilter: Record Item;
        EOQCalc: Codeunit "GSO EOQ";
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item1);
        TestLib.CreateItemWithDailySales(Item2);
        ItemFilter.SetFilter("No.", '%1|%2', Item1."No.", Item2."No.");

        Assert.AreEqual(2, EOQCalc.CalculateBulk(ItemFilter, true), 'Two items');

        Item1.Get(Item1."No.");
        Item2.Get(Item2."No.");
        Assert.AreEqual(Round(RawEOQ(5), 1, '>'), Item1."Reorder Quantity", 'First item written');
        Assert.AreEqual(Round(RawEOQ(5), 1, '>'), Item2."Reorder Quantity", 'Second item written');
    end;
}
