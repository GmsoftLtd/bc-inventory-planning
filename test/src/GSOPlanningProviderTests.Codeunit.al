namespace GMSoft.InventoryPlanning.Test;

using GMSoft.InventoryPlanning;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Planning;
using System.TestLibraries.Utilities;

/// <summary>
/// Dynamic planning provider, called the way the planning engine calls it:
/// through Planning-Get Parameters.AtSKU, which raises the event the
/// provider subscribes to.
/// </summary>
codeunit 50208 "GSO Planning Provider Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLib: Codeunit "GSO Test Library";

    local procedure EnableProvider()
    var
        Setup: Record "GSO Setup";
    begin
        Setup.GetSetup();
        Setup."Dynamic Provider Enabled" := true;
        Setup.Modify(false);
    end;

    local procedure CreatePlannedItem(var Item: Record Item)
    begin
        TestLib.CreateItemWithDailySales(Item);
        Item."Reordering Policy" := Item."Reordering Policy"::"Fixed Reorder Qty.";
        Item."Safety Stock Quantity" := 3;
        Item."Reorder Point" := 4;
        Item."Reorder Quantity" := 5;
        Item.Modify(false);
    end;

    [Test]
    procedure AtSKU_NoRealSKU_SuppliesCalculatedValues()
    var
        Item: Record Item;
        TempSKU: Record "Stockkeeping Unit" temporary;
        Provider: Codeunit "GSO Planning Provider";
        PlanningGetParameters: Codeunit "Planning-Get Parameters";
        SS, ROP, RQ : Decimal;
    begin
        TestLib.InitSetup();
        EnableProvider();
        CreatePlannedItem(Item);
        Assert.IsTrue(Provider.TryGetPlanningValues(Item."No.", SS, ROP, RQ), 'Provider serves values');

        PlanningGetParameters.AtSKU(TempSKU, Item."No.", '', '');

        Assert.AreEqual(SS, TempSKU."Safety Stock Quantity", 'Planning reads the calculated safety stock');
        Assert.AreEqual(ROP, TempSKU."Reorder Point", 'Planning reads the calculated reorder point');
        Assert.AreEqual(RQ, TempSKU."Reorder Quantity", 'Planning reads the calculated EOQ');
        Assert.AreNotEqual(4, TempSKU."Reorder Point", 'Not the stored item value');
    end;

    [Test]
    procedure AtSKU_RealSKU_LeftAlone()
    var
        Item: Record Item;
        Location: Record Location;
        StockkeepingUnit: Record "Stockkeeping Unit";
        TempSKU: Record "Stockkeeping Unit" temporary;
        PlanningGetParameters: Codeunit "Planning-Get Parameters";
    begin
        TestLib.InitSetup();
        EnableProvider();
        CreatePlannedItem(Item);
        Location.Init();
        Location.Code := 'GSOTEST';
        Location.Insert(false);
        StockkeepingUnit.Init();
        StockkeepingUnit."Location Code" := Location.Code;
        StockkeepingUnit."Item No." := Item."No.";
        StockkeepingUnit."Reordering Policy" := StockkeepingUnit."Reordering Policy"::"Fixed Reorder Qty.";
        StockkeepingUnit."Safety Stock Quantity" := 11;
        StockkeepingUnit."Reorder Point" := 12;
        StockkeepingUnit."Reorder Quantity" := 13;
        StockkeepingUnit.Insert(false);

        PlanningGetParameters.AtSKU(TempSKU, Item."No.", '', Location.Code);

        Assert.AreEqual(11, TempSKU."Safety Stock Quantity", 'A real SKU keeps its own safety stock');
        Assert.AreEqual(12, TempSKU."Reorder Point", 'A real SKU keeps its own reorder point');
        Assert.AreEqual(13, TempSKU."Reorder Quantity", 'A real SKU keeps its own reorder quantity');
    end;

    [Test]
    procedure AtSKU_ProviderDisabled_ItemValues()
    var
        Item: Record Item;
        TempSKU: Record "Stockkeeping Unit" temporary;
        PlanningGetParameters: Codeunit "Planning-Get Parameters";
    begin
        TestLib.InitSetup();
        CreatePlannedItem(Item);

        PlanningGetParameters.AtSKU(TempSKU, Item."No.", '', '');

        Assert.AreEqual(3, TempSKU."Safety Stock Quantity", 'Disabled provider: stored safety stock');
        Assert.AreEqual(4, TempSKU."Reorder Point", 'Disabled provider: stored reorder point');
        Assert.AreEqual(5, TempSKU."Reorder Quantity", 'Disabled provider: stored reorder quantity');
    end;

    [Test]
    procedure AtSKU_UncalculableItem_FailsOpen()
    var
        Item: Record Item;
        TempSKU: Record "Stockkeeping Unit" temporary;
        PlanningGetParameters: Codeunit "Planning-Get Parameters";
    begin
        TestLib.InitSetup();
        EnableProvider();
        TestLib.CreateItem(Item);
        TestLib.AddSales(Item."No.", 1, 3, 1, 10, 10);
        Item."Reordering Policy" := Item."Reordering Policy"::"Fixed Reorder Qty.";
        Item."Reorder Point" := 4;
        Item.Modify(false);

        PlanningGetParameters.AtSKU(TempSKU, Item."No.", '', '');

        Assert.AreEqual(4, TempSKU."Reorder Point", 'Stored values stand when the provider cannot calculate');
    end;

    [Test]
    procedure ReorderQty_OrderMultipleTarget_NotSupplied()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        TempSKU: Record "Stockkeeping Unit" temporary;
        Provider: Codeunit "GSO Planning Provider";
        PlanningGetParameters: Codeunit "Planning-Get Parameters";
        SS, ROP, RQ : Decimal;
    begin
        TestLib.InitSetup();
        EnableProvider();
        Setup.GetSetup();
        Setup."EOQ Write Target" := Setup."EOQ Write Target"::"Order Multiple";
        Setup.Modify(false);
        CreatePlannedItem(Item);

        Assert.IsTrue(Provider.TryGetPlanningValues(Item."No.", SS, ROP, RQ), 'Provider serves values');
        Assert.AreEqual(0, RQ, 'EOQ is supplied only when it targets Reorder Quantity');

        PlanningGetParameters.AtSKU(TempSKU, Item."No.", '', '');
        Assert.AreEqual(5, TempSKU."Reorder Quantity", 'The stored reorder quantity stands');
    end;

    [Test]
    procedure Miss_RememberedUntilCacheCleared()
    var
        Item: Record Item;
        Provider: Codeunit "GSO Planning Provider";
        SS, ROP, RQ : Decimal;
    begin
        TestLib.InitSetup();
        EnableProvider();
        TestLib.CreateItem(Item);
        TestLib.AddSales(Item."No.", 1, 3, 1, 10, 10);
        Assert.IsFalse(Provider.TryGetPlanningValues(Item."No.", SS, ROP, RQ), 'Too little history');

        TestLib.AddSales(Item."No.", 4, 30, 1, 10, 10);
        Assert.IsFalse(Provider.TryGetPlanningValues(Item."No.", SS, ROP, RQ), 'A miss is remembered for the cache lifetime');

        TestLib.ClearCaches();
        Assert.IsTrue(Provider.TryGetPlanningValues(Item."No.", SS, ROP, RQ), 'After ClearCache the new history counts');
    end;

    [Test]
    procedure SetupSaved_CachedValuesDropped()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        Provider: Codeunit "GSO Planning Provider";
        SS, ROP, RQ : Decimal;
    begin
        TestLib.InitSetup();
        EnableProvider();
        CreatePlannedItem(Item);
        Assert.IsTrue(Provider.TryGetPlanningValues(Item."No.", SS, ROP, RQ), 'Provider serves values');
        Assert.IsTrue(RQ > 0, 'EOQ supplied while it targets Reorder Quantity');

        Setup.GetSetup();
        Setup."EOQ Write Target" := Setup."EOQ Write Target"::"Order Multiple";
        Setup.Modify(false);

        Assert.IsTrue(Provider.TryGetPlanningValues(Item."No.", SS, ROP, RQ), 'Provider still serves values');
        Assert.AreEqual(0, RQ, 'The changed EOQ target is used at once, not the cached reorder quantity');
    end;

    [Test]
    procedure ItemModified_CachedValuesDropped()
    var
        Item: Record Item;
        Provider: Codeunit "GSO Planning Provider";
        SS, ROP, RQ : Decimal;
        SSBefore: Decimal;
    begin
        TestLib.InitSetup();
        EnableProvider();
        CreatePlannedItem(Item);
        Assert.IsTrue(Provider.TryGetPlanningValues(Item."No.", SSBefore, ROP, RQ), 'Provider serves values');

        Item.Get(Item."No.");
        Item.Validate("GSO Service Level %", 99);
        Item.Modify(true);

        Assert.IsTrue(Provider.TryGetPlanningValues(Item."No.", SS, ROP, RQ), 'Provider still serves values');
        Assert.IsTrue(SS > SSBefore, 'The item''s higher service level is used at once, not the cached safety stock');
    end;

    [Test]
    procedure ItemNoLongerExcluded_MissForgotten()
    var
        Item: Record Item;
        Provider: Codeunit "GSO Planning Provider";
        SS, ROP, RQ : Decimal;
    begin
        TestLib.InitSetup();
        EnableProvider();
        CreatePlannedItem(Item);
        Item."GSO Exclude From Planning" := true;
        Item.Modify(false);
        Assert.IsFalse(Provider.TryGetPlanningValues(Item."No.", SS, ROP, RQ), 'Excluded items are not supplied');

        Item.Get(Item."No.");
        Item."GSO Exclude From Planning" := false;
        Item.Modify(false);

        Assert.IsTrue(Provider.TryGetPlanningValues(Item."No.", SS, ROP, RQ), 'Including the item again takes effect at once');
    end;

    [Test]
    procedure MakeToOrderItem_FailsOpen()
    var
        Item: Record Item;
        Provider: Codeunit "GSO Planning Provider";
        SS, ROP, RQ : Decimal;
    begin
        TestLib.InitSetup();
        EnableProvider();
        CreatePlannedItem(Item);
        Item."Manufacturing Policy" := Item."Manufacturing Policy"::"Make-to-Order";
        Item.Modify(false);

        Assert.IsFalse(Provider.TryGetPlanningValues(Item."No.", SS, ROP, RQ), 'Make-to-order items are not supplied');
    end;

    [Test]
    procedure BlockedItem_FailsOpen()
    var
        Item: Record Item;
        Provider: Codeunit "GSO Planning Provider";
        SS, ROP, RQ : Decimal;
    begin
        TestLib.InitSetup();
        EnableProvider();
        CreatePlannedItem(Item);
        Item.Blocked := true;
        Item.Modify(false);

        Assert.IsFalse(Provider.TryGetPlanningValues(Item."No.", SS, ROP, RQ), 'Blocked items are not supplied');
    end;

    [Test]
    procedure UnknownItem_FailsOpen()
    var
        Provider: Codeunit "GSO Planning Provider";
        SS, ROP, RQ : Decimal;
    begin
        TestLib.InitSetup();
        EnableProvider();

        Assert.IsFalse(Provider.TryGetPlanningValues('GSO-NO-SUCH-ITEM', SS, ROP, RQ), 'Unknown items are not supplied');
    end;

    [Test]
    procedure Log_OneEntryPerFreshComputation()
    var
        Item: Record Item;
        LogEntry: Record "GSO Calculation Log";
        Provider: Codeunit "GSO Planning Provider";
        SS, ROP, RQ : Decimal;
    begin
        TestLib.InitSetup();
        EnableProvider();
        CreatePlannedItem(Item);

        Provider.TryGetPlanningValues(Item."No.", SS, ROP, RQ);
        Provider.TryGetPlanningValues(Item."No.", SS, ROP, RQ);

        LogEntry.SetRange("Item No.", Item."No.");
        LogEntry.SetRange("Calculation Type", LogEntry."Calculation Type"::"Dynamic Supply");
        Assert.AreEqual(1, LogEntry.Count(), 'Cached calls are not logged again');
        LogEntry.FindFirst();
        Assert.AreEqual(SS, LogEntry."Raw Result", 'Raw Result holds the supplied safety stock');
        Assert.AreEqual(ROP, LogEntry.Result, 'Result holds the supplied reorder point');
        Assert.IsFalse(LogEntry.Applied, 'Nothing is written to the item');
    end;

    [Test]
    procedure Log_HistoryOff_NoLog()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        Provider: Codeunit "GSO Planning Provider";
        SS, ROP, RQ : Decimal;
    begin
        TestLib.InitSetup();
        EnableProvider();
        Setup.GetSetup();
        Setup."Log History" := false;
        Setup.Modify(false);
        CreatePlannedItem(Item);

        Provider.TryGetPlanningValues(Item."No.", SS, ROP, RQ);

        Assert.AreEqual(0, TestLib.CountLog(Item."No."), 'Log History off must not log');
    end;

    [Test]
    procedure SuppliedValues_NeverWrittenToItem()
    var
        Item: Record Item;
        TempSKU: Record "Stockkeeping Unit" temporary;
        PlanningGetParameters: Codeunit "Planning-Get Parameters";
    begin
        TestLib.InitSetup();
        EnableProvider();
        CreatePlannedItem(Item);

        PlanningGetParameters.AtSKU(TempSKU, Item."No.", '', '');

        Item.Get(Item."No.");
        Assert.AreEqual(3, Item."Safety Stock Quantity", 'Item safety stock untouched');
        Assert.AreEqual(4, Item."Reorder Point", 'Item reorder point untouched');
        Assert.AreEqual(5, Item."Reorder Quantity", 'Item reorder quantity untouched');
    end;
}
