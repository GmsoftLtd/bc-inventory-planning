namespace GMSoft.InventoryPlanning.Test;

using GMSoft.InventoryPlanning;
using Microsoft.Inventory.Item;
using System.TestLibraries.Utilities;

/// <summary>
/// Policy advisor: every demand pattern, every recommendation, the
/// auto-update switch, configurable thresholds, logging and bulk runs.
/// A 30-day window holds the sales of days 1-29 back:
/// - daily, equal sizes: ADI 30/29, CV2 0 (Smooth)
/// - daily, sizes 1 and 20: ADI 30/29, CV2 about 0.87 (Erratic)
/// - every third day, equal sizes: ADI 30/9, CV2 0 (Intermittent)
/// - every third day, sizes 1 and 20: ADI 30/9, CV2 about 1 (Lumpy)
/// </summary>
codeunit 50206 "GSO Policy Advisor Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLib: Codeunit "GSO Test Library";

    local procedure Init()
    var
        Setup: Record "GSO Setup";
    begin
        TestLib.InitSetup();
        Setup.GetSetup();
        Setup."History Window (Days)" := 30;
        Setup.Modify(false);
    end;

    local procedure CreateSmoothItem(var Item: Record Item)
    begin
        TestLib.CreateItem(Item);
        TestLib.AddSales(Item."No.", 1, 29, 1, 10, 10);
    end;

    local procedure CreateIntermittentItem(var Item: Record Item)
    begin
        TestLib.CreateItem(Item);
        TestLib.AddSales(Item."No.", 1, 29, 3, 10, 10);
    end;

    local procedure SetAutoUpdate()
    var
        Setup: Record "GSO Setup";
    begin
        Setup.GetSetup();
        Setup."Auto-Update Policy" := true;
        Setup.Modify(false);
    end;

    local procedure SetShelfLife(var Item: Record Item)
    var
        ExpirationFormula: DateFormula;
    begin
        Evaluate(ExpirationFormula, '<30D>');
        Item."Expiration Calculation" := ExpirationFormula;
        Item.Modify(false);
    end;

    [Test]
    procedure Erratic_RecommendsFixedReorderQty()
    var
        Item: Record Item;
        PolicyAdvisor: Codeunit "GSO Policy Advisor";
        Recommendation: Enum "GSO Policy Recommendation";
        Pattern: Text[30];
        Note: Text[250];
    begin
        Init();
        TestLib.CreateItem(Item);
        TestLib.AddSales(Item."No.", 1, 29, 1, 1, 20);

        Recommendation := PolicyAdvisor.AdvisePreview(Item."No.", Pattern, Note);

        Assert.AreEqual('Erratic', Pattern, 'Frequent demand of varying size is Erratic');
        Assert.AreEqual(Recommendation::"Fixed Reorder Qty.", Recommendation, 'Frequent demand without a cap: Fixed Reorder Qty.');
    end;

    [Test]
    procedure Intermittent_RecommendsLotForLot()
    var
        Item: Record Item;
        PolicyAdvisor: Codeunit "GSO Policy Advisor";
        Recommendation: Enum "GSO Policy Recommendation";
        Pattern: Text[30];
        Note: Text[250];
    begin
        Init();
        CreateIntermittentItem(Item);

        Recommendation := PolicyAdvisor.AdvisePreview(Item."No.", Pattern, Note);

        Assert.AreEqual('Intermittent', Pattern, 'Infrequent demand of equal size is Intermittent');
        Assert.AreEqual(Recommendation::"Lot-for-Lot", Recommendation, 'Infrequent demand: Lot-for-Lot');
    end;

    [Test]
    procedure Lumpy_RecommendsLotForLot()
    var
        Item: Record Item;
        PolicyAdvisor: Codeunit "GSO Policy Advisor";
        Recommendation: Enum "GSO Policy Recommendation";
        Pattern: Text[30];
        Note: Text[250];
    begin
        Init();
        TestLib.CreateItem(Item);
        TestLib.AddSales(Item."No.", 1, 29, 3, 1, 20);

        Recommendation := PolicyAdvisor.AdvisePreview(Item."No.", Pattern, Note);

        Assert.AreEqual('Lumpy', Pattern, 'Infrequent demand of varying size is Lumpy');
        Assert.AreEqual(Recommendation::"Lot-for-Lot", Recommendation, 'Lumpy demand: Lot-for-Lot');
    end;

    [Test]
    procedure ShelfLife_RecommendsMaximumQty()
    var
        Item: Record Item;
        PolicyAdvisor: Codeunit "GSO Policy Advisor";
        Recommendation: Enum "GSO Policy Recommendation";
        Pattern: Text[30];
        Note: Text[250];
    begin
        Init();
        CreateSmoothItem(Item);
        SetShelfLife(Item);

        Recommendation := PolicyAdvisor.AdvisePreview(Item."No.", Pattern, Note);

        Assert.AreEqual(Recommendation::"Maximum Qty.", Recommendation, 'A shelf life caps stock: Maximum Qty.');
    end;

    [Test]
    procedure ShelfLife_SettingOff_RecommendsFixedReorderQty()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        PolicyAdvisor: Codeunit "GSO Policy Advisor";
        Recommendation: Enum "GSO Policy Recommendation";
        Pattern: Text[30];
        Note: Text[250];
    begin
        Init();
        Setup.GetSetup();
        Setup."Perishable Means Max Qty." := false;
        Setup.Modify(false);
        CreateSmoothItem(Item);
        SetShelfLife(Item);

        Recommendation := PolicyAdvisor.AdvisePreview(Item."No.", Pattern, Note);

        Assert.AreEqual(Recommendation::"Fixed Reorder Qty.", Recommendation, 'With the setting off a shelf life does not matter');
    end;

    [Test]
    procedure MaximumInventorySet_RecommendsMaximumQty()
    var
        Item: Record Item;
        PolicyAdvisor: Codeunit "GSO Policy Advisor";
        Recommendation: Enum "GSO Policy Recommendation";
        Pattern: Text[30];
        Note: Text[250];
    begin
        Init();
        CreateSmoothItem(Item);
        Item."Maximum Inventory" := 500;
        Item.Modify(false);

        Recommendation := PolicyAdvisor.AdvisePreview(Item."No.", Pattern, Note);

        Assert.AreEqual(Recommendation::"Maximum Qty.", Recommendation, 'An existing ceiling: Maximum Qty.');
    end;

    [Test]
    procedure MakeToOrder_RecommendsOrder()
    var
        Item: Record Item;
        PolicyAdvisor: Codeunit "GSO Policy Advisor";
        Recommendation: Enum "GSO Policy Recommendation";
        Pattern: Text[30];
        Note: Text[250];
    begin
        Init();
        CreateSmoothItem(Item);
        Item."Manufacturing Policy" := Item."Manufacturing Policy"::"Make-to-Order";
        Item.Modify(false);

        Recommendation := PolicyAdvisor.AdvisePreview(Item."No.", Pattern, Note);

        Assert.AreEqual(Recommendation::Order, Recommendation, 'Make-to-order: Order');
        Assert.IsTrue(StrPos(Note, 'Make-to-order') > 0, 'The note explains why');
    end;

    [Test]
    procedure InsufficientHistory_UnknownPattern()
    var
        Item: Record Item;
        PolicyAdvisor: Codeunit "GSO Policy Advisor";
        Recommendation: Enum "GSO Policy Recommendation";
        Pattern: Text[30];
        Note: Text[250];
    begin
        Init();
        TestLib.CreateItem(Item);
        TestLib.AddSales(Item."No.", 1, 3, 1, 10, 10);

        Recommendation := PolicyAdvisor.AdvisePreview(Item."No.", Pattern, Note);

        Assert.AreEqual(Recommendation::"Insufficient Data", Recommendation, 'Too little history');
        Assert.AreEqual('Unknown', Pattern, 'Pattern unknown');
    end;

    [Test]
    procedure UnknownItem_InsufficientData()
    var
        PolicyAdvisor: Codeunit "GSO Policy Advisor";
        Recommendation: Enum "GSO Policy Recommendation";
        Pattern: Text[30];
        Note: Text[250];
    begin
        Init();

        Recommendation := PolicyAdvisor.AdviseForItem('GSO-NO-SUCH-ITEM', true, Pattern, Note);

        Assert.AreEqual(Recommendation::"Insufficient Data", Recommendation, 'An unknown item gets no advice');
        Assert.AreEqual('Item not found.', Note, 'And says so');
    end;

    [Test]
    procedure IneligibleItems_InsufficientData()
    var
        Blocked, Excluded, Service : Record Item;
        PolicyAdvisor: Codeunit "GSO Policy Advisor";
        Pattern: Text[30];
        Note: Text[250];
    begin
        Init();
        CreateSmoothItem(Blocked);
        Blocked.Blocked := true;
        Blocked.Modify(false);
        CreateSmoothItem(Excluded);
        Excluded."GSO Exclude From Planning" := true;
        Excluded.Modify(false);
        CreateSmoothItem(Service);
        Service.Type := Service.Type::Service;
        Service.Modify(false);

        Assert.AreEqual(Enum::"GSO Policy Recommendation"::"Insufficient Data", PolicyAdvisor.AdvisePreview(Blocked."No.", Pattern, Note), 'Blocked');
        Assert.AreEqual('Item is blocked.', Note, 'Blocked note');
        Assert.AreEqual(Enum::"GSO Policy Recommendation"::"Insufficient Data", PolicyAdvisor.AdvisePreview(Excluded."No.", Pattern, Note), 'Excluded');
        Assert.AreEqual('Item is excluded from inventory planning.', Note, 'Excluded note');
        Assert.AreEqual(Enum::"GSO Policy Recommendation"::"Insufficient Data", PolicyAdvisor.AdvisePreview(Service."No.", Pattern, Note), 'Service item');
        Assert.IsTrue(StrPos(Note, 'Not an inventory item') > 0, 'Non-inventory note');
    end;

    [Test]
    procedure AutoUpdateOff_PolicyNotWritten()
    var
        Item: Record Item;
        PolicyAdvisor: Codeunit "GSO Policy Advisor";
        Pattern: Text[30];
        Note: Text[250];
    begin
        Init();
        CreateIntermittentItem(Item);

        PolicyAdvisor.AdviseForItem(Item."No.", true, Pattern, Note);

        Item.Get(Item."No.");
        Assert.AreEqual(Item."Reordering Policy"::" ", Item."Reordering Policy", 'Without auto-update only advice is given');
    end;

    [Test]
    procedure AutoUpdateOn_WritesLotForLot()
    var
        Item: Record Item;
        PolicyAdvisor: Codeunit "GSO Policy Advisor";
        Pattern: Text[30];
        Note: Text[250];
    begin
        Init();
        SetAutoUpdate();
        CreateIntermittentItem(Item);

        PolicyAdvisor.AdviseForItem(Item."No.", true, Pattern, Note);

        Item.Get(Item."No.");
        Assert.AreEqual(Item."Reordering Policy"::"Lot-for-Lot", Item."Reordering Policy", 'Lot-for-Lot written');
    end;

    [Test]
    procedure AutoUpdateOn_WritesMaximumQty()
    var
        Item: Record Item;
        PolicyAdvisor: Codeunit "GSO Policy Advisor";
        Pattern: Text[30];
        Note: Text[250];
    begin
        Init();
        SetAutoUpdate();
        CreateSmoothItem(Item);
        SetShelfLife(Item);

        PolicyAdvisor.AdviseForItem(Item."No.", true, Pattern, Note);

        Item.Get(Item."No.");
        Assert.AreEqual(Item."Reordering Policy"::"Maximum Qty.", Item."Reordering Policy", 'Maximum Qty. written');
    end;

    [Test]
    procedure AutoUpdateOn_WritesFixedReorderQty()
    var
        Item: Record Item;
        PolicyAdvisor: Codeunit "GSO Policy Advisor";
        Pattern: Text[30];
        Note: Text[250];
    begin
        Init();
        SetAutoUpdate();
        CreateSmoothItem(Item);

        PolicyAdvisor.AdviseForItem(Item."No.", true, Pattern, Note);

        Item.Get(Item."No.");
        Assert.AreEqual(Item."Reordering Policy"::"Fixed Reorder Qty.", Item."Reordering Policy", 'Fixed Reorder Qty. written');
    end;

    [Test]
    procedure AutoUpdateOn_NeverFlipsToOrder()
    var
        Item: Record Item;
        PolicyAdvisor: Codeunit "GSO Policy Advisor";
        Pattern: Text[30];
        Note: Text[250];
    begin
        Init();
        SetAutoUpdate();
        CreateSmoothItem(Item);
        Item."Manufacturing Policy" := Item."Manufacturing Policy"::"Make-to-Order";
        Item."Reordering Policy" := Item."Reordering Policy"::"Fixed Reorder Qty.";
        Item.Modify(false);

        PolicyAdvisor.AdviseForItem(Item."No.", true, Pattern, Note);

        Item.Get(Item."No.");
        Assert.AreEqual(Item."Reordering Policy"::"Fixed Reorder Qty.", Item."Reordering Policy", 'The advisor never writes Order');
    end;

    [Test]
    procedure AutoUpdateOn_ApplyFalse_NotWritten()
    var
        Item: Record Item;
        PolicyAdvisor: Codeunit "GSO Policy Advisor";
        Pattern: Text[30];
        Note: Text[250];
    begin
        Init();
        SetAutoUpdate();
        CreateIntermittentItem(Item);

        PolicyAdvisor.AdviseForItem(Item."No.", false, Pattern, Note);

        Item.Get(Item."No.");
        Assert.AreEqual(Item."Reordering Policy"::" ", Item."Reordering Policy", 'Apply = false must not write');
    end;

    [Test]
    procedure Thresholds_AreConfigurable()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        PolicyAdvisor: Codeunit "GSO Policy Advisor";
        Pattern: Text[30];
        Note: Text[250];
    begin
        Init();
        Setup.GetSetup();
        Setup."Lumpy ADI Threshold" := 4;
        Setup."Erratic CV2 Threshold" := 2;
        Setup.Modify(false);
        TestLib.CreateItem(Item);
        TestLib.AddSales(Item."No.", 1, 29, 3, 1, 20); // Lumpy under default thresholds

        PolicyAdvisor.AdvisePreview(Item."No.", Pattern, Note);

        Assert.AreEqual('Smooth', Pattern, 'ADI 3.3 < 4 and CV2 about 1 < 2 classify as Smooth');
    end;

    [Test]
    procedure Preview_NoWriteNoLog()
    var
        Item: Record Item;
        PolicyAdvisor: Codeunit "GSO Policy Advisor";
        Pattern: Text[30];
        Note: Text[250];
    begin
        Init();
        SetAutoUpdate();
        CreateIntermittentItem(Item);

        PolicyAdvisor.AdvisePreview(Item."No.", Pattern, Note);

        Item.Get(Item."No.");
        Assert.AreEqual(Item."Reordering Policy"::" ", Item."Reordering Policy", 'Preview must not write, even with auto-update');
        Assert.AreEqual(0, TestLib.CountLog(Item."No."), 'Preview must not log');
    end;

    [Test]
    procedure Log_RecordsAdvice()
    var
        Item: Record Item;
        LogEntry: Record "GSO Calculation Log";
        PolicyAdvisor: Codeunit "GSO Policy Advisor";
        Pattern: Text[30];
        Note: Text[250];
    begin
        Init();
        SetAutoUpdate();
        CreateIntermittentItem(Item);

        PolicyAdvisor.AdviseForItem(Item."No.", true, Pattern, Note);

        Assert.IsTrue(TestLib.FindLastLog(Item."No.", LogEntry."Calculation Type"::"Policy Advice", LogEntry), 'A log entry');
        Assert.AreEqual(9, LogEntry."Demand Observations", 'Nine demand days');
        Assert.AreNearlyEqual(30 / 9, LogEntry."Avg Demand Interval (ADI)", 0.0001, 'ADI');
        Assert.AreNearlyEqual(0, LogEntry."Demand CV Squared", 0.0001, 'CV2');
        Assert.AreEqual('Intermittent', LogEntry."Demand Pattern", 'Pattern');
        Assert.AreEqual(LogEntry."Recommended Policy"::"Lot-for-Lot", LogEntry."Recommended Policy", 'Recommendation');
        Assert.IsTrue(LogEntry.Applied, 'Applied');
        Assert.AreEqual(Note, LogEntry.Note, 'The logged note is the returned note');
    end;

    [Test]
    procedure Bulk_AdvisesFilteredItems()
    var
        Item1, Item2 : Record Item;
        ItemFilter: Record Item;
        PolicyAdvisor: Codeunit "GSO Policy Advisor";
    begin
        Init();
        SetAutoUpdate();
        CreateIntermittentItem(Item1);
        CreateSmoothItem(Item2);
        ItemFilter.SetFilter("No.", '%1|%2', Item1."No.", Item2."No.");

        Assert.AreEqual(2, PolicyAdvisor.AdviseBulk(ItemFilter, true), 'Two items');

        Item1.Get(Item1."No.");
        Item2.Get(Item2."No.");
        Assert.AreEqual(Item1."Reordering Policy"::"Lot-for-Lot", Item1."Reordering Policy", 'First item advised and written');
        Assert.AreEqual(Item2."Reordering Policy"::"Fixed Reorder Qty.", Item2."Reordering Policy", 'Second item advised and written');
    end;
}
