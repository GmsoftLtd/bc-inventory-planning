namespace GMSoft.InventoryPlanning.Test;

using GMSoft.InventoryPlanning;
using Microsoft.Inventory.Item;
using System.TestLibraries.Utilities;

/// <summary>
/// Run All, bulk runs, worksheet proposals and Apply Selected.
/// The smooth item sells 9 and 11 units on alternate days for the whole
/// 90-day window: average exactly 10 a day, so demand during the 7-day
/// fallback lead time is exactly 70 and the advisor classifies it Smooth.
/// </summary>
codeunit 50207 "GSO Run All Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLib: Codeunit "GSO Test Library";

    local procedure CreateSmoothItem(var Item: Record Item)
    begin
        TestLib.CreateItem(Item);
        TestLib.AddSales(Item."No.", 0, 89, 1, 9, 11);
    end;

    local procedure SetMaximumQtyPolicy(var Item: Record Item; MaximumInventory: Decimal)
    begin
        Item."Reordering Policy" := Item."Reordering Policy"::"Maximum Qty.";
        Item."Maximum Inventory" := MaximumInventory;
        Item.Modify(false);
    end;

    local procedure CountMaxInventoryLogs(ItemNo: Code[20]): Integer
    var
        LogEntry: Record "GSO Calculation Log";
    begin
        LogEntry.SetRange("Item No.", ItemNo);
        LogEntry.SetRange("Calculation Type", LogEntry."Calculation Type"::"Maximum Inventory");
        exit(LogEntry.Count());
    end;

    [Test]
    procedure RunForItem_WritesConsistentChain()
    var
        Item: Record Item;
        RunAll: Codeunit "GSO Run All";
    begin
        TestLib.InitSetup();
        CreateSmoothItem(Item);

        RunAll.RunForItem(Item."No.", true);

        Item.Get(Item."No.");
        Assert.IsTrue(Item."Safety Stock Quantity" > 0, 'Safety stock written');
        Assert.AreEqual(70 + Item."Safety Stock Quantity", Item."Reorder Point", 'ROP = demand during lead time + the safety stock written in the same run');
        Assert.IsTrue(Item."Reorder Quantity" > 0, 'EOQ written');
        Assert.AreEqual(Item."Reordering Policy"::"Fixed Reorder Qty.", Item."Reordering Policy", 'Smooth advice allows the Fixed Reorder Qty. default');
        Assert.AreEqual(0, Item."Maximum Inventory", 'No Maximum Inventory for Fixed Reorder Qty.');
    end;

    [Test]
    procedure RunForItem_LotForLotAdvice_BlocksPolicyDefault()
    var
        Item: Record Item;
        RunAll: Codeunit "GSO Run All";
    begin
        TestLib.InitSetup();
        TestLib.CreateItemWithDailySales(Item); // ADI 3: Intermittent, Lot-for-Lot advice

        RunAll.RunForItem(Item."No.", true);

        Item.Get(Item."No.");
        Assert.AreEqual(Item."Reordering Policy"::" ", Item."Reordering Policy", 'ROP/EOQ must not stamp a policy the advisor contradicts');
        Assert.IsTrue(Item."Reorder Point" > 0, 'The reorder point is still written');
    end;

    [Test]
    procedure RunForItem_AutoUpdate_WritesAdvisedPolicy()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        RunAll: Codeunit "GSO Run All";
    begin
        TestLib.InitSetup();
        Setup.GetSetup();
        Setup."Auto-Update Policy" := true;
        Setup.Modify(false);
        TestLib.CreateItemWithDailySales(Item);

        RunAll.RunForItem(Item."No.", true);

        Item.Get(Item."No.");
        Assert.AreEqual(Item."Reordering Policy"::"Lot-for-Lot", Item."Reordering Policy", 'The advised policy is written');
    end;

    [Test]
    procedure RunForItem_ApplyFalse_WritesNothing()
    var
        Item: Record Item;
        RunAll: Codeunit "GSO Run All";
    begin
        TestLib.InitSetup();
        CreateSmoothItem(Item);

        RunAll.RunForItem(Item."No.", false);

        Item.Get(Item."No.");
        Assert.AreEqual(0, Item."Safety Stock Quantity", 'No safety stock');
        Assert.AreEqual(0, Item."Reorder Point", 'No reorder point');
        Assert.AreEqual(0, Item."Reorder Quantity", 'No EOQ');
    end;

    [Test]
    procedure RunForItem_UnknownItem_NoError()
    var
        RunAll: Codeunit "GSO Run All";
    begin
        TestLib.InitSetup();

        RunAll.RunForItem('GSO-NO-SUCH-ITEM', true);
    end;

    [Test]
    procedure MaximumInventory_WrittenAndLogged()
    var
        Item: Record Item;
        LogEntry: Record "GSO Calculation Log";
        RunAll: Codeunit "GSO Run All";
    begin
        TestLib.InitSetup();
        CreateSmoothItem(Item);
        SetMaximumQtyPolicy(Item, 0);

        RunAll.RunForItem(Item."No.", true);

        Item.Get(Item."No.");
        Assert.AreEqual(Item."Reorder Point" + Item."Reorder Quantity", Item."Maximum Inventory", 'Order-up-to level');
        Assert.IsTrue(TestLib.FindLastLog(Item."No.", LogEntry."Calculation Type"::"Maximum Inventory", LogEntry), 'Logged');
        Assert.AreEqual(Item."Reorder Point", LogEntry."Raw Result", 'Raw Result holds the ROP component');
        Assert.AreEqual(Item."Maximum Inventory", LogEntry.Result, 'Result');
        Assert.AreEqual(0, LogEntry."Previous Value", 'Previous value');
    end;

    [Test]
    procedure MaximumInventory_Unchanged_NotRewritten()
    var
        Item: Record Item;
        RunAll: Codeunit "GSO Run All";
    begin
        TestLib.InitSetup();
        CreateSmoothItem(Item);
        SetMaximumQtyPolicy(Item, 0);

        RunAll.RunForItem(Item."No.", true);
        RunAll.RunForItem(Item."No.", true);

        Assert.AreEqual(1, CountMaxInventoryLogs(Item."No."), 'A second run with the same values writes and logs nothing new');
    end;

    [Test]
    procedure MaximumInventory_SettingOff_NotWritten()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        RunAll: Codeunit "GSO Run All";
    begin
        TestLib.InitSetup();
        Setup.GetSetup();
        Setup."Apply Maximum Inventory" := false;
        Setup.Modify(false);
        CreateSmoothItem(Item);
        SetMaximumQtyPolicy(Item, 0);

        RunAll.RunForItem(Item."No.", true);

        Item.Get(Item."No.");
        Assert.AreEqual(0, Item."Maximum Inventory", 'Apply Maximum Inventory off must not write');
    end;

    [Test]
    procedure MaximumInventory_SettingOff_KeepsCap()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        RunAll: Codeunit "GSO Run All";
    begin
        TestLib.InitSetup();
        Setup.GetSetup();
        Setup."Apply Maximum Inventory" := false;
        Setup.Modify(false);
        CreateSmoothItem(Item);
        SetMaximumQtyPolicy(Item, 50);

        RunAll.RunForItem(Item."No.", true);

        Item.Get(Item."No.");
        Assert.AreEqual(50, Item."Reorder Point", 'When the run does not rewrite the maximum, the cap at the existing one still holds');
        Assert.AreEqual(50, Item."Maximum Inventory", 'Maximum untouched');
    end;

    [Test]
    procedure Bulk_ProcessesFilteredEligibleItems()
    var
        Item1, Item2, Blocked : Record Item;
        ItemFilter: Record Item;
        RunAll: Codeunit "GSO Run All";
    begin
        TestLib.InitSetup();
        CreateSmoothItem(Item1);
        CreateSmoothItem(Item2);
        CreateSmoothItem(Blocked);
        Blocked.Blocked := true;
        Blocked.Modify(false);
        ItemFilter.SetFilter("No.", '%1|%2|%3', Item1."No.", Item2."No.", Blocked."No.");

        Assert.AreEqual(2, RunAll.RunBulk(ItemFilter, true), 'Blocked items are left out');

        Item1.Get(Item1."No.");
        Item2.Get(Item2."No.");
        Assert.IsTrue(Item1."Reorder Point" > 0, 'First item written');
        Assert.IsTrue(Item2."Reorder Point" > 0, 'Second item written');
    end;

    [Test]
    procedure Proposals_CarryCurrentAndProposedValues()
    var
        Item: Record Item;
        ItemFilter: Record Item;
        TempProposal: Record "GSO Planning Proposal" temporary;
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        EOQCalc: Codeunit "GSO EOQ";
        RunAll: Codeunit "GSO Run All";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
        ExpectedSS: Decimal;
        ExpectedEOQ: Decimal;
    begin
        TestLib.InitSetup();
        CreateSmoothItem(Item);
        Item."Safety Stock Quantity" := 3;
        Item."Reorder Point" := 4;
        Item."Reorder Quantity" := 5;
        Item.Modify(false);
        ExpectedSS := SafetyStockCalc.CalculatePreview(Item."No.", ResultCode, Note);
        EOQCalc.CalculatePreview(Item, ResultCode, ExpectedEOQ);
        ItemFilter.SetRange("No.", Item."No.");

        RunAll.BuildProposals(TempProposal, ItemFilter);

        Assert.AreEqual(1, TempProposal.Count(), 'One line');
        TempProposal.FindFirst();
        Assert.AreEqual(Item.Description, TempProposal.Description, 'Description');
        Assert.AreEqual(3, TempProposal."Current Safety Stock", 'Current safety stock');
        Assert.AreEqual(4, TempProposal."Current Reorder Point", 'Current reorder point');
        Assert.AreEqual(5, TempProposal."Current Reorder Quantity", 'Current reorder quantity');
        Assert.AreEqual(ExpectedSS, TempProposal."Proposed Safety Stock", 'Proposed safety stock');
        Assert.AreEqual(70 + ExpectedSS, TempProposal."Proposed Reorder Point", 'Proposed ROP builds on the proposed safety stock, not the stored 3');
        Assert.AreEqual(ExpectedEOQ, TempProposal."Proposed EOQ", 'Proposed EOQ');
        Assert.AreEqual('Smooth', TempProposal."Demand Pattern", 'Pattern');
        Assert.AreEqual(TempProposal."Recommended Policy"::"Fixed Reorder Qty.", TempProposal."Recommended Policy", 'Recommendation');
        Assert.AreEqual(TempProposal."SS Result Code"::OK, TempProposal."SS Result Code", 'SS result');
        Assert.AreEqual(TempProposal."ROP Result Code"::OK, TempProposal."ROP Result Code", 'ROP result');
        Assert.AreEqual(TempProposal."EOQ Result Code"::OK, TempProposal."EOQ Result Code", 'EOQ result');
        Assert.AreEqual(0, TempProposal."Proposed Maximum Inventory", 'No order-up-to level for Fixed Reorder Qty.');
        Assert.IsTrue(TempProposal.Selected, 'A calculable line is pre-selected');
    end;

    [Test]
    procedure Proposals_WriteAndLogNothing()
    var
        Item: Record Item;
        ItemFilter: Record Item;
        TempProposal: Record "GSO Planning Proposal" temporary;
        RunAll: Codeunit "GSO Run All";
    begin
        TestLib.InitSetup();
        CreateSmoothItem(Item);
        ItemFilter.SetRange("No.", Item."No.");

        RunAll.BuildProposals(TempProposal, ItemFilter);

        Item.Get(Item."No.");
        Assert.AreEqual(0, Item."Reorder Point", 'Nothing written');
        Assert.AreEqual(0, TestLib.CountLog(Item."No."), 'Nothing logged');
    end;

    [Test]
    procedure Proposals_UncalculableItem_NotSelected()
    var
        Item: Record Item;
        ItemFilter: Record Item;
        TempProposal: Record "GSO Planning Proposal" temporary;
        RunAll: Codeunit "GSO Run All";
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);
        TestLib.AddSales(Item."No.", 1, 3, 1, 10, 10);
        ItemFilter.SetRange("No.", Item."No.");

        RunAll.BuildProposals(TempProposal, ItemFilter);

        TempProposal.FindFirst();
        Assert.IsFalse(TempProposal.Selected, 'Nothing usable: not selected');
        Assert.AreEqual(TempProposal."SS Result Code"::"Insufficient Demand Data", TempProposal."SS Result Code", 'Reason shown');
    end;

    [Test]
    procedure Proposals_MaximumQty_OrderUpToLevelNotCappedByOldMaximum()
    var
        Item: Record Item;
        ItemFilter: Record Item;
        TempProposal: Record "GSO Planning Proposal" temporary;
        RunAll: Codeunit "GSO Run All";
    begin
        TestLib.InitSetup();
        CreateSmoothItem(Item);
        SetMaximumQtyPolicy(Item, 1);
        ItemFilter.SetRange("No.", Item."No.");

        RunAll.BuildProposals(TempProposal, ItemFilter);

        TempProposal.FindFirst();
        Assert.AreEqual(70 + TempProposal."Proposed Safety Stock", TempProposal."Proposed Reorder Point", 'The old maximum of 1 must not cap the proposed ROP');
        Assert.AreEqual(TempProposal."Proposed Reorder Point" + TempProposal."Proposed EOQ", TempProposal."Proposed Maximum Inventory", 'Order-up-to level = ROP + EOQ');
    end;

    [Test]
    procedure Proposals_AdvisedMaximumQty_AutoUpdateOff_MatchApply()
    var
        Item: Record Item;
        ItemFilter: Record Item;
        TempProposal: Record "GSO Planning Proposal" temporary;
        RunAll: Codeunit "GSO Run All";
    begin
        TestLib.InitSetup(); // Auto-Update Policy off
        CreateSmoothItem(Item);
        Item."Reordering Policy" := Item."Reordering Policy"::"Fixed Reorder Qty.";
        Item."Maximum Inventory" := 50;
        Item.Modify(false);
        ItemFilter.SetRange("No.", Item."No.");

        RunAll.BuildProposals(TempProposal, ItemFilter);

        TempProposal.FindFirst();
        Assert.AreEqual(TempProposal."Recommended Policy"::"Maximum Qty.", TempProposal."Recommended Policy", 'An existing cap makes the advisor recommend Maximum Qty.');
        Assert.AreEqual(50, TempProposal."Proposed Reorder Point", 'The policy is not changed, so the existing cap still holds');
        Assert.AreEqual(0, TempProposal."Proposed Maximum Inventory", 'No new maximum while the item stays on Fixed Reorder Qty.');

        RunAll.ApplySelected(TempProposal);

        Item.Get(Item."No.");
        Assert.AreEqual(TempProposal."Proposed Reorder Point", Item."Reorder Point", 'Apply writes the reorder point the worksheet showed');
        Assert.AreEqual(50, Item."Maximum Inventory", 'Maximum untouched');
    end;

    [Test]
    procedure Proposals_AutoUpdateOn_AdvisedAwayFromMaximumQty_MatchApply()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        ItemFilter: Record Item;
        TempProposal: Record "GSO Planning Proposal" temporary;
        RunAll: Codeunit "GSO Run All";
    begin
        TestLib.InitSetup();
        Setup.GetSetup();
        Setup."Auto-Update Policy" := true;
        Setup.Modify(false);
        TestLib.CreateItemWithDailySales(Item); // ADI 3: Intermittent, Lot-for-Lot advice
        SetMaximumQtyPolicy(Item, 1);
        ItemFilter.SetRange("No.", Item."No.");

        RunAll.BuildProposals(TempProposal, ItemFilter);

        TempProposal.FindFirst();
        Assert.AreEqual(TempProposal."Recommended Policy"::"Lot-for-Lot", TempProposal."Recommended Policy", 'Lot-for-Lot advice');
        Assert.AreEqual(1, TempProposal."Proposed Reorder Point", 'Applying moves the item off Maximum Qty., so the existing cap holds');
        Assert.AreEqual(0, TempProposal."Proposed Maximum Inventory", 'No order-up-to level for Lot-for-Lot');

        RunAll.ApplySelected(TempProposal);

        Item.Get(Item."No.");
        Assert.AreEqual(Item."Reordering Policy"::"Lot-for-Lot", Item."Reordering Policy", 'The advised policy is written');
        Assert.AreEqual(TempProposal."Proposed Reorder Point", Item."Reorder Point", 'Apply writes the reorder point the worksheet showed');
        Assert.AreEqual(1, Item."Maximum Inventory", 'Maximum untouched');
    end;

    [Test]
    procedure Proposals_LeaveOutIneligibleItems()
    var
        Item, Blocked, Excluded : Record Item;
        ItemFilter: Record Item;
        TempProposal: Record "GSO Planning Proposal" temporary;
        RunAll: Codeunit "GSO Run All";
    begin
        TestLib.InitSetup();
        CreateSmoothItem(Item);
        CreateSmoothItem(Blocked);
        Blocked.Blocked := true;
        Blocked.Modify(false);
        CreateSmoothItem(Excluded);
        Excluded."GSO Exclude From Planning" := true;
        Excluded.Modify(false);
        ItemFilter.SetFilter("No.", '%1|%2|%3', Item."No.", Blocked."No.", Excluded."No.");

        RunAll.BuildProposals(TempProposal, ItemFilter);

        Assert.AreEqual(1, TempProposal.Count(), 'Only the eligible item gets a line');
    end;

    [Test]
    procedure Proposals_RebuildReplacesLines()
    var
        Item1, Item2 : Record Item;
        ItemFilter: Record Item;
        TempProposal: Record "GSO Planning Proposal" temporary;
        RunAll: Codeunit "GSO Run All";
    begin
        TestLib.InitSetup();
        CreateSmoothItem(Item1);
        CreateSmoothItem(Item2);
        ItemFilter.SetRange("No.", Item1."No.");
        RunAll.BuildProposals(TempProposal, ItemFilter);

        ItemFilter.SetRange("No.", Item2."No.");
        RunAll.BuildProposals(TempProposal, ItemFilter);

        Assert.AreEqual(1, TempProposal.Count(), 'Old lines are cleared');
        TempProposal.FindFirst();
        Assert.AreEqual(Item2."No.", TempProposal."Item No.", 'Only the new item');
    end;

    [Test]
    procedure ApplySelected_AppliesOnlySelectedLines()
    var
        Item1, Item2 : Record Item;
        ItemFilter: Record Item;
        TempProposal: Record "GSO Planning Proposal" temporary;
        RunAll: Codeunit "GSO Run All";
    begin
        TestLib.InitSetup();
        CreateSmoothItem(Item1);
        CreateSmoothItem(Item2);
        ItemFilter.SetFilter("No.", '%1|%2', Item1."No.", Item2."No.");
        RunAll.BuildProposals(TempProposal, ItemFilter);
        TempProposal.Get(Item2."No.");
        TempProposal.Selected := false;
        TempProposal.Modify(false);

        Assert.AreEqual(1, RunAll.ApplySelected(TempProposal), 'One line applied');

        Item1.Get(Item1."No.");
        Item2.Get(Item2."No.");
        Assert.IsTrue(Item1."Reorder Point" > 0, 'Selected item written');
        Assert.AreEqual(0, Item2."Reorder Point", 'Unselected item untouched');
    end;
}
