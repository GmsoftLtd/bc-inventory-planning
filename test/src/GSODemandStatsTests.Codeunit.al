namespace GMSoft.InventoryPlanning.Test;

using GMSoft.InventoryPlanning;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using System.TestLibraries.Utilities;

/// <summary>
/// Demand statistics engine: netting, demand definition, the statistics
/// themselves, caching, lead time resolution, trend and advisory text.
/// Expected values are worked out from the formulas in the comments.
/// </summary>
codeunit 50203 "GSO Demand Stats Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLib: Codeunit "GSO Test Library";
        DemandStats: Codeunit "GSO Demand Statistics";

    [Test]
    procedure SameDayReturn_NetsAgainstSales()
    var
        Item: Record Item;
        ItemLedgerEntry: Record "Item Ledger Entry";
        AvgDemand, StdDev, ADI, CV2 : Decimal;
        Observations: Integer;
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddSale(Item."No.", 1, 10);
        TestLib.AddLedgerEntry(Item."No.", 1, ItemLedgerEntry."Entry Type"::Sale, 4); // return

        DemandStats.ComputeDemandStats(Item."No.", 90, AvgDemand, StdDev, Observations, ADI, CV2);

        Assert.AreEqual(1, Observations, 'One demand day');
        Assert.AreNearlyEqual(6 / 90, AvgDemand, 0.000001, 'Net demand 10 - 4 = 6 over 90 calendar days');
    end;

    [Test]
    procedure ReturnsExceedingSales_CountAsZeroDemandDay()
    var
        Item: Record Item;
        ItemLedgerEntry: Record "Item Ledger Entry";
        AvgDemand, StdDev, ADI, CV2 : Decimal;
        Observations: Integer;
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddSale(Item."No.", 1, 5);
        TestLib.AddLedgerEntry(Item."No.", 1, ItemLedgerEntry."Entry Type"::Sale, 8);
        TestLib.AddSale(Item."No.", 2, 10);

        DemandStats.ComputeDemandStats(Item."No.", 90, AvgDemand, StdDev, Observations, ADI, CV2);

        Assert.AreEqual(1, Observations, 'A day whose returns exceed its sales is not a demand day');
        Assert.AreNearlyEqual(10 / 90, AvgDemand, 0.000001, 'Negative net demand must not reduce the average');
    end;

    [Test]
    procedure Consumption_IgnoredByDefault()
    var
        Item: Record Item;
        ItemLedgerEntry: Record "Item Ledger Entry";
        AvgDemand, StdDev, ADI, CV2 : Decimal;
        Observations: Integer;
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddLedgerEntry(Item."No.", 1, ItemLedgerEntry."Entry Type"::Consumption, -10);
        TestLib.AddLedgerEntry(Item."No.", 2, ItemLedgerEntry."Entry Type"::"Assembly Consumption", -5);

        DemandStats.ComputeDemandStats(Item."No.", 90, AvgDemand, StdDev, Observations, ADI, CV2);

        Assert.AreEqual(0, Observations, 'Consumption is not demand unless setup says so');
    end;

    [Test]
    procedure Consumption_CountedWhenEnabled()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        ItemLedgerEntry: Record "Item Ledger Entry";
        AvgDemand, StdDev, ADI, CV2 : Decimal;
        Observations: Integer;
    begin
        TestLib.InitSetup();
        Setup.GetSetup();
        Setup."Include Consumption Demand" := true;
        Setup.Modify(false);
        TestLib.CreateItem(Item);
        TestLib.AddLedgerEntry(Item."No.", 1, ItemLedgerEntry."Entry Type"::Consumption, -10);
        TestLib.AddLedgerEntry(Item."No.", 2, ItemLedgerEntry."Entry Type"::"Assembly Consumption", -5);
        TestLib.AddSale(Item."No.", 3, 3);

        DemandStats.ComputeDemandStats(Item."No.", 90, AvgDemand, StdDev, Observations, ADI, CV2);

        Assert.AreEqual(3, Observations, 'Consumption, assembly consumption and sales are all demand');
        Assert.AreNearlyEqual(18 / 90, AvgDemand, 0.000001, '10 + 5 + 3 over 90 days');
    end;

    [Test]
    procedure OtherEntryTypes_NeverDemand()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        ItemLedgerEntry: Record "Item Ledger Entry";
        AvgDemand, StdDev, ADI, CV2 : Decimal;
        Observations: Integer;
    begin
        TestLib.InitSetup();
        Setup.GetSetup();
        Setup."Include Consumption Demand" := true;
        Setup.Modify(false);
        TestLib.CreateItem(Item);
        TestLib.AddLedgerEntry(Item."No.", 1, ItemLedgerEntry."Entry Type"::"Negative Adjmt.", -10);
        TestLib.AddLedgerEntry(Item."No.", 2, ItemLedgerEntry."Entry Type"::Transfer, -10);
        TestLib.AddLedgerEntry(Item."No.", 3, ItemLedgerEntry."Entry Type"::Purchase, 10);

        DemandStats.ComputeDemandStats(Item."No.", 90, AvgDemand, StdDev, Observations, ADI, CV2);

        Assert.AreEqual(0, Observations, 'Adjustments, transfers and purchases are not demand');
    end;

    [Test]
    procedure CV2_FromDemandSizes()
    var
        Item: Record Item;
        AvgDemand, StdDev, ADI, CV2 : Decimal;
        Observations: Integer;
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddSale(Item."No.", 1, 5);
        TestLib.AddSale(Item."No.", 2, 15);

        DemandStats.ComputeDemandStats(Item."No.", 90, AvgDemand, StdDev, Observations, ADI, CV2);

        // Sizes 5 and 15: mean 10, population variance 25, CV2 = 25 / 10^2.
        Assert.AreNearlyEqual(0.25, CV2, 0.000001, 'CV2 is the squared variation of demand sizes');
    end;

    [Test]
    procedure StdDev_SampleOverAllCalendarDays()
    var
        Item: Record Item;
        AvgDemand, StdDev, ADI, CV2 : Decimal;
        Observations: Integer;
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddSale(Item."No.", 1, 90);

        DemandStats.ComputeDemandStats(Item."No.", 90, AvgDemand, StdDev, Observations, ADI, CV2);

        // Mean 90/90 = 1; variance (8100 - 90 * 1^2) / 89 = 90.
        Assert.AreNearlyEqual(1, AvgDemand, 0.000001, 'Mean over all 90 calendar days');
        Assert.AreNearlyEqual(Power(90, 0.5), StdDev, 0.0001, 'Sample standard deviation with zero days counted');
    end;

    [Test]
    procedure ADI_CalendarDaysPerDemandDay()
    var
        Item: Record Item;
        AvgDemand, StdDev, ADI, CV2 : Decimal;
        Observations: Integer;
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddSales(Item."No.", 1, 30, 3, 10, 10); // days 3, 6 ... 30

        DemandStats.ComputeDemandStats(Item."No.", 90, AvgDemand, StdDev, Observations, ADI, CV2);

        Assert.AreEqual(10, Observations, 'Ten demand days');
        Assert.AreNearlyEqual(9, ADI, 0.000001, '90 calendar days / 10 demand days');
        Assert.AreNearlyEqual(0, CV2, 0.000001, 'Equal sizes have no size variation');
    end;

    [Test]
    procedure NoHistory_AllZero()
    var
        Item: Record Item;
        AvgDemand, StdDev, ADI, CV2 : Decimal;
        Observations: Integer;
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);

        DemandStats.ComputeDemandStats(Item."No.", 90, AvgDemand, StdDev, Observations, ADI, CV2);

        Assert.AreEqual(0, Observations, 'No observations');
        Assert.AreEqual(0, AvgDemand, 'No average');
        Assert.AreEqual(0, StdDev, 'No deviation');
        Assert.AreEqual(0, ADI, 'No ADI');
        Assert.AreEqual(0, CV2, 'No CV2');
    end;

    [Test]
    procedure Cache_ServesUntilCleared()
    var
        Item: Record Item;
        AvgDemand, StdDev, ADI, CV2 : Decimal;
        Observations: Integer;
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item);
        DemandStats.ComputeDemandStats(Item."No.", 90, AvgDemand, StdDev, Observations, ADI, CV2);
        TestLib.AddSale(Item."No.", 40, 10);

        DemandStats.ComputeDemandStats(Item."No.", 90, AvgDemand, StdDev, Observations, ADI, CV2);
        Assert.AreEqual(30, Observations, 'Within the TTL the cached statistics are served');

        DemandStats.ClearCache();
        DemandStats.ComputeDemandStats(Item."No.", 90, AvgDemand, StdDev, Observations, ADI, CV2);
        Assert.AreEqual(31, Observations, 'ClearCache makes the next call see new demand');
    end;

    [Test]
    procedure Cache_WindowChangeRecomputes()
    var
        Item: Record Item;
        AvgDemand, StdDev, ADI, CV2 : Decimal;
        Observations: Integer;
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddSale(Item."No.", 1, 10);
        TestLib.AddSale(Item."No.", 50, 10);

        DemandStats.ComputeDemandStats(Item."No.", 90, AvgDemand, StdDev, Observations, ADI, CV2);
        Assert.AreEqual(2, Observations, 'Both sales are inside 90 days');

        DemandStats.ComputeDemandStats(Item."No.", 30, AvgDemand, StdDev, Observations, ADI, CV2);
        Assert.AreEqual(1, Observations, 'A different window must not be served from the cache');
    end;

    [Test]
    procedure Cache_DemandDefinitionChangeRecomputes()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        ItemLedgerEntry: Record "Item Ledger Entry";
        AvgDemand, StdDev, ADI, CV2 : Decimal;
        Observations: Integer;
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddLedgerEntry(Item."No.", 1, ItemLedgerEntry."Entry Type"::Consumption, -10);
        DemandStats.ComputeDemandStats(Item."No.", 90, AvgDemand, StdDev, Observations, ADI, CV2);
        Assert.AreEqual(0, Observations, 'Consumption excluded');

        Setup.GetSetup();
        Setup."Include Consumption Demand" := true;
        Setup.Modify(false);

        DemandStats.ComputeDemandStats(Item."No.", 90, AvgDemand, StdDev, Observations, ADI, CV2);
        Assert.AreEqual(1, Observations, 'Changing the demand definition must invalidate the cache');
    end;

    [Test]
    procedure RecentWindowDays_QuarterBoundedBy30AndWindow()
    begin
        Assert.AreEqual(30, DemandStats.RecentWindowDays(90), 'A quarter of 90 is below the 30-day floor');
        Assert.AreEqual(30, DemandStats.RecentWindowDays(120), 'A quarter of 120 is exactly 30');
        Assert.AreEqual(91, DemandStats.RecentWindowDays(365), 'A quarter of 365');
        Assert.AreEqual(20, DemandStats.RecentWindowDays(20), 'Never longer than the window itself');
    end;

    [Test]
    procedure DaysFromDateFormula_EvaluatesFromWorkDate()
    var
        DF: DateFormula;
    begin
        Assert.AreEqual(0, DemandStats.DaysFromDateFormula(DF), 'A blank formula is 0 days');
        Evaluate(DF, '<7D>');
        Assert.AreEqual(7, DemandStats.DaysFromDateFormula(DF), '<7D> is 7 days');
        Evaluate(DF, '<2W>');
        Assert.AreEqual(14, DemandStats.DaysFromDateFormula(DF), '<2W> is 14 days');
    end;

    [Test]
    procedure IsMakeToOrder_PolicyOrManufacturingPolicy()
    var
        Item: Record Item;
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        Assert.IsFalse(DemandStats.IsMakeToOrder(Item), 'A plain item is make-to-stock');

        Item."Manufacturing Policy" := Item."Manufacturing Policy"::"Make-to-Order";
        Assert.IsTrue(DemandStats.IsMakeToOrder(Item), 'Make-to-Order manufacturing policy');

        Item."Manufacturing Policy" := Item."Manufacturing Policy"::"Make-to-Stock";
        Item."Reordering Policy" := Item."Reordering Policy"::Order;
        Assert.IsTrue(DemandStats.IsMakeToOrder(Item), 'Order reordering policy');
    end;

    [Test]
    procedure LeadTime_FromPurchaseReceipts()
    var
        Item: Record Item;
        LeadTimeDays, LeadTimeStdDev : Decimal;
        Source: Text[50];
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddReceipt(Item."No.", 20, 10); // 10 days
        TestLib.AddReceipt(Item."No.", 30, 16); // 14 days

        DemandStats.ComputeLeadTime(Item, 7, LeadTimeDays, LeadTimeStdDev, Source);

        Assert.AreNearlyEqual(12, LeadTimeDays, 0.000001, 'Mean of 10 and 14 days');
        Assert.AreNearlyEqual(Power(8, 0.5), LeadTimeStdDev, 0.0001, 'Sample deviation of 10 and 14 is sqrt(8)');
        Assert.AreEqual('Purchase receipt history', Source, 'Source must name the receipts');
    end;

    [Test]
    procedure LeadTime_ReceiptsAfterWorkDateIgnored()
    var
        Item: Record Item;
        LeadTimeDays, LeadTimeStdDev : Decimal;
        Source: Text[50];
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddReceipt(Item."No.", 15, 5);   // 10 days
        TestLib.AddReceipt(Item."No.", 5, -25);  // 30 days, received after the work date

        DemandStats.ComputeLeadTime(Item, 7, LeadTimeDays, LeadTimeStdDev, Source);

        Assert.AreNearlyEqual(10, LeadTimeDays, 0.000001, 'A receipt after the work date must not count');
        Assert.AreEqual(0, LeadTimeStdDev, 'Only the one past receipt is a sample');
    end;

    [Test]
    procedure LeadTime_WorkDateMovedBack_CacheNotReused()
    var
        Item: Record Item;
        LeadTimeDays, LeadTimeStdDev : Decimal;
        Source: Text[50];
        OriginalWorkDate: Date;
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddReceipt(Item."No.", 15, 5); // 10 days, received 5 days ago
        TestLib.SetLeadTimeFormula(Item, '<5D>');
        DemandStats.ComputeLeadTime(Item, 7, LeadTimeDays, LeadTimeStdDev, Source);
        Assert.AreNearlyEqual(10, LeadTimeDays, 0.000001, 'The receipt counts at the original work date');

        OriginalWorkDate := WorkDate();
        WorkDate(OriginalWorkDate - 10);
        DemandStats.ComputeLeadTime(Item, 7, LeadTimeDays, LeadTimeStdDev, Source);
        WorkDate(OriginalWorkDate);

        Assert.AreEqual(5, LeadTimeDays, 'Ten days earlier the receipt is in the future: the cached 10 days must not be reused');
        Assert.AreEqual('Item Lead Time Calculation', Source, 'Falls through to the item formula');
    end;

    [Test]
    procedure LeadTime_SingleReceipt_NoSpread()
    var
        Item: Record Item;
        LeadTimeDays, LeadTimeStdDev : Decimal;
        Source: Text[50];
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddReceipt(Item."No.", 15, 5);

        DemandStats.ComputeLeadTime(Item, 7, LeadTimeDays, LeadTimeStdDev, Source);

        Assert.AreNearlyEqual(10, LeadTimeDays, 0.000001, 'One receipt of 10 days');
        Assert.AreEqual(0, LeadTimeStdDev, 'One sample has no deviation');
    end;

    [Test]
    procedure LeadTime_UnusableReceiptsIgnored()
    var
        Item: Record Item;
        LeadTimeDays, LeadTimeStdDev : Decimal;
        Source: Text[50];
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddReceipt(Item."No.", 0, 5);      // no order date
        TestLib.AddReceipt(Item."No.", 5, 10);     // received before ordered
        TestLib.AddReceipt(Item."No.", 800, 790);  // older than two years
        TestLib.SetLeadTimeFormula(Item, '<5D>');

        DemandStats.ComputeLeadTime(Item, 7, LeadTimeDays, LeadTimeStdDev, Source);

        Assert.AreEqual(5, LeadTimeDays, 'Unusable receipts fall through to the item formula');
        Assert.AreEqual('Item Lead Time Calculation', Source, 'Source must name the item formula');
    end;

    [Test]
    procedure LeadTime_ReceiptsBeatItemFormula()
    var
        Item: Record Item;
        LeadTimeDays, LeadTimeStdDev : Decimal;
        Source: Text[50];
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddReceipt(Item."No.", 15, 5);
        TestLib.SetLeadTimeFormula(Item, '<5D>');

        DemandStats.ComputeLeadTime(Item, 7, LeadTimeDays, LeadTimeStdDev, Source);

        Assert.AreNearlyEqual(10, LeadTimeDays, 0.000001, 'Receipt history comes first for purchased items');
    end;

    [Test]
    procedure LeadTime_ProducedItem_UsesFormula()
    var
        Item: Record Item;
        LeadTimeDays, LeadTimeStdDev : Decimal;
        Source: Text[50];
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddReceipt(Item."No.", 15, 5); // ignored for produced items
        TestLib.SetLeadTimeFormula(Item, '<9D>');
        Item."Replenishment System" := Item."Replenishment System"::"Prod. Order";
        Item.Modify(false);

        DemandStats.ComputeLeadTime(Item, 7, LeadTimeDays, LeadTimeStdDev, Source);

        Assert.AreEqual(9, LeadTimeDays, 'Produced items use the Lead Time Calculation');
        Assert.AreEqual('Item Lead Time Calculation (manufacturing)', Source, 'Source must say manufacturing');
    end;

    [Test]
    procedure LeadTime_AssembledItem_UsesFormula()
    var
        Item: Record Item;
        LeadTimeDays, LeadTimeStdDev : Decimal;
        Source: Text[50];
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.SetLeadTimeFormula(Item, '<4D>');
        Item."Replenishment System" := Item."Replenishment System"::Assembly;
        Item.Modify(false);

        DemandStats.ComputeLeadTime(Item, 7, LeadTimeDays, LeadTimeStdDev, Source);

        Assert.AreEqual(4, LeadTimeDays, 'Assembled items use the Lead Time Calculation');
        Assert.AreEqual('Item Lead Time Calculation (assembly)', Source, 'Source must say assembly');
    end;

    [Test]
    procedure LeadTime_NothingKnown_SetupFallback()
    var
        Item: Record Item;
        LeadTimeDays, LeadTimeStdDev : Decimal;
        Source: Text[50];
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);

        DemandStats.ComputeLeadTime(Item, 7, LeadTimeDays, LeadTimeStdDev, Source);

        Assert.AreEqual(7, LeadTimeDays, 'Fallback days');
        Assert.AreEqual(0, LeadTimeStdDev, 'The fallback has no deviation');
        Assert.AreEqual('Setup fallback', Source, 'Source must say fallback');
    end;

    [Test]
    procedure TrendPct_RecentOnlyDemand_Is200()
    var
        Item: Record Item;
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddSales(Item."No.", 1, 20, 1, 10, 10);

        // Recent window 30 days: 200/30 a day against 200/90 overall = +200%.
        Assert.AreNearlyEqual(200, DemandStats.ComputeTrendPct(Item."No.", 90), 0.0001, 'Recent average is three times the full-window average');
    end;

    [Test]
    procedure TrendPct_NoHistory_Zero()
    var
        Item: Record Item;
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);

        Assert.AreEqual(0, DemandStats.ComputeTrendPct(Item."No.", 90), 'No history means no trend');
    end;

    [Test]
    procedure Advisory_UpwardTrend_Warns()
    var
        Item: Record Item;
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddSales(Item."No.", 1, 20, 1, 10, 10);

        Assert.IsTrue(StrPos(DemandStats.BuildAdvisoryText(Item."No.", 90, 30), 'above') > 0, 'An upward trend beyond the threshold must be reported');
    end;

    [Test]
    procedure Advisory_DownwardTrend_Warns()
    var
        Item: Record Item;
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddSales(Item."No.", 45, 64, 1, 10, 10);

        Assert.IsTrue(StrPos(DemandStats.BuildAdvisoryText(Item."No.", 90, 30), 'below') > 0, 'A downward trend beyond the threshold must be reported');
    end;

    [Test]
    procedure Advisory_SteadyDemand_Silent()
    var
        Item: Record Item;
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddSales(Item."No.", 0, 89, 1, 10, 10); // every day of the window

        Assert.AreEqual('', DemandStats.BuildAdvisoryText(Item."No.", 90, 30), 'Steady demand and no SKUs give no advisory');
    end;

    [Test]
    procedure Advisory_ThresholdZero_DisablesTrend()
    var
        Item: Record Item;
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddSales(Item."No.", 1, 20, 1, 10, 10);

        Assert.AreEqual('', DemandStats.BuildAdvisoryText(Item."No.", 90, 0), 'Threshold 0 switches the trend warning off');
    end;

    [Test]
    procedure Advisory_StockkeepingUnits_Noted()
    var
        Item: Record Item;
        StockkeepingUnit: Record "Stockkeeping Unit";
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        StockkeepingUnit.Init();
        StockkeepingUnit."Location Code" := 'GSOTEST';
        StockkeepingUnit."Item No." := Item."No.";
        StockkeepingUnit.Insert(false);

        Assert.AreEqual(1, DemandStats.GetSKUCount(Item."No."), 'One SKU');
        Assert.IsTrue(StrPos(DemandStats.BuildAdvisoryText(Item."No.", 90, 0), 'stockkeeping unit') > 0, 'SKUs make item-card values inert and must be noted');
    end;
}
