namespace GMSoft.InventoryPlanning.Test;

using GMSoft.InventoryPlanning;
using Microsoft.Inventory.Item;
using System.TestLibraries.Utilities;
using System.Threading;

/// <summary>
/// The user interface: Item Card and Item List actions, the planning
/// worksheet, the setup page and the calculation log page, driven through
/// test pages with the dialogs answered by handlers. The Item Card actions
/// are tested through the calls they make (see the note above them).
/// </summary>
codeunit 50210 "GSO Page Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLib: Codeunit "GSO Test Library";
        ItemNoFilter: Text;
        LastMessage: Text;
        ConfirmReply: Boolean;

    local procedure CreateSmoothItem(var Item: Record Item)
    begin
        TestLib.CreateItem(Item);
        TestLib.AddSales(Item."No.", 0, 89, 1, 9, 11);
    end;

    // The Item Card cannot be opened as a test page in an online sandbox: its
    // Item Picture FactBox asks the client for a camera on open, and a test
    // session has no client, so the platform throws a NullReferenceException.
    // These tests make the same calls as the Item Card actions instead.

    [Test]
    procedure ItemCardAction_CalculateSafetyStock()
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
        Result: Decimal;
    begin
        TestLib.InitSetup();
        CreateSmoothItem(Item);

        Result := SafetyStockCalc.CalculateForItem(Item."No.", 0, true, ResultCode, Note);

        Item.Get(Item."No.");
        Assert.IsTrue(Result > 0, 'Safety stock calculated');
        Assert.AreEqual(Result, Item."Safety Stock Quantity", 'Safety stock written');
    end;

    [Test]
    procedure ItemCardAction_CalculateReorderPoint()
    var
        Item: Record Item;
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        CreateSmoothItem(Item);

        ReorderPointCalc.CalculateForItem(Item."No.", true, -1, ResultCode, Note);

        Item.Get(Item."No.");
        Assert.AreEqual(70, Item."Reorder Point", 'Reorder point written');
    end;

    [Test]
    procedure ItemCardAction_CalculateEOQ()
    var
        Item: Record Item;
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        AppliedQty: Decimal;
    begin
        TestLib.InitSetup();
        CreateSmoothItem(Item);

        Assert.IsTrue(EOQCalc.Calculate(Item, true, ResultCode, AppliedQty), 'EOQ calculated');

        Item.Get(Item."No.");
        Assert.IsTrue(Item."Reorder Quantity" > 0, 'EOQ written');
        Assert.AreEqual(AppliedQty, Item."Reorder Quantity", 'The quantity shown is the one written');
    end;

    [Test]
    procedure ItemCardAction_CalculateEOQ_ExplainsSkip()
    var
        Item: Record Item;
        EOQCalc: Codeunit "GSO EOQ";
        ResultCode: Enum "GSO Result Code";
        AppliedQty: Decimal;
    begin
        TestLib.InitSetup();
        CreateSmoothItem(Item);
        Item."Last Direct Cost" := 0;
        Item.Modify(false);

        Assert.IsFalse(EOQCalc.Calculate(Item, true, ResultCode, AppliedQty), 'EOQ skipped');

        Assert.AreEqual(ResultCode::"Zero Unit Cost", ResultCode, 'The skip reason is returned for the message');
    end;

    [Test]
    procedure ItemCardAction_AdvisePolicy()
    var
        Item: Record Item;
        PolicyAdvisor: Codeunit "GSO Policy Advisor";
        Pattern: Text[30];
        Note: Text[250];
    begin
        TestLib.InitSetup();
        CreateSmoothItem(Item);

        PolicyAdvisor.AdviseForItem(Item."No.", true, Pattern, Note);

        Assert.AreEqual('Smooth', Pattern, 'Demand pattern returned for the message');
    end;

    [Test]
    procedure ItemCardAction_RunAll()
    var
        Item: Record Item;
        RunAll: Codeunit "GSO Run All";
    begin
        TestLib.InitSetup();
        CreateSmoothItem(Item);

        RunAll.RunForItem(Item."No.", true);

        Item.Get(Item."No.");
        Assert.AreEqual(70 + Item."Safety Stock Quantity", Item."Reorder Point", 'All values written');
        Assert.IsTrue(Item."Reorder Quantity" > 0, 'EOQ written');
    end;

    [Test]
    procedure ItemCardAction_ViewLog_FilteredToItem()
    var
        Item: Record Item;
        LogEntry: Record "GSO Calculation Log";
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        LogPage: TestPage "GSO Calculation Log";
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
    begin
        TestLib.InitSetup();
        CreateSmoothItem(Item);
        SafetyStockCalc.CalculateForItem(Item."No.", 95, false, ResultCode, Note);

        LogEntry.SetRange("Item No.", Item."No.");
        LogPage.Trap();
        Page.Run(Page::"GSO Calculation Log", LogEntry);

        Assert.AreEqual(Item."No.", LogPage.Filter.GetFilter("Item No."), 'The log opens filtered to the item');
        Assert.IsTrue(LogPage.First(), 'The item''s entry is shown');
        LogPage.Close();
    end;

    [Test]
    procedure ItemCardFields_PlanningFields_Saved()
    var
        Item: Record Item;
    begin
        TestLib.InitSetup();
        TestLib.CreateItem(Item);

        Item.Validate("GSO Service Level %", 99);
        Item.Validate("GSO Exclude From Planning", true);
        Item.Modify(true);

        Item.Get(Item."No.");
        Assert.AreEqual(99, Item."GSO Service Level %", 'Service level saved');
        Assert.IsTrue(Item."GSO Exclude From Planning", 'Exclusion saved');
    end;

    [Test]
    [HandlerFunctions('ConfirmHandler,MessageHandler')]
    procedure ItemList_CalculateAll_UsesListFilter()
    var
        Item1, Item2 : Record Item;
        ItemList: TestPage "Item List";
    begin
        TestLib.InitSetup();
        CreateSmoothItem(Item1);
        CreateSmoothItem(Item2);
        ConfirmReply := true;
        ItemList.OpenView();
        ItemList.Filter.SetFilter("No.", StrSubstNo('%1|%2', Item1."No.", Item2."No."));

        ItemList.GSORunAllBulk.Invoke();

        Item1.Get(Item1."No.");
        Item2.Get(Item2."No.");
        Assert.IsTrue(Item1."Reorder Point" > 0, 'First filtered item written');
        Assert.IsTrue(Item2."Reorder Point" > 0, 'Second filtered item written');
        Assert.IsTrue(StrPos(LastMessage, '2 item(s) processed') = 1, 'Count reported');
    end;

    [Test]
    [HandlerFunctions('ConfirmHandler')]
    procedure ItemList_CalculateAll_Declined_WritesNothing()
    var
        Item: Record Item;
        ItemList: TestPage "Item List";
    begin
        TestLib.InitSetup();
        CreateSmoothItem(Item);
        ConfirmReply := false;
        ItemList.OpenView();
        ItemList.Filter.SetFilter("No.", Item."No.");

        ItemList.GSORunAllBulk.Invoke();

        Item.Get(Item."No.");
        Assert.AreEqual(0, Item."Reorder Point", 'Declining the confirmation writes nothing');
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure ItemList_AdvisePolicy_UsesListFilter()
    var
        Item: Record Item;
        Setup: Record "GSO Setup";
        ItemList: TestPage "Item List";
    begin
        TestLib.InitSetup();
        Setup.GetSetup();
        Setup."Auto-Update Policy" := true;
        Setup.Modify(false);
        CreateSmoothItem(Item);
        ItemList.OpenView();
        ItemList.Filter.SetFilter("No.", Item."No.");

        ItemList.GSOAdviseBulk.Invoke();

        Item.Get(Item."No.");
        Assert.AreEqual(Item."Reordering Policy"::"Fixed Reorder Qty.", Item."Reordering Policy", 'Advice written with auto-update');
        Assert.IsTrue(StrPos(LastMessage, '1 item(s) advised') = 1, 'Count reported');
    end;

    [Test]
    procedure ItemList_OpensWorksheet()
    var
        ItemList: TestPage "Item List";
        Worksheet: TestPage "GSO Planning Worksheet";
    begin
        ItemList.OpenView();
        Worksheet.Trap();

        ItemList.GSOWorksheet.Invoke();

        Worksheet.Close();
    end;

    [Test]
    [HandlerFunctions('ItemFilterHandler,MessageHandler')]
    procedure Worksheet_LoadItems_OneLinePerItem()
    var
        Item1, Item2 : Record Item;
        Worksheet: TestPage "GSO Planning Worksheet";
    begin
        TestLib.InitSetup();
        CreateSmoothItem(Item1);
        CreateSmoothItem(Item2);
        ItemNoFilter := StrSubstNo('%1|%2', Item1."No.", Item2."No.");
        Worksheet.OpenEdit();

        Worksheet.LoadItems.Invoke();

        Assert.IsTrue(Worksheet.GoToKey(Item1."No."), 'Line for the first item');
        Assert.IsTrue(Worksheet."Proposed Reorder Point".AsDecimal() > 0, 'Proposal calculated');
        Assert.IsTrue(Worksheet.Selected.AsBoolean(), 'Pre-selected');
        Assert.IsTrue(Worksheet.GoToKey(Item2."No."), 'Line for the second item');
        Assert.IsTrue(StrPos(LastMessage, '2 of 2 line(s)') = 1, 'Variance summary shown');
        Worksheet.Close();
    end;

    [Test]
    [HandlerFunctions('CancelFilterHandler')]
    procedure Worksheet_LoadItems_Cancelled_NoLines()
    var
        Worksheet: TestPage "GSO Planning Worksheet";
    begin
        TestLib.InitSetup();
        Worksheet.OpenEdit();

        Worksheet.LoadItems.Invoke();

        Assert.IsFalse(Worksheet.First(), 'Cancelling the filter loads nothing');
        Worksheet.Close();
    end;

    [Test]
    [HandlerFunctions('ItemFilterHandler,MessageHandler')]
    procedure Worksheet_SelectAllAndClearSelection()
    var
        Item: Record Item;
        Worksheet: TestPage "GSO Planning Worksheet";
    begin
        TestLib.InitSetup();
        CreateSmoothItem(Item);
        ItemNoFilter := Item."No.";
        Worksheet.OpenEdit();
        Worksheet.LoadItems.Invoke();

        Worksheet.ClearSelection.Invoke();
        Worksheet.GoToKey(Item."No.");
        Assert.IsFalse(Worksheet.Selected.AsBoolean(), 'Clear Selection deselects');

        Worksheet.SelectAll.Invoke();
        Worksheet.GoToKey(Item."No.");
        Assert.IsTrue(Worksheet.Selected.AsBoolean(), 'Select All selects');
        Worksheet.Close();
    end;

    [Test]
    [HandlerFunctions('ItemFilterHandler,MessageHandler,ConfirmHandler')]
    procedure Worksheet_ApplySelected_OnlySelectedAndRefreshed()
    var
        Item1, Item2 : Record Item;
        Worksheet: TestPage "GSO Planning Worksheet";
    begin
        TestLib.InitSetup();
        CreateSmoothItem(Item1);
        CreateSmoothItem(Item2);
        ItemNoFilter := StrSubstNo('%1|%2', Item1."No.", Item2."No.");
        ConfirmReply := true;
        Worksheet.OpenEdit();
        Worksheet.LoadItems.Invoke();
        Worksheet.ClearSelection.Invoke();
        Worksheet.GoToKey(Item1."No.");
        Worksheet.Selected.SetValue(true);

        Worksheet.ApplySelected.Invoke();

        Item1.Get(Item1."No.");
        Item2.Get(Item2."No.");
        Assert.IsTrue(Item1."Reorder Point" > 0, 'Selected item written');
        Assert.AreEqual(0, Item2."Reorder Point", 'Unselected item untouched');
        Assert.IsTrue(StrPos(LastMessage, '1 item(s) updated') = 1, 'Count reported');
        Worksheet.GoToKey(Item1."No.");
        Assert.AreEqual(Item1."Reorder Point", Worksheet."Current Reorder Point".AsDecimal(), 'Current column refreshed');
        Assert.IsFalse(Worksheet.Selected.AsBoolean(), 'Applied line deselected');
        Worksheet.Close();
    end;

    [Test]
    [HandlerFunctions('ItemFilterHandler,MessageHandler')]
    procedure Worksheet_ApplySelected_NothingSelected_NoQuestion()
    var
        Item: Record Item;
        Worksheet: TestPage "GSO Planning Worksheet";
    begin
        TestLib.InitSetup();
        CreateSmoothItem(Item);
        ItemNoFilter := Item."No.";
        Worksheet.OpenEdit();
        Worksheet.LoadItems.Invoke();
        Worksheet.ClearSelection.Invoke();

        Worksheet.ApplySelected.Invoke(); // no ConfirmHandler: a question would fail the test

        Item.Get(Item."No.");
        Assert.AreEqual(0, Item."Reorder Point", 'Nothing applied');
        Worksheet.Close();
    end;

    [Test]
    procedure Worksheet_OpensLogAndSetup()
    var
        Worksheet: TestPage "GSO Planning Worksheet";
        LogPage: TestPage "GSO Calculation Log";
        SetupPage: TestPage "GSO Setup";
    begin
        TestLib.InitSetup();
        Worksheet.OpenEdit();

        LogPage.Trap();
        Worksheet.OpenLog.Invoke();
        LogPage.Close();

        SetupPage.Trap();
        Worksheet.OpenSetup.Invoke();
        SetupPage.Close();
        Worksheet.Close();
    end;

    [Test]
    procedure Setup_ChangesSaved()
    var
        Setup: Record "GSO Setup";
        SetupPage: TestPage "GSO Setup";
    begin
        TestLib.InitSetup();
        SetupPage.OpenEdit();

        SetupPage."Ordering Cost".SetValue(80);
        SetupPage."Dynamic Provider Enabled".SetValue(true);
        SetupPage.Close();

        Setup.Get();
        Assert.AreEqual(80, Setup."Ordering Cost", 'Ordering cost saved');
        Assert.IsTrue(Setup."Dynamic Provider Enabled", 'Provider switch saved');
    end;

    [Test]
    procedure Setup_OpensWithoutRecord_CreatesIt()
    var
        Setup: Record "GSO Setup";
        SetupPage: TestPage "GSO Setup";
    begin
        Setup.DeleteAll(false);

        SetupPage.OpenView();

        Assert.AreEqual(365, SetupPage."History Window (Days)".AsInteger(), 'Defaults shown');
        SetupPage.Close();
        Assert.IsFalse(Setup.IsEmpty(), 'Opening the page creates the setup record');
    end;

    [Test]
    procedure Setup_CreateJobQueueEntry_OnHoldNightlyAll()
    var
        JobQueueEntry: Record "Job Queue Entry";
        SetupPage: TestPage "GSO Setup";
        JobQueueCard: TestPage "Job Queue Entry Card";
        CountBefore: Integer;
    begin
        TestLib.InitSetup();
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"GSO Job Queue");
        CountBefore := JobQueueEntry.Count();
        SetupPage.OpenView();

        JobQueueCard.Trap();
        SetupPage.CreateJobQueueEntry.Invoke();

        Assert.AreEqual(CountBefore + 1, JobQueueEntry.Count(), 'One entry created');
        JobQueueEntry.SetRange("Parameter String", 'ALL');
        JobQueueEntry.SetRange(Status, JobQueueEntry.Status::"On Hold");
        JobQueueEntry.SetRange("Recurring Job", true);
        JobQueueEntry.SetRange("Starting Time", 030000T);
        Assert.IsFalse(JobQueueEntry.IsEmpty(), 'Runs everything nightly at 03:00, created on hold for review');
    end;

    [Test]
    procedure Setup_OpensWorksheetAndLog()
    var
        SetupPage: TestPage "GSO Setup";
        Worksheet: TestPage "GSO Planning Worksheet";
        LogPage: TestPage "GSO Calculation Log";
    begin
        TestLib.InitSetup();
        SetupPage.OpenView();

        Worksheet.Trap();
        SetupPage.OpenWorksheet.Invoke();
        Worksheet.Close();

        LogPage.Trap();
        SetupPage.OpenLog.Invoke();
        LogPage.Close();
        SetupPage.Close();
    end;

    [Test]
    [HandlerFunctions('HyperlinkHandler')]
    procedure Setup_AboutLinkOpensWebsite()
    var
        SetupPage: TestPage "GSO Setup";
    begin
        TestLib.InitSetup();
        SetupPage.OpenView();

        SetupPage.GMSoftSuite.Invoke();

        Assert.AreEqual('https://insidebusinesscentral.com/', LastMessage, 'Opens the GMSoft site');
        SetupPage.Close();
    end;

    [Test]
    procedure CalculationLog_IsReadOnly()
    var
        LogPage: TestPage "GSO Calculation Log";
    begin
        LogPage.OpenView();

        Assert.IsFalse(LogPage.Editable(), 'The audit log cannot be edited');
        LogPage.Close();
    end;

    [MessageHandler]
    procedure MessageHandler(Message: Text[1024])
    begin
        LastMessage := Message;
    end;

    [ConfirmHandler]
    procedure ConfirmHandler(Question: Text[1024]; var Reply: Boolean)
    begin
        Reply := ConfirmReply;
    end;

    [FilterPageHandler]
    procedure ItemFilterHandler(var ItemRecordRef: RecordRef): Boolean
    var
        Item: Record Item;
    begin
        ItemRecordRef.Field(Item.FieldNo("No.")).SetFilter(ItemNoFilter);
        exit(true);
    end;

    [FilterPageHandler]
    procedure CancelFilterHandler(var ItemRecordRef: RecordRef): Boolean
    begin
        exit(false);
    end;

    [HyperlinkHandler]
    procedure HyperlinkHandler(Message: Text[1024])
    begin
        LastMessage := Message;
    end;
}
